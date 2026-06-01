import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../../../services/database_helper.dart';

class AccountingRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  Future<Database> get _db => _dbHelper.database;

  Future<void> savePayment(Map<String, dynamic> payment) async {
    final db = await _db;
    await db.insert('payments', payment, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, dynamic>>> fetchPayments({String? customerId, String? supplierId}) async {
    final db = await _db;
    final conditions = <String>[];
    final args = <dynamic>[];
    if (customerId != null) {
      conditions.add('customer_id = ?');
      args.add(customerId);
    }
    if (supplierId != null) {
      conditions.add('supplier_id = ?');
      args.add(supplierId);
    }
    final where = conditions.isNotEmpty ? 'WHERE ${conditions.join(' AND ')}' : '';
    return db.rawQuery('''
      SELECT * FROM payments
      $where
      ORDER BY date DESC
    ''', args);
  }

  Future<List<Map<String, dynamic>>> getAccountsReceivable() async {
    final db = await _db;
    return db.rawQuery('''
      SELECT
        d.customer_id,
        d.customer_name,
        COUNT(*) as invoice_count,
        SUM(d.total) as total_amount,
        COALESCE((
          SELECT SUM(p.amount) FROM payments p
          WHERE p.document_id = d.id AND p.type = 'received'
        ), 0) as paid_amount
      FROM documents d
      WHERE d.document_type = 'invoice' AND d.status = 'confirmed'
      GROUP BY d.customer_id, d.customer_name
      HAVING total_amount > paid_amount
      ORDER BY customer_name ASC
    ''');
  }

  Future<List<Map<String, dynamic>>> getPaymentSchedule() async {
    final db = await _db;
    return db.rawQuery('''
      SELECT
        substr(p.date, 1, 7) as month,
        p.supplier_name,
        p.total as amount,
        p.document_number
      FROM purchases p
      WHERE p.status = 'confirmed' AND p.purchase_type = 'receipt'
      ORDER BY p.date ASC
    ''');
  }

  Future<Map<String, int>> getCashFlow() async {
    final db = await _db;
    final inflow = await db.rawQuery(
      "SELECT COALESCE(SUM(total), 0) as total FROM documents WHERE document_type IN ('invoice','receipt') AND status = 'confirmed'",
    );
    final outflow = await db.rawQuery(
      "SELECT COALESCE(SUM(total), 0) as total FROM purchases WHERE status = 'confirmed' AND purchase_type = 'receipt'",
    );
    return {
      'inflow': (inflow.first['total'] as num?)?.toInt() ?? 0,
      'outflow': (outflow.first['total'] as num?)?.toInt() ?? 0,
    };
  }

  String generateId() => const Uuid().v4();
}
