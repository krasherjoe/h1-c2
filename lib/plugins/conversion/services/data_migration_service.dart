import 'package:sqflite/sqflite.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DataMigrationService {
  static const _conversionDoneKey = 'conversion_v1_to_v2_done';

  static Future<bool> needsConversion(Database db) async {
    final tables = await db
        .rawQuery("SELECT name FROM sqlite_master WHERE type='table' AND name='documents'");
    return tables.isNotEmpty;
  }

  static Future<void> runConversion(
    Database db,
    SharedPreferences prefs,
  ) async {
    final done = prefs.getBool(_conversionDoneKey) ?? false;
    if (done) return;

    final hasOld = await needsConversion(db);
    if (!hasOld) {
      await prefs.setBool(_conversionDoneKey, true);
      return;
    }

    final oldDocs = await db.rawQuery('SELECT * FROM documents');
    for (final row in oldDocs) {
      final id = row['id'] as String? ?? '';
      if (id.isEmpty) continue;

      final exists = await db.rawQuery(
        'SELECT id FROM invoices WHERE id = ?',
        [id],
      );
      if (exists.isNotEmpty) continue;

      await db.insert('invoices', {
        'id': id,
        'customer_id': row['customer_id'] ?? '',
        'date': row['date'] ?? '',
        'notes': row['notes'],
        'subject': row['subject'],
        'total_amount': row['total_amount'] ?? 0,
        'tax_rate': row['tax_rate'] ?? 0.10,
        'document_type': row['document_type'] ?? 'invoice',
        'order_status': row['order_status'] ?? row['status'] ?? 'draft',
        'source_document_id': row['source_document_id'],
        'customer_formal_name': row['customer_formal_name'],
        'updated_at': row['updated_at'] ?? DateTime.now().toIso8601String(),
        'meta_json': row['meta_json'],
      });

      final oldItems = await db.rawQuery(
        'SELECT * FROM document_items WHERE document_id = ?',
        [id],
      );
      for (final item in oldItems) {
        await db.insert('invoice_items', {
          'id': item['id'],
          'invoice_id': id,
          'product_id': item['product_id'],
          'description': item['description'] ?? '',
          'quantity': item['quantity'] ?? 1,
          'unit_price': item['unit_price'] ?? 0,
        });
      }
    }

    await db.execute('DROP TABLE IF EXISTS document_items');
    await db.execute('DROP TABLE IF EXISTS documents');

    await prefs.setBool(_conversionDoneKey, true);
  }
}
