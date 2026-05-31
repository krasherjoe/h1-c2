import 'package:flutter/foundation.dart';
import '../../../models/invoice_models.dart';
import '../../../models/customer_model.dart';
import '../../../models/payment_schedule_model.dart' show PaymentStatus;
import '../../../services/database_helper.dart';

Future<Invoice?> loadSourceInvoice(
  String? sourceDocumentId, {
  required DocumentType currentDocumentType,
}) async {
  final sid = sourceDocumentId;
  if (sid == null) return null;
  try {
    final db = await DatabaseHelper().database;
    final rows = await db.query('invoices',
      where: 'id = ?', whereArgs: [sid], limit: 1);
    if (rows.isEmpty) return null;
    final iMap = rows.first;
    final custId = iMap['customer_id'] as String?;
    final custRows = custId != null
      ? await db.query('customers', where: 'id = ?', whereArgs: [custId], limit: 1)
      : null;
    final customer = custRows != null && custRows.isNotEmpty
      ? Customer.fromMap(custRows.first)
      : Customer(id: '', displayName: '不明', formalName: '不明');
    final itemRows = await db.query('invoice_items',
      where: 'invoice_id = ?', whereArgs: [sid]);
    final items = itemRows.map((r) => InvoiceItem(
      description: r['description'] as String? ?? '',
      quantity: r['quantity'] as int? ?? 1,
      unitPrice: r['unit_price'] as int? ?? 0,
      productId: r['product_id'] as String?,
    )).toList();

    return Invoice(
      id: iMap['id'] as String?,
      customer: customer,
      date: DateTime.tryParse(iMap['date'] as String? ?? '') ?? DateTime.now(),
      items: items,
      notes: iMap['notes'] as String?,
      taxRate: (iMap['tax_rate'] as num?)?.toDouble() ?? 0.10,
      documentType: currentDocumentType,
      isDraft: (iMap['is_draft'] as int? ?? 0) == 1,
      isLocked: (iMap['is_locked'] as int? ?? 0) == 1,
      sourceDocumentId: iMap['source_document_id'] as String?,
      subject: iMap['subject'] as String?,
      filePath: iMap['file_path'] as String?,
      paymentStatus: PaymentStatus.values.firstWhere(
        (s) => s.name == (iMap['payment_status'] as String? ?? 'unpaid'),
        orElse: () => PaymentStatus.unpaid,
      ),
      receivedAmount: iMap['received_amount'] as int? ?? 0,
    );
  } catch (e) {
    debugPrint('元伝票読込エラー: $e');
    return null;
  }
}
