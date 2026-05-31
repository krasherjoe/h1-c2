import 'package:flutter/material.dart';
import '../../../models/invoice_models.dart';
import '../../../models/customer_model.dart';
import '../../../services/invoice_repository.dart';
import '../../../services/pdf_generator.dart';
import '../../../services/app_settings_repository.dart';
import '../../../services/invoice_email_sender.dart';
import '../../../services/database_helper.dart';
import '../../../services/sys_logger.dart';

String _documentTypeLabel(DocumentType t) {
  switch (t) {
    case DocumentType.estimation:
      return '見積書';
    case DocumentType.order:
      return '受注伝票';
    case DocumentType.delivery:
      return '納品書';
    case DocumentType.invoice:
      return '請求書';
    case DocumentType.receipt:
      return '領収書';
  }
}

Future<Invoice?> createRedInvoice(
  BuildContext context, {
  required Customer selectedCustomer,
  required Invoice currentInvoice,
  required List<InvoiceItem> items,
  required DocumentType documentType,
  required double taxRate,
  required String subject,
  required bool includeTax,
  required bool isTaxInclusiveMode,
  required String? currentId,
  required InvoiceRepository invoiceRepo,
  String? bankAccount,
  String? priceAdjustmentType,
  int? priceAdjustmentUnit,
  String? terminalId,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('赤伝起票の確認'),
      content: Text(
        '「${_documentTypeLabel(documentType).replaceAll('書', '')}」${currentInvoice.invoiceNumber} の取消し（赤伝）を作成します。\n元の伝票は保持されたまま、全明細をマイナスにして自動ロックされます。',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('キャンセル'),
        ),
        ElevatedButton.icon(
          onPressed: () => Navigator.pop(ctx, true),
          style: ElevatedButton.styleFrom(backgroundColor: Theme.of(ctx).colorScheme.error, foregroundColor: Colors.white),
          icon: const Icon(Icons.undo),
          label: const Text('赤伝を起票'),
        ),
      ],
    ),
  );

  if (confirmed != true) return null;

  final negatedItems = items.map((e) => e.negate()).toList();
  final redInvoice = Invoice(
    customer: selectedCustomer,
    date: DateTime.now(),
    items: negatedItems,
    notes: '【赤伝】${currentInvoice.invoiceNumber} の取消し\n${currentInvoice.notes ?? ''}',
    documentType: documentType,
    taxRate: taxRate,
    isDraft: false,
    isLocked: true,
    subject: subject.isEmpty
        ? '赤伝：${currentInvoice.invoiceNumber}'
        : '赤伝：$subject',
    includeTax: includeTax,
    isTaxInclusiveMode: isTaxInclusiveMode,
    priceAdjustmentType: priceAdjustmentType,
    priceAdjustmentUnit: priceAdjustmentUnit,
    sourceDocumentId: currentId,
    terminalId: terminalId,
    bankAccount: bankAccount,
  );

  final pdfPath = await PdfGenerator.generateAndSaveInvoice(redInvoice);
  final saved = redInvoice.copyWith(filePath: pdfPath);
  await invoiceRepo.saveInvoice(saved);

  return saved;
}

Future<String?> trySendRedInvoiceEmail({
  required BuildContext context,
  required Invoice redInvoice,
  required String? customerEmail,
}) async {
  if (customerEmail == null || customerEmail.isEmpty) return null;
  try {
    final emailSender = InvoiceEmailSender();
    final result = await emailSender.sendEmailWithInvoice(
      redInvoice,
      pdfFilePath: redInvoice.filePath,
    );
    if (result.success) {
      if (result.sentAt != null) {
        try {
          final isoDate = DateTime.fromMillisecondsSinceEpoch(result.sentAt!).toIso8601String();
          final database = await DatabaseHelper().database;
          await database.update('invoices', {
            'email_sent_at': isoDate,
            'email_sent_to': customerEmail,
          }, where: 'id = ?', whereArgs: [redInvoice.id]);
        } catch (e) {
          debugPrint('trySendRedInvoiceEmail update sentAt error: $e');
        }
      }
      return '送信完了';
    }
    return '送信キャンセル';
  } catch (e) {
    SysLogger.instance.logError('InvIn', e);
    return '送信エラー: $e';
  }
}
