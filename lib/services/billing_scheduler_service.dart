import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:logger/logger.dart';
import 'billing_converter_service.dart';
import 'gmail_sender.dart';
import 'billing_template_repository.dart';
import 'invoice_repository.dart';
import 'customer_repository.dart';
import 'project_repository.dart';
import 'ar_report_generator.dart';
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

  /// 請求書をメールで送信
  Future<void> _sendInvoicesByEmail(List<Invoice> invoices, BillingTemplate template) async {
    try {
      for (final invoice in invoices) {
        // 顧客情報取得
        final customer = await _customerRepo.getCustomerById(invoice.customer.id);
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
        Uint8List? arReportBytes;
        if (template.attachArReport) {
          arReportBytes = await _generateArReport(invoice, template);
        }

        // メール送信
        final success = await GmailSender.sendPdf(
          to: customer.email!,
          bcc: template.emailBcc,
          replyTo: template.emailReplyTo,
          subject: invoice.mailTitleCore,
          body: invoice.mailBodyText,
          pdfBytes: pdfBytes,
          pdfFilename: invoice.mailAttachmentFileName,
        );

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
  Future<Uint8List?> _generateInvoicePdf(Invoice invoice) async {
    try {
      // 既存のdocument_pdf_generator.dartを使用
      // InvoiceをDocumentModelに変換してからPDF生成
      // TODO: Invoice→DocumentModel変換ロジックを実装
      _logger.w('[BillingScheduler] Invoice PDF generation requires Invoice→DocumentModel conversion');
      return null;
    } catch (e) {
      _logger.e('[BillingScheduler] Generate invoice PDF error: $e');
      return null;
    }
  }

  /// 売掛レポート生成
  Future<Uint8List?> _generateArReport(Invoice invoice, BillingTemplate template) async {
    try {
      return await _arReportGenerator.generateArReportForInvoice(invoice);
    } catch (e) {
      _logger.e('[BillingScheduler] Generate AR report error: $e');
      return null;
    }
  }

  /// 請求書のメール送信日時を更新
  Future<void> _updateInvoiceEmailSent(String invoiceId, String email) async {
    try {
      // TODO: InvoiceRepositoryにメール送信日時更新メソッドを追加
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
