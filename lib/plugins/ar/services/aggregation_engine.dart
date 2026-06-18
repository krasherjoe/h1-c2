import 'package:flutter/foundation.dart';
import '../../../services/database_helper.dart';
import '../models/ar_models.dart';

class AggregationEngine {
  final DatabaseHelper _db;

  AggregationEngine([DatabaseHelper? db]) : _db = db ?? DatabaseHelper();

  String get _arFilter => "is_current = 1 AND status = 'confirmed'";

  Future<List<ArLedgerRow>> arLedger() async {
    try {
      final db = await _db.database;
      final rows = await db.rawQuery('''
        SELECT customer_name,
               SUM(total) as total,
               SUM(CASE WHEN payment_status = 'paid' THEN total ELSE 0 END) as paid,
               MAX(date) as last_date,
               COUNT(*) as cnt
        FROM documents
        WHERE $_arFilter AND document_type = 'invoice' AND deleted_at IS NULL
        GROUP BY customer_name
        ORDER BY total DESC
      ''');
      return rows.map((r) => ArLedgerRow.fromMap(r)).toList();
    } catch (e) {
      debugPrint('[AR:Agg] arLedger error: $e');
      rethrow;
    }
  }

  Future<List<ArInvoiceRow>> arInvoiceList() async {
    try {
      final db = await _db.database;
      final rows = await db.rawQuery('''
        SELECT id, customer_name, date, total as total_amount, received_amount,
               payment_status, linked_document_id as source_document_id
        FROM documents
        WHERE is_current = 1 AND status = 'confirmed' AND document_type = 'invoice'
          AND deleted_at IS NULL
          AND (payment_status IS NULL OR payment_status != 'paid')
        ORDER BY date DESC, customer_name ASC
      ''');
      return rows.map((r) => ArInvoiceRow.fromMap(r)).toList();
    } catch (e) {
      debugPrint('[AR:Agg] arInvoiceList error: $e');
      rethrow;
    }
  }

  Future<List<ApLedgerRow>> apLedger() async {
    try {
      final db = await _db.database;
      final rows = await db.rawQuery('''
        SELECT COALESCE(s.display_name, '') as supplier_name,
               SUM(p.total) as total,
               SUM(CASE WHEN p.payment_status = 'paid' THEN p.total ELSE 0 END) as paid,
               MAX(p.date) as last_date,
               COUNT(*) as cnt
        FROM purchases p
        LEFT JOIN suppliers s ON p.supplier_id = s.id
        WHERE p.status != 'draft'
        GROUP BY p.supplier_id
        ORDER BY total DESC
      ''');
      return rows.map((r) => ApLedgerRow.fromMap(r)).toList();
    } catch (e) {
      debugPrint('[AR:Agg] apLedger error: $e');
      rethrow;
    }
  }
}
