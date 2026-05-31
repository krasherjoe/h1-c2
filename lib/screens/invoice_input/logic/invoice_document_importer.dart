import 'package:flutter/material.dart';
import '../../../models/invoice_models.dart';
import '../../../services/database_helper.dart';
import '../../../screens/invoice_history/invoice_history_screen.dart';

Future<Map<String, dynamic>?> importItemsFromDocuments(
  BuildContext context,
) async {
  final selected = await Navigator.push<List<Map<String, dynamic>>>(
    context,
    MaterialPageRoute(
      builder: (_) => const InvoiceHistoryScreen(isPickerMode: true),
    ),
  );
  if (selected == null || selected.isEmpty) return null;

  final db = await DatabaseHelper().database;
  final newItems = <InvoiceItem>[];
  String? firstCustomerId;
  String? firstSubject;

  for (final doc in selected) {
    final source = doc['_source'] as String?;
    final id = doc['id'] as String?;
    if (source == null || id == null) continue;

    if (source == 'invoice') {
      final rows = await db.query('invoice_items',
          where: 'invoice_id = ?', whereArgs: [id]);
      for (final row in rows) {
        newItems.add(InvoiceItem(
          productId: row['product_id'] as String?,
          description: row['description'] as String? ?? '',
          quantity: row['quantity'] as int? ?? 1,
          unitPrice: row['unit_price'] as int? ?? 0,
        ));
      }
      if (firstCustomerId == null) {
        final inv = await db.query('invoices',
            where: 'id = ?', whereArgs: [id], limit: 1);
        if (inv.isNotEmpty) {
          firstCustomerId = inv.first['customer_id'] as String?;
          firstSubject = inv.first['subject'] as String?;
        }
      }
    } else if (source == 'sales') {
      final rows = await db.query('sales_items',
          where: 'sales_id = ?', whereArgs: [id]);
      for (final row in rows) {
        newItems.add(InvoiceItem(
          productId: row['product_id'] as String?,
          description: row['product_name'] as String? ?? '',
          quantity: row['quantity'] as int? ?? 1,
          unitPrice: row['unit_price'] as int? ?? 0,
        ));
      }
      if (firstCustomerId == null) {
        final sale = await db.query('sales',
            where: 'id = ?', whereArgs: [id], limit: 1);
        if (sale.isNotEmpty) {
          firstCustomerId = sale.first['customer_id'] as String?;
          firstSubject = sale.first['subject'] as String?;
        }
      }
    }
  }

  return {
    'items': newItems,
    'customerId': firstCustomerId,
    'subject': firstSubject,
    'selectedCount': selected.length,
  };
}
