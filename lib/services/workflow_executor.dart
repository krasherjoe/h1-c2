import 'package:flutter/foundation.dart' show debugPrint;
import 'dart:typed_data';
import '../models/billing_template_model.dart';
import '../models/invoice_models.dart' as invoice_models;
import '../models/customer_model.dart';
import '../plugins/documents/models/document_model.dart';
import '../plugins/documents/services/document_repository.dart';
import '../plugins/documents/logic/document_pdf_generator.dart' show generateDocumentPdf;
import 'project_repository.dart';
import 'billing_converter_service.dart';
import 'invoice_repository.dart';
import 'customer_repository.dart';
import 'gmail_sender.dart';
import 'ar_report_generator.dart';

/// ワークフロー実行エンジン
class WorkflowExecutor {
  final _projectRepo = ProjectRepository();
  final _docRepo = DocumentRepository();
  final _converter = BillingConverterService();
  final _invoiceRepo = InvoiceRepository();
  final _customerRepo = CustomerRepository();
  final _arReportGenerator = ArReportGenerator();

  /// ワークフロー実行（単一ステップ）
  Future<void> executeStep({
    required String projectId,
    required WorkflowStep step,
    String? documentId,
  }) async {
    debugPrint('[WorkflowExecutor] Executing step: ${step.name} for project: $projectId');

    try {
      switch (step) {
        case WorkflowStep.delivery:
          await _executeDelivery(projectId, documentId);
          break;
        case WorkflowStep.cashCollection:
          await _executeCashCollection(projectId, documentId);
          break;
        case WorkflowStep.waitForClosing:
          await _executeWaitForClosing(projectId);
          break;
        case WorkflowStep.generateInvoice:
          await _executeGenerateInvoice(projectId);
          break;
        case WorkflowStep.sendEmail:
          await _executeSendEmail(projectId);
          break;
        case WorkflowStep.complete:
          await _executeComplete(projectId);
          break;
      }

      // 進捗更新
      await _projectRepo.updateWorkflowProgress(projectId, step);
    } catch (e) {
      debugPrint('[WorkflowExecutor] Step execution error: $e');
      rethrow;
    }
  }

  /// 📦 納品書発行
  Future<void> _executeDelivery(String projectId, String? documentId) async {
    debugPrint('[WorkflowExecutor] Delivery step: documentId=$documentId');
    // 納品書正式発行時にDocumentPageでSalesQueueが作成される
    // ここでは何もしない
  }

  /// 💰 現金回収
  Future<void> _executeCashCollection(String projectId, String? documentId) async {
    debugPrint('[WorkflowExecutor] Cash collection step: documentId=$documentId');
    // TODO: 現金回収画面を表示するロジック
    // 現時はスキップ
  }

  /// ⏳ 締め日待機
  Future<void> _executeWaitForClosing(String projectId) async {
    debugPrint('[WorkflowExecutor] Wait for closing step: $projectId');
    // スケジューラが締め日を検知したら次のステップへ
    // ここでは何もしない（待機状態）
  }

  /// 📄 請求書生成
  Future<void> _executeGenerateInvoice(String projectId) async {
    debugPrint('[WorkflowExecutor] Generate invoice step: $projectId');

    try {
      // 未請求の納品書を取得
      final deliveries = await _converter.getUnbilledDeliveries(projectId);
      if (deliveries.isEmpty) {
        debugPrint('[WorkflowExecutor] No unbilled deliveries for project: $projectId');
        return;
      }

      // テンプレート取得
      final template = await _converter.getTemplateForProject(projectId);

      // 顧客取得
      final project = await _projectRepo.getById(projectId);
      if (project == null || project.customerId == null) {
        debugPrint('[WorkflowExecutor] No customer for project: $projectId');
        return;
      }

      final customers = await _customerRepo.getAllCustomers();
      final customer = customers.where((c) => c.id == project.customerId).firstOrNull;
      if (customer == null) {
        debugPrint('[WorkflowExecutor] Customer not found: ${project.customerId}');
        return;
      }

      // 請求書生成
      final invoice = await _converter.convertDeliveriesToInvoice(
        deliveries: deliveries,
        template: template,
        customer: customer,
        projectId: projectId,
      );

      // 請求書保存
      await _invoiceRepo.saveInvoice(invoice);
      debugPrint('[WorkflowExecutor] Invoice generated: ${invoice.id}');
    } catch (e) {
      debugPrint('[WorkflowExecutor] Generate invoice error: $e');
      rethrow;
    }
  }

  /// 📧 メール送信
  Future<void> _executeSendEmail(String projectId) async {
    debugPrint('[WorkflowExecutor] Send email step: $projectId');

    try {
      // 案件の最新請求書を取得
      final project = await _projectRepo.getById(projectId);
      if (project == null || project.customerId == null) return;

      final customers = await _customerRepo.getAllCustomers();
      final customer = customers.where((c) => c.id == project.customerId).firstOrNull;
      if (customer == null) {
        debugPrint('[WorkflowExecutor] Customer not found: ${project.customerId}');
        return;
      }

      final allInvoices = await _invoiceRepo.getAllInvoices(customers);
      final invoices = allInvoices
          .where((inv) =>
              inv.customer.id == customer.id &&
              inv.projectId == projectId &&
              inv.documentType == invoice_models.DocumentType.invoice &&
              !inv.isLocked)
          .toList();

      if (invoices.isEmpty) {
        debugPrint('[WorkflowExecutor] No pending invoices for project: $projectId');
        return;
      }

      // 最新の請求書を送信
      final invoice = invoices.first;

      // PDF生成（Invoice→DocumentModel変換）
      final document = _converter.invoiceToDocumentModel(invoice);
      final pdf = await generateDocumentPdf(document);
      final pdfBytes = Uint8List.fromList(await pdf.save());

      // メール送信
      if (customer.email == null || customer.email!.isEmpty) {
        debugPrint('[WorkflowExecutor] No email for customer: ${customer.displayName}');
        return;
      }

      final success = await GmailSender.sendPdf(
        to: customer.email!,
        subject: invoice.mailTitleCore,
        body: invoice.mailBodyText,
        pdfBytes: pdfBytes,
        pdfFilename: invoice.mailAttachmentFileName,
      );

      if (success) {
        debugPrint('[WorkflowExecutor] Email sent for invoice: ${invoice.id}');
      } else {
        debugPrint('[WorkflowExecutor] Email send failed for invoice: ${invoice.id}');
      }
    } catch (e) {
      debugPrint('[WorkflowExecutor] Send email error: $e');
      rethrow;
    }
  }

  /// ✅ 完了
  Future<void> _executeComplete(String projectId) async {
    debugPrint('[WorkflowExecutor] Complete step: $projectId');
    await _projectRepo.completeWorkflow(projectId);
  }

  /// ワークフロー全体実行（自動実行用）
  Future<void> executeWorkflow(String projectId) async {
    try {
      final project = await _projectRepo.getById(projectId);
      if (project?.billingTemplateId == null) {
        debugPrint('[WorkflowExecutor] No billing template for project: $projectId');
        return;
      }

      final template = await _converter.getTemplateForProject(projectId);
      final steps = template.workflowSteps;

      debugPrint('[WorkflowExecutor] Executing workflow with ${steps.length} steps');

      for (final step in steps) {
        await executeStep(projectId: projectId, step: step);
      }
    } catch (e) {
      debugPrint('[WorkflowExecutor] Workflow execution error: $e');
      rethrow;
    }
  }

  /// 次のステップを取得
  Future<WorkflowStep?> getNextStep(String projectId) async {
    try {
      final currentStep = await _projectRepo.getCurrentWorkflowStep(projectId);
      if (currentStep == null) return null;

      final template = await _converter.getTemplateForProject(projectId);
      final currentIndex = template.workflowSteps.indexOf(currentStep);

      if (currentIndex < 0 || currentIndex >= template.workflowSteps.length - 1) {
        return null; // 次のステップなし
      }

      return template.workflowSteps[currentIndex + 1];
    } catch (e) {
      debugPrint('[WorkflowExecutor] getNextStep error: $e');
      return null;
    }
  }
}
