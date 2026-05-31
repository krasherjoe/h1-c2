import 'package:flutter/material.dart';
import '../../../models/invoice_models.dart';
import '../../../services/invoice_repository.dart';
import '../../../services/edit_log_repository.dart';
import '../../../services/pdf_generator.dart' show PdfGenerator;
import '../../../services/database_helper.dart';
import '../../../screens/invoice_preview_page.dart';

Future<({bool isDraft, bool isLocked})?> showInvoicePreview(
  BuildContext context, {
  required Invoice invoice,
  required InvoiceRepository invoiceRepo,
  required EditLogRepository editLogRepo,
  required String currentId,
}) async {
  final id = invoice.id;

  await Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => InvoicePdfPreviewPage(
        invoice: invoice,
        isUnlocked: true,
        isLocked: invoice.isLocked,
        allowFormalIssue: invoice.isDraft && !invoice.isLocked,
        onFormalIssue: invoice.isDraft && !invoice.isLocked
            ? () async {
                final promoted = invoice.copyWith(
                  id: id,
                  isDraft: false,
                  isLocked: true,
                );
                await invoiceRepo.saveInvoice(promoted);
                final newPath = await PdfGenerator.generateAndSaveInvoice(promoted);
                final saved = promoted.copyWith(filePath: newPath);
                await invoiceRepo.saveInvoice(saved);
                await editLogRepo.addLog(id, "正式発行しました");
              }
            : null,
        showShare: true,
        showEmail: true,
        showPrint: true,
        onShare: () => editLogRepo.addLog(id, "PDFを共有しました"),
        onEmail: () => editLogRepo.addLog(id, "メール送信しました"),
        onPrint: () async {
          await editLogRepo.addLog(id, "印刷しました");
          final db = await DatabaseHelper().database;
          await db.update('invoices', {'printed_at': DateTime.now().toIso8601String()},
              where: 'id = ?', whereArgs: [id]);
        },
      ),
    ),
  );

  try {
    final db = await DatabaseHelper().database;
    final rows = await db.query('invoices',
        where: 'id = ? AND is_current = 1', whereArgs: [currentId], limit: 1);
    if (rows.isNotEmpty) {
      return (
        isDraft: (rows.first['is_draft'] as int? ?? 1) == 1,
        isLocked: (rows.first['is_locked'] as int? ?? 0) == 1,
      );
    }
  } catch (e) {
    debugPrint('[_InvoiceInputFormState] showInvoicePreview reload error: $e');
  }

  return null;
}
