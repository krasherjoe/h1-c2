import '../../../services/database_helper.dart';
import '../models/analysis_models.dart';

class AnalysisRepository {
  final DatabaseHelper _dbHelper;

  AnalysisRepository({DatabaseHelper? databaseHelper})
      : _dbHelper = databaseHelper ?? DatabaseHelper();

  Future<List<MonthlySummary>> getMonthlySales(int months) async {
    final db = await _dbHelper.database;
    final since = DateTime.now().subtract(Duration(days: months * 30));
    final sinceStr = since.toIso8601String().substring(0, 10);

    final rows = await db.rawQuery('''
      SELECT
        CAST(substr(date, 1, 4) AS INTEGER) as year,
        CAST(substr(date, 6, 2) AS INTEGER) as month,
        SUM(total) as sales_amount,
        COUNT(*) as order_count
      FROM documents
      WHERE status = 'confirmed'
        AND document_type IN ('invoice', 'receipt')
        AND date >= ?
      GROUP BY substr(date, 1, 7)
      ORDER BY year, month
    ''', [sinceStr]);

    return rows.map((r) => MonthlySummary.fromMap(r)).toList();
  }

  Future<List<ProductProfit>> getProductProfits(DateTime from, DateTime to) async {
    final db = await _dbHelper.database;
    final fromStr = from.toIso8601String().substring(0, 10);
    final toStr = to.toIso8601String().substring(0, 10);

    final rows = await db.rawQuery('''
      SELECT
        di.product_id,
        di.product_name,
        SUM(di.quantity) as quantity,
        SUM(di.unit_price * di.quantity) as sales_amount,
        COALESCE(SUM(p.wholesale_price * di.quantity), 0) as cost_amount
      FROM document_items di
      JOIN documents d ON d.id = di.document_id
      LEFT JOIN products p ON p.id = di.product_id
      WHERE d.status = 'confirmed'
        AND d.document_type IN ('invoice', 'receipt')
        AND d.date >= ? AND d.date <= ?
      GROUP BY di.product_id, di.product_name
      ORDER BY sales_amount DESC
    ''', [fromStr, toStr]);

    return rows.map((r) => ProductProfit.fromMap(r)).toList();
  }

  Future<Map<String, dynamic>> getArAging() async {
    final db = await _dbHelper.database;
    final rows = await db.rawQuery('''
      SELECT
        CASE
          WHEN julianday('now') - julianday(date) <= 30 THEN '0-30'
          WHEN julianday('now') - julianday(date) <= 60 THEN '31-60'
          WHEN julianday('now') - julianday(date) <= 90 THEN '61-90'
          ELSE '90+'
        END as bucket,
        SUM(total) as amount,
        COUNT(*) as count
      FROM documents
      WHERE status = 'confirmed'
        AND document_type IN ('invoice', 'receipt')
      GROUP BY bucket
      ORDER BY bucket
    ''');

    int total = 0;
    final buckets = <String, int>{};
    for (final r in rows) {
      final amt = (r['amount'] as num?)?.toInt() ?? 0;
      buckets[r['bucket'] as String? ?? ''] = amt;
      total += amt;
    }

    return {
      'buckets': buckets,
      'total': total,
      'count': rows.length,
    };
  }

  Future<Map<String, int>> getDashboardSummary() async {
    final db = await _dbHelper.database;
    final now = DateTime.now();
    final todayStr = now.toIso8601String().substring(0, 10);
    final thisMonthStr = '${now.year}-${now.month.toString().padLeft(2, '0')}';

    final lastMonth = DateTime(now.year, now.month - 1, 1);
    final lastMonthStr = '${lastMonth.year}-${lastMonth.month.toString().padLeft(2, '0')}';

    final thisMonth = await db.rawQuery(
      "SELECT COALESCE(SUM(total), 0) as total FROM documents WHERE date LIKE ? AND status = 'confirmed' AND document_type IN ('invoice', 'receipt')",
      ['$thisMonthStr%'],
    );
    final lastMonthVal = await db.rawQuery(
      "SELECT COALESCE(SUM(total), 0) as total FROM documents WHERE date LIKE ? AND status = 'confirmed' AND document_type IN ('invoice', 'receipt')",
      ['$lastMonthStr%'],
    );
    final today = await db.rawQuery(
      "SELECT COALESCE(SUM(total), 0) as total FROM documents WHERE date = ? AND status = 'confirmed' AND document_type IN ('invoice', 'receipt')",
      [todayStr],
    );

    final unpaid = await db.rawQuery(
      "SELECT COALESCE(SUM(total_amount - received_amount), 0) as total FROM invoices WHERE payment_status != 'paid' AND is_draft = 0",
    );

    return {
      'this_month': (thisMonth.first['total'] as num?)?.toInt() ?? 0,
      'last_month': (lastMonthVal.first['total'] as num?)?.toInt() ?? 0,
      'today': (today.first['total'] as num?)?.toInt() ?? 0,
      'unpaid': (unpaid.first['total'] as num?)?.toInt() ?? 0,
    };
  }
}
