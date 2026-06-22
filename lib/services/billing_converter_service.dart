import 'package:flutter/foundation.dart' show debugPrint;
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import '../models/billing_template_model.dart';
import '../models/invoice_models.dart' as invoice_models;
import '../models/customer_model.dart';
import '../models/project_model.dart';
import '../plugins/documents/models/document_model.dart';
import '../plugins/documents/services/document_repository.dart';
import 'invoice_repository.dart';
import 'customer_repository.dart';
import 'billing_template_repository.dart';
import 'project_repository.dart';
import 'database_helper.dart';

/// 納品書→請求書変換サービス
class BillingConverterService {
  final _uuid = const Uuid();
  final _docRepo = DocumentRepository();
  final _invoiceRepo = InvoiceRepository();
  final _customerRepo = CustomerRepository();
  final _templateRepo = BillingTemplateRepository();
  final _projectRepo = ProjectRepository();
  final _dbHelper = DatabaseHelper();

  /// 案件に紐づく未請求の納品書を収集
  Future<List<DocumentModel>> getUnbilledDeliveries(String projectId) async {
    try {
      final docs = await _docRepo.fetchAll();
      final unbilled = <DocumentModel>[];
      for (final doc in docs) {
        if (doc.projectId == projectId &&
            doc.documentType == DocumentType.delivery &&
            doc.status == 'confirmed') {
          // 既に請求書に含まれているかチェック
          final alreadyInvoiced = await _isAlreadyInvoiced(doc.id);
          if (!alreadyInvoiced) {
            unbilled.add(doc);
          }
        }
      }
      return unbilled;
    } catch (e) {
      debugPrint('[BillingConverter] getUnbilledDeliveries error: $e');
      rethrow;
    }
  }

  /// 期間内の未請求納品書を収集
  Future<List<DocumentModel>> getUnbilledDeliveriesInPeriod({
    required String projectId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      final docs = await getUnbilledDeliveries(projectId);
      return docs.where((doc) {
        final docDate = doc.date;
        return !docDate.isBefore(startDate) && !docDate.isAfter(endDate);
      }).toList();
    } catch (e) {
      debugPrint('[BillingConverter] getUnbilledDeliveriesInPeriod error: $e');
      rethrow;
    }
  }

  /// 顧客別の未請求納品書を収集（複数案件まとめて）
  Future<List<DocumentModel>> getUnbilledDeliveriesByCustomer(String customerId) async {
    try {
      final docs = await _docRepo.fetchAll();
      final unbilled = <DocumentModel>[];
      for (final doc in docs) {
        if (doc.customerId == customerId &&
            doc.documentType == DocumentType.delivery &&
            doc.status == 'confirmed') {
          final alreadyInvoiced = await _isAlreadyInvoiced(doc.id);
          if (!alreadyInvoiced) {
            unbilled.add(doc);
          }
        }
      }
      return unbilled;
    } catch (e) {
      debugPrint('[BillingConverter] getUnbilledDeliveriesByCustomer error: $e');
      rethrow;
    }
  }

  /// 既に請求書に含まれているかチェック
  Future<bool> _isAlreadyInvoiced(String deliveryId) async {
    try {
      final db = await _dbHelper.database;
      // linked_delivery_idにdeliveryIdが含まれる請求書を検索
      final result = await db.rawQuery(
        "SELECT id FROM invoices WHERE linked_delivery_id LIKE ?",
        ['%$deliveryId%'],
      );
      return result.isNotEmpty;
    } catch (e) {
      debugPrint('[BillingConverter] _isAlreadyInvoiced error: $e');
      return false;
    }
  }

  /// 納品書から請求書を生成
  Future<invoice_models.Invoice> convertDeliveriesToInvoice({
    required List<DocumentModel> deliveries,
    required BillingTemplate template,
    required Customer customer,
    String? projectId,
  }) async {
    try {
      if (deliveries.isEmpty) {
        throw Exception('納品書がありません');
      }

      // 請求書日（締め日または今日）
      final invoiceDate = template.invoiceTiming == InvoiceTiming.onClosingDate
          ? template.calculateClosingDate(DateTime.now())
          : DateTime.now();

      // 支払い期限
      final paymentDueDate = template.calculatePaymentDueDate(invoiceDate);

      // 明細を統合
      final items = _consolidateItems(deliveries, template);

      // 案件名（備考または最初の納品書から）
      final subject = deliveries.first.subject;

      // 納品書IDをカンマ区切りで保存（複数納品書対応）
      final deliveryIds = deliveries.map((d) => d.id).join(',');

      // 請求書作成
      final invoice = invoice_models.Invoice(
        id: _uuid.v4(),
        customer: customer,
        date: invoiceDate,
        items: items,
        notes: template.invoiceNotes,
        taxRate: 0.10, // デフォルト10%
        documentType: invoice_models.DocumentType.invoice,
        orderStatus: invoice_models.OrderStatus.confirmed,
        subject: subject,
        isLocked: false, // まだ正式発行前
        isDraft: false,
        projectId: projectId,
        includeTax: true,
        isTaxInclusiveMode: false,
        linkedDeliveryId: deliveryIds, // 複数納品書をカンマ区切りで紐づけ
      );

      return invoice;
    } catch (e) {
      debugPrint('[BillingConverter] convertDeliveriesToInvoice error: $e');
      rethrow;
    }
  }

  /// 明細を統合（テンプレート設定に基づく）
  List<invoice_models.InvoiceItem> _consolidateItems(List<DocumentModel> deliveries, BillingTemplate template) {
    if (!template.groupByProject) {
      // 案件別グループ化なし - 全ての明細をフラットに統合
      return deliveries.expand((doc) => doc.items).map((item) => invoice_models.InvoiceItem(
        id: _uuid.v4(),
        productId: item.productId,
        description: item.productName,
        quantity: item.quantity.toInt(),
        unitPrice: item.unitPrice.toInt(),
        discountAmount: item.discountAmount?.toInt(),
        discountRate: item.discountRate,
      )).toList();
    }

    // 案件別にグループ化
    final Map<String, List<DocumentItem>> grouped = {};
    for (final doc in deliveries) {
      final projectKey = doc.projectId ?? 'no_project';
      grouped.putIfAbsent(projectKey, () => []);
      grouped[projectKey]!.addAll(doc.items);
    }

    // グループごとに統合
    final List<invoice_models.InvoiceItem> consolidated = [];
    for (final entry in grouped.entries) {
      if (template.includeDeliveryDetails) {
        // 納品明細を含む - そのまま追加
        consolidated.addAll(entry.value.map((item) => invoice_models.InvoiceItem(
          id: _uuid.v4(),
          productId: item.productId,
          description: item.productName,
          quantity: item.quantity.toInt(),
          unitPrice: item.unitPrice.toInt(),
          discountAmount: item.discountAmount?.toInt(),
          discountRate: item.discountRate,
        )));
      } else {
        // 納品明細を含まない - サマリーのみ
        final totalAmount = entry.value.fold(0, (sum, item) => sum + item.subtotal);
        final project = entry.key == 'no_project' ? 'その他' : entry.key;
        consolidated.add(invoice_models.InvoiceItem(
          id: _uuid.v4(),
          description: '案件: $project（納品分）',
          quantity: 1,
          unitPrice: totalAmount.toInt(),
        ));
      }
    }

    return consolidated;
  }

  /// 案件の請求テンプレートを取得（なければデフォルト）
  Future<BillingTemplate> getTemplateForProject(String projectId) async {
    try {
      final project = await _projectRepo.getById(projectId);
      if (project?.billingTemplateId != null) {
        final template = await _templateRepo.getTemplateById(project!.billingTemplateId!);
        if (template != null) return template;
      }

      // デフォルトテンプレート
      final defaultTemplate = await _templateRepo.getDefaultTemplate();
      if (defaultTemplate != null) return defaultTemplate;

      // デフォルトがない場合は初期化
      await _templateRepo.initializeDefaultTemplate();
      return (await _templateRepo.getDefaultTemplate())!;
    } catch (e) {
      debugPrint('[BillingConverter] getTemplateForProject error: $e');
      rethrow;
    }
  }

  /// 締め日ベースで請求書を一括生成
  Future<List<invoice_models.Invoice>> generateInvoicesForClosingDate(DateTime closingDate) async {
    try {
      final List<invoice_models.Invoice> generatedInvoices = [];

      // 全案件を取得
      final projects = await _projectRepo.getAll();

      for (final project in projects) {
        if (project.status != ProjectStatus.active) continue;

        // テンプレート取得
        final template = await getTemplateForProject(project.id);
        if (!template.autoGenerateInvoice) continue;
        if (template.invoiceTiming != InvoiceTiming.onClosingDate) continue;

        // 締め日チェック
        final templateClosingDate = template.calculateClosingDate(closingDate);
        if (templateClosingDate.day != closingDate.day) continue;

        // 期間内の未請求納品書を取得
        final startDate = _getPreviousClosingDate(closingDate, template);
        final deliveries = await getUnbilledDeliveriesInPeriod(
          projectId: project.id,
          startDate: startDate,
          endDate: closingDate,
        );

        if (deliveries.isEmpty) continue;

        // 顧客取得
        final customers = await _customerRepo.getAllCustomers();
        final customer = project.customerId != null
            ? customers.where((c) => c.id == project.customerId).firstOrNull
            : null;
        if (customer == null) continue;

        // 請求書生成
        final invoice = await convertDeliveriesToInvoice(
          deliveries: deliveries,
          template: template,
          customer: customer,
          projectId: project.id,
        );

        generatedInvoices.add(invoice);
      }

      return generatedInvoices;
    } catch (e) {
      debugPrint('[BillingConverter] generateInvoicesForClosingDate error: $e');
      rethrow;
    }
  }

  /// 前回の締め日を計算
  DateTime _getPreviousClosingDate(DateTime currentClosingDate, BillingTemplate template) {
    switch (template.closingMonthType) {
      case ClosingMonthType.everyMonth:
        return DateTime(currentClosingDate.year, currentClosingDate.month, 1);
      case ClosingMonthType.everyTwoMonths:
        return DateTime(currentClosingDate.year, currentClosingDate.month - 1, 1);
      case ClosingMonthType.quarterly:
        return DateTime(currentClosingDate.year, currentClosingDate.month - 3, 1);
    }
  }

  /// 生成した請求書を保存
  Future<void> saveGeneratedInvoices(List<invoice_models.Invoice> invoices) async {
    try {
      for (final invoice in invoices) {
        await _invoiceRepo.saveInvoice(invoice);
      }
    } catch (e) {
      debugPrint('[BillingConverter] saveGeneratedInvoices error: $e');
      rethrow;
    }
  }

  /// InvoiceをDocumentModelに変換（PDF生成用）
  DocumentModel invoiceToDocumentModel(invoice_models.Invoice invoice) {
    // DocumentItemに変換
    final documentItems = invoice.items.map((item) => DocumentItem(
      id: item.id ?? _uuid.v4(),
      productId: item.productId ?? '',
      productName: item.description,
      quantity: item.quantity.toDouble(),
      unitPrice: item.unitPrice,
      taxRate: invoice.taxRate.toDouble(),
      discountAmount: item.discountAmount,
      discountRate: item.discountRate,
      maker: '',
      productCode: '',
      notes: '',
    )).toList();

    // DocumentModelを作成
    return DocumentModel(
      id: invoice.id,
      documentType: invoice.documentType == invoice_models.DocumentType.invoice 
          ? DocumentType.invoice 
          : DocumentType.estimation, // fallback
      customerId: invoice.customer.id,
      customerName: invoice.customerNameForDisplay ?? '',
      documentNumber: invoice.invoiceNumber,
      date: invoice.date,
      total: invoice.totalAmount,
      status: invoice.isLocked ? 'confirmed' : 'draft',
      linkedDocumentId: invoice.sourceDocumentId,
      projectId: invoice.projectId,
      subject: invoice.subject,
      items: documentItems,
      includeTax: invoice.includeTax,
      taxRate: invoice.taxRate.toDouble(),
      totalDiscountAmount: invoice.totalDiscountAmount,
      totalDiscountRate: invoice.totalDiscountRate,
      priceAdjustmentType: invoice.priceAdjustmentType,
      priceAdjustmentUnit: invoice.priceAdjustmentUnit,
      isLocked: invoice.isLocked,
      contentHash: invoice.contentHash,
      version: invoice.version,
      isCurrent: invoice.isCurrent,
      previousHash: invoice.previousHash,
      paymentStatus: invoice.paymentStatus.name,
      receivedAmount: invoice.receivedAmount,
      dueDate: null, // Invoice doesn't have dueDate field
    );
  }
}
