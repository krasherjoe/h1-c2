import 'dart:async';
import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:logger/logger.dart';
import 'package:path_provider/path_provider.dart';
import 'billing_converter_service.dart';
import 'gmail_sender.dart';
import 'billing_template_repository.dart';
import 'invoice_repository.dart';
import 'customer_repository.dart';
import 'project_repository.dart';
import 'ar_report_generator.dart';
import 'sales_queue_repository.dart';
import '../models/sales_queue_model.dart';
import '../models/invoice_models.dart' as invoice_models;
import '../models/billing_template_model.dart';
import '../plugins/documents/logic/document_pdf_generator.dart';

/// 請求書自動発行スケジューラ
class BillingSchedulerService {
  static final BillingSchedulerService _instance = BillingSchedulerService._internal();
  factory BillingSchedulerService() => _instance;
  BillingSchedulerService._internal();

  final Logger _logger = Logger();
  Timer? _schedulerTimer;
  bool _isRunning = false;
  DateTime? _lastRunDate;

  final _converter = BillingConverterService();
  final _templateRepo = BillingTemplateRepository();
  final _invoiceRepo = InvoiceRepository();
  final _customerRepo = CustomerRepository();
  final _projectRepo = ProjectRepository();
  final _arReportGenerator = ArReportGenerator();
  final _salesQueueRepo = SalesQueueRepository();

  /// スケジューラを開始
  void startScheduler() {
    if (_isRunning) {
      _logger.w('[BillingScheduler] Already running');
      return;
    }

    _isRunning = true;
    _logger.i('[BillingScheduler] Started');

    // 即時実行（初回チェック）
    _checkAndProcess();

    // 毎日0時にチェック（24時間ごと）
    _schedulerTimer = Timer.periodic(const Duration(hours: 24), (_) => _checkAndProcess());
  }

  /// スケジューラを停止
  void stopScheduler() {
    _schedulerTimer?.cancel();
    _schedulerTimer = null;
    _isRunning = false;
    _logger.i('[BillingScheduler] Stopped');
  }

  /// 締め日チェックと処理実行
  Future<void> _checkAndProcess() async {
    try {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      // 同日チェックはスキップ
      if (_lastRunDate != null && _lastRunDate!.isAtSameMomentAs(today)) {
        _logger.d('[BillingScheduler] Already checked today, skipping');
        return;
      }

      _logger.i('[BillingScheduler] Checking for closing date: $today');
      _lastRunDate = today;

      // 締め日チェック
      await _processClosingDate(today);
    } catch (e) {
      _logger.e('[BillingScheduler] Check error: $e');
    }
  }

  /// 締め日処理
  Future<void> _processClosingDate(DateTime date) async {
    try {
      // 売上キュー処理
      await _processSalesQueue(date);

      // 全テンプレートを取得
      final templates = await _templateRepo.getAllTemplates();

      for (final template in templates) {
        if (!template.autoGenerateInvoice) continue;

        // 締め日チェック
        final closingDate = template.calculateClosingDate(date);
        if (closingDate.day != date.day) continue;

        _logger.i('[BillingScheduler] Processing closing date for template: ${template.name}');

        // 請求書生成
        final invoices = await _converter.generateInvoicesForClosingDate(date);

        if (invoices.isEmpty) {
          _logger.d('[BillingScheduler] No invoices to generate for template: ${template.name}');
          continue;
        }

        // 請求書保存
        await _converter.saveGeneratedInvoices(invoices);
        _logger.i('[BillingScheduler] Generated ${invoices.length} invoices');

        // 自動メール送信
        if (template.autoSendEmail) {
          await _sendInvoicesByEmail(invoices, template);
        }
      }
    } catch (e) {
      _logger.e('[BillingScheduler] Process closing date error: $e');
    }
  }

  /// 売上キュー処理
  Future<void> _processSalesQueue(DateTime date) async {
    try {
      _logger.i('[BillingScheduler] Processing sales queue for date: $date');

      // 待機中のエントリを取得
      final pendingEntries = await _salesQueueRepo.getPendingEntries();
      if (pendingEntries.isEmpty) {
        _logger.d('[BillingScheduler] No pending entries in sales queue');
        return;
      }

      _logger.i('[BillingScheduler] Found ${pendingEntries.length} pending entries');

      // 案件ごとにグループ化
      final Map<String, List<SalesQueueEntry>> grouped = {};
      for (final entry in pendingEntries) {
        grouped.putIfAbsent(entry.projectId, () => []);
        grouped[entry.projectId]!.add(entry);
      }

      // 案件ごとに処理
      for (final entry in grouped.entries) {
        final projectId = entry.key;
        final entries = entry.value;

        // テンプレート取得
        final template = await _converter.getTemplateForProject(projectId);
        if (template == null) {
          _logger.w('[BillingScheduler] No template for project: $projectId');
          continue;
        }

        // 締め日チェック
        final closingDate = template.calculateClosingDate(date);
        if (closingDate.day != date.day) {
          _logger.d('[BillingScheduler] Not closing date for project: $projectId');
          continue;
        }

        _logger.i('[BillingScheduler] Processing ${entries.length} entries for project: $projectId');

        // エントリを処理中に更新
        for (final entry in entries) {
          await _salesQueueRepo.updateStatus(entry.id, QueueStatus.processing);
        }

        try {
          // 請求書生成
          final invoices = await _converter.generateInvoicesForClosingDate(date);
          
          if (invoices.isEmpty) {
            _logger.w('[BillingScheduler] No invoices generated for project: $projectId');
            // 処理失敗としてマーク
            for (final entry in entries) {
              await _salesQueueRepo.updateStatus(
                entry.id,
                QueueStatus.failed,
                errorMessage: '請求書生成なし',
              );
            }
            continue;
          }

          // 請求書保存
          await _converter.saveGeneratedInvoices(invoices);

          // エントリを完了に更新
          for (final entry in entries) {
            await _salesQueueRepo.updateStatus(
              entry.id,
              QueueStatus.completed,
              invoiceId: invoices.first.id,
            );
          }

          _logger.i('[BillingScheduler] Completed ${entries.length} entries for project: $projectId');
        } catch (e) {
          _logger.e('[BillingScheduler] Error processing project $projectId: $e');
          // エントリを失敗に更新
          for (final entry in entries) {
            await _salesQueueRepo.updateStatus(
              entry.id,
              QueueStatus.failed,
              errorMessage: e.toString(),
            );
          }
        }
      }
    } catch (e) {
      _logger.e('[BillingScheduler] Process sales queue error: $e');
    }
  }

  /// 請求書をメールで送信
  Future<void> _sendInvoicesByEmail(List<invoice_models.Invoice> invoices, BillingTemplate template) async {
    try {
      for (final invoice in invoices) {
        // 顧客情報取得
        final customers = await _customerRepo.getAllCustomers();
        final customer = customers.where((c) => c.id == invoice.customer.id).firstOrNull;
        if (customer == null) {
          _logger.w('[BillingScheduler] Customer not found: ${invoice.customer.id}');
          continue;
        }

        // メールアドレスチェック
        if (customer.email == null || customer.email!.isEmpty) {
          _logger.w('[BillingScheduler] No email for customer: ${customer.displayName}');
          continue;
        }

        // PDF生成
        final pdfBytes = await _generateInvoicePdf(invoice);
        if (pdfBytes == null) {
          _logger.e('[BillingScheduler] PDF generation failed for invoice: ${invoice.id}');
          continue;
        }

        // 売掛レポート添付
        File? arReportFile;
        if (template.attachArReport) {
          arReportFile = await _generateArReport(invoice, template);
        }

        // 添付ファイルリスト作成
        final attachments = <Map<String, dynamic>>[
          {'filename': invoice.mailAttachmentFileName, 'bytes': pdfBytes},
        ];

        if (arReportFile != null) {
          attachments.add({
            'filename': arReportFile.path.split('/').last,
            'bytes': await arReportFile.readAsBytes(),
          });
        }

        // メール送信（複数添付対応）
        final success = await GmailSender.sendPdfs(
          to: customer.email!,
          bcc: template.emailBcc,
          replyTo: template.emailReplyTo,
          subject: invoice.mailTitleCore,
          body: invoice.mailBodyText,
          attachments: attachments,
        );

        // 一時ファイル削除
        if (arReportFile != null) {
          try {
            await arReportFile.delete();
            _logger.d('[BillingScheduler] Temp AR report deleted: ${arReportFile.path}');
          } catch (e) {
            _logger.w('[BillingScheduler] Failed to delete temp AR report: $e');
          }
        }

        if (success) {
          _logger.i('[BillingScheduler] Email sent for invoice: ${invoice.id}');
          // 送信日時を記録
          await _updateInvoiceEmailSent(invoice.id, customer.email!);
        } else {
          _logger.e('[BillingScheduler] Email send failed for invoice: ${invoice.id}');
        }
      }
    } catch (e) {
      _logger.e('[BillingScheduler] Send invoices by email error: $e');
    }
  }

  /// 請求書PDF生成
  Future<Uint8List?> _generateInvoicePdf(invoice_models.Invoice invoice) async {
    try {
      // InvoiceをDocumentModelに変換
      final document = _converter.invoiceToDocumentModel(invoice);

      // PDF生成
      final pdf = await generateDocumentPdf(document);
      final pdfBytes = Uint8List.fromList(await pdf.save());

      return pdfBytes;
    } catch (e) {
      _logger.e('[BillingScheduler] Generate invoice PDF error: $e');
      return null;
    }
  }

  /// 売掛レポート生成（一時ファイル）
  Future<File?> _generateArReport(invoice_models.Invoice invoice, BillingTemplate template) async {
    try {
      final file = await _arReportGenerator.generateArReportAsTempFile(
        customer: invoice.customer,
        asOfDate: DateTime.now(),
        template: template,
      );
      return file;
    } catch (e) {
      _logger.e('[BillingScheduler] Generate AR report error: $e');
      return null;
    }
  }

  /// 請求書のメール送信日時を更新
  Future<void> _updateInvoiceEmailSent(String invoiceId, String email) async {
    try {
      // InvoiceRepositoryを通じて更新
      // まず現在の請求書を取得
      final customers = await _customerRepo.getAllCustomers();
      final invoices = await _invoiceRepo.getAllInvoices(customers);
      final invoice = invoices.where((inv) => inv.id == invoiceId).firstOrNull;

      if (invoice == null) {
        _logger.w('[BillingScheduler] Invoice not found: $invoiceId');
        return;
      }

      // メール送信日時を更新して保存
      final updated = invoice.copyWith(
        emailSentAt: DateTime.now().toIso8601String(),
        emailSentTo: email,
      );
      await _invoiceRepo.updateInvoice(updated);

      _logger.d('[BillingScheduler] Update email sent for invoice: $invoiceId');
    } catch (e) {
      _logger.e('[BillingScheduler] Update email sent error: $e');
    }
  }

  /// 手動実行（テスト用）
  Future<void> runManually(DateTime date) async {
    _logger.i('[BillingScheduler] Manual run for date: $date');
    await _processClosingDate(date);
  }

  bool get isRunning => _isRunning;
  DateTime? get lastRunDate => _lastRunDate;
}
