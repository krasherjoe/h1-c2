import 'package:flutter/foundation.dart';
import '../../../services/database_helper.dart';
import '../models/ar_models.dart';

class AggregationEngine {
  final DatabaseHelper _db;

  AggregationEngine([DatabaseHelper? db]) : _db = db ?? DatabaseHelper();

  String get _currentFilter => 'is_current = 1';
  String get _draftFilter => 'is_draft = 0';
  String get _arBaseFilter => '$_currentFilter AND $_draftFilter';

  Future<List<ArLedgerRow>> arLedger() async {
    try {
      final db = await _db.database;
      final rows = await db.rawQuery('''
        SELECT customer_formal_name as customer_name,
               SUM(total_amount) as total,
               SUM(CASE WHEN payment_status = 'paid' THEN total_amount ELSE 0 END) as paid,
               MAX(date) as last_date,
               COUNT(*) as cnt
        FROM invoices
        WHERE $_arBaseFilter AND document_type = 'invoice'
        GROUP BY customer_formal_name
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
        SELECT id, customer_formal_name, date, total_amount, received_amount,
               payment_status, source_document_id
        FROM invoices
        WHERE $_currentFilter AND is_draft = 0 AND document_type = 'invoice'
          AND NOT EXISTS (
            SELECT 1 FROM invoices red
            WHERE red.source_document_id = invoices.id AND red.total_amount < 0
          )
        ORDER BY date DESC, customer_formal_name ASC
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
