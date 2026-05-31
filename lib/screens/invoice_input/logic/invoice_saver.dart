import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../../models/invoice_models.dart';
import '../../../models/customer_model.dart';
import '../../../models/sales_model.dart' show Sales;
import '../../../models/base_document.dart' show DocumentItem;
import '../../../widgets/document_card.dart' show DocumentStatus;
import '../../../services/invoice_repository.dart';
import '../../../services/edit_log_repository.dart';
import '../../../services/project_repository.dart';
import '../../../services/sales_repository.dart';
import '../../../services/pdf_generator.dart' show PdfGenerator;

Future<Invoice> saveInvoice(
  BuildContext context, {
  required InvoiceRepository invoiceRepo,
  required EditLogRepository editLogRepo,
  required ProjectRepository projectRepo,
  required Customer selectedCustomer,
  required List<InvoiceItem> items,
  required DateTime selectedDate,
  required double taxRate,
  required DocumentType documentType,
  required String? subject,
  required bool isDraft,
  required bool includeTax,
  required bool isTaxInclusiveMode,
  required String? priceAdjustmentType,
  required int? priceAdjustmentUnit,
  required String? bankAccount,
  required String? projectId,
  required String? currentId,
  required double? latitude,
  required double? longitude,
  required bool generatePdf,
}) async {
  final invoiceId = currentId ?? DateTime.now().millisecondsSinceEpoch.toString();

  final invoice = Invoice(
    id: invoiceId,
    customer: selectedCustomer,
    date: selectedDate,
    items: items,
    taxRate: includeTax ? taxRate : 0.0,
    documentType: documentType,
    customerFormalNameSnapshot: selectedCustomer.formalName,
    subject: subject?.isNotEmpty == true ? subject : null,
    notes: null,
    latitude: latitude,
    longitude: longitude,
    isDraft: isDraft,
    includeTax: includeTax,
    isTaxInclusiveMode: isTaxInclusiveMode,
    priceAdjustmentType: priceAdjustmentType,
    priceAdjustmentUnit: priceAdjustmentUnit,
    bankAccount: bankAccount,
    projectId: projectId,
  );

  Invoice savedInvoice;
  if (generatePdf) {
    final path = await PdfGenerator.generateAndSaveInvoice(invoice);
    savedInvoice = invoice.copyWith(filePath: path);
    await invoiceRepo.saveInvoice(savedInvoice);
  } else {
    await invoiceRepo.saveInvoice(invoice);
    savedInvoice = invoice;
  }

  if (projectId != null) {
    await projectRepo.linkDocument(
      projectId: projectId,
      table: 'invoices',
      documentId: invoiceId,
    );
  }

  return savedInvoice;
}

Future<void> saveAsSalesInvoice({
  required SalesRepository salesRepo,
  required ProjectRepository projectRepo,
  required EditLogRepository editLogRepo,
  required String invoiceId,
  required Customer selectedCustomer,
  required List<InvoiceItem> items,
  required DateTime selectedDate,
  required double taxRate,
  required bool includeTax,
  required DocumentStatus salesStatus,
  required DateTime? salesPaymentDueDate,
  required String salesPaymentMethod,
  required String? selectedProjectId,
}) async {
  final sales = Sales(
    id: invoiceId,
    documentNumber: invoiceId.substring(0, 8),
    date: selectedDate,
    customer: selectedCustomer,
    items: items.map((i) => DocumentItem(
      id: const Uuid().v4(),
      productId: i.productId ?? '',
      productName: i.description,
      quantity: i.quantity,
      unitPrice: i.unitPrice,
      subtotal: i.unitPrice * i.quantity,
      taxRate: includeTax ? taxRate : 0.0,
    )).toList(),
    subtotal: items.fold(0, (s, i) => s + i.unitPrice * i.quantity),
    taxAmount: includeTax
        ? ((items.fold(0, (s, i) => s + i.unitPrice * i.quantity)) * taxRate).floor()
        : 0,
    total: items.fold(0, (s, i) => s + i.unitPrice * i.quantity) +
        (includeTax
            ? ((items.fold(0, (s, i) => s + i.unitPrice * i.quantity)) * taxRate).floor()
            : 0),
    taxRate: includeTax ? taxRate : 0.0,
    status: salesStatus,
    paymentDueDate: salesPaymentDueDate,
    paymentMethod: salesPaymentMethod,
    projectId: selectedProjectId,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );
  await salesRepo.saveSales(sales);
  if (selectedProjectId != null) {
    await projectRepo.linkDocument(
      projectId: selectedProjectId,
      table: 'sales',
      documentId: invoiceId,
    );
  }
  await editLogRepo.addLog(invoiceId, "売上伝票を保存しました");
}
