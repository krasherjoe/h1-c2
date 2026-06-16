import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../services/database_helper.dart';
import '../../../constants/screen_ids.dart';

class MonthlyReportScreen extends StatefulWidget {
  const MonthlyReportScreen({super.key});
  @override
  State<MonthlyReportScreen> createState() => _MonthlyReportScreenState();
}

class _MonthlyReportScreenState extends State<MonthlyReportScreen> {
  final _nf = NumberFormat('#,###');
  int _year = DateTime.now().year;
  bool _loading = true;

  List<_MonthRow> _rows = [];
  int _totalSales = 0;
  int _totalPurchases = 0;
  int _totalCost = 0;
  int _totalProfit = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final db = await DatabaseHelper().database;
      final yearStr = '$_year';

      final salesRows = await db.rawQuery('''
        SELECT CAST(substr(date, 6, 2) AS INTEGER) as month,
               SUM(total) as amount
        FROM documents
        WHERE status = 'confirmed'
          AND document_type IN ('invoice', 'receipt')
          AND substr(date, 1, 4) = ?
        GROUP BY substr(date, 1, 7)
        ORDER BY month
      ''', [yearStr]);

      final costRows = await db.rawQuery('''
        SELECT CAST(substr(d.date, 6, 2) AS INTEGER) as month,
               COALESCE(SUM(p.wholesale_price * di.quantity), 0) as amount
        FROM document_items di
        JOIN documents d ON d.id = di.document_id
        LEFT JOIN products p ON p.id = di.product_id
        WHERE d.status = 'confirmed'
          AND d.document_type IN ('invoice', 'receipt')
          AND substr(d.date, 1, 4) = ?
        GROUP BY substr(d.date, 1, 7)
        ORDER BY month
      ''', [yearStr]);

      final purchaseRows = await db.rawQuery('''
        SELECT CAST(substr(date, 6, 2) AS INTEGER) as month,
               SUM(total) as amount
        FROM purchases
        WHERE status NOT IN ('draft', 'cancelled')
          AND substr(date, 1, 4) = ?
        GROUP BY substr(date, 1, 7)
        ORDER BY month
      ''', [yearStr]);

      Map<int, int> salesMap = {};
      Map<int, int> costMap = {};
      Map<int, int> purchaseMap = {};

      for (final r in salesRows) {
        salesMap[r['month'] as int] = (r['amount'] as num?)?.toInt() ?? 0;
      }
      for (final r in costRows) {
        costMap[r['month'] as int] = (r['amount'] as num?)?.toInt() ?? 0;
      }
      for (final r in purchaseRows) {
        purchaseMap[r['month'] as int] = (r['amount'] as num?)?.toInt() ?? 0;
      }

      final rows = <_MonthRow>[];
      int ts = 0, tp = 0, tc = 0;
      for (int m = 1; m <= 12; m++) {
        final sales = salesMap[m] ?? 0;
        final cost = costMap[m] ?? 0;
        final purchases = purchaseMap[m] ?? 0;
        final grossProfit = sales - cost;
        final profit = grossProfit - purchases;
        rows.add(_MonthRow(
          month: m, sales: sales, cost: cost,
          purchases: purchases, grossProfit: grossProfit, profit: profit,
        ));
        ts += sales; tc += cost; tp += purchases;
      }
      _totalSales = ts; _totalCost = tc; _totalPurchases = tp;
      _totalProfit = ts - tc - tp;

      if (!mounted) return;
      setState(() { _rows = rows; _loading = false; });
    } catch (e) {
      debugPrint('[FP1] _load error: $e');
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('${S.fp1}:月次収支'),
        actions: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () { _year--; _load(); },
          ),
          Text('$_year', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () { _year++; _load(); },
          ),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSummaryCards(cs),
                  const SizedBox(height: 16),
                  _buildTable(cs),
                ],
              ),
            ),
    );
  }

  Widget _buildSummaryCards(ColorScheme cs) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _card('総売上', '¥${_nf.format(_totalSales)}', Icons.trending_up, cs.primary),
          const SizedBox(width: 8),
          _card('仕入計', '¥${_nf.format(_totalPurchases)}', Icons.shopping_cart, cs.secondary),
          const SizedBox(width: 8),
          _card('粗利', '¥${_nf.format(_totalSales - _totalCost)}', Icons.show_chart, cs.tertiary),
          const SizedBox(width: 8),
          _card('利益', '¥${_nf.format(_totalProfit)}', Icons.account_balance, _totalProfit >= 0 ? cs.primary : cs.error),
        ],
      ),
    );
  }

  Widget _card(String title, String value, IconData icon, Color color) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      child: SizedBox(
        width: 170,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 34, height: 34,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(value, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: cs.onSurface)),
                    Text(title, style: TextStyle(fontSize: 9, color: cs.onSurfaceVariant)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTable(ColorScheme cs) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('月別収支', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: cs.onSurface)),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(cs.surfaceContainerHighest.withValues(alpha: 0.3)),
                columns: [
                  DataColumn(label: Text('月', style: TextStyle(fontWeight: FontWeight.bold, color: cs.onSurface))),
                  DataColumn(label: Text('売上', style: TextStyle(fontWeight: FontWeight.bold, color: cs.onSurface))),
                  DataColumn(label: Text('仕入', style: TextStyle(fontWeight: FontWeight.bold, color: cs.onSurface))),
                  DataColumn(label: Text('原価', style: TextStyle(fontWeight: FontWeight.bold, color: cs.onSurface))),
                  DataColumn(label: Text('粗利', style: TextStyle(fontWeight: FontWeight.bold, color: cs.onSurface))),
                  DataColumn(label: Text('利益', style: TextStyle(fontWeight: FontWeight.bold, color: cs.onSurface))),
                ],
                rows: [
                  for (final r in _rows)
                    DataRow(cells: [
                      DataCell(Text('${r.month}月')),
                      DataCell(Text('¥${_nf.format(r.sales)}', style: const TextStyle(fontSize: 12))),
                      DataCell(Text('¥${_nf.format(r.purchases)}', style: const TextStyle(fontSize: 12))),
                      DataCell(Text('¥${_nf.format(r.cost)}', style: const TextStyle(fontSize: 12))),
                      DataCell(Text('¥${_nf.format(r.grossProfit)}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: r.grossProfit >= 0 ? cs.tertiary : cs.error))),
                      DataCell(Text('¥${_nf.format(r.profit)}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: r.profit >= 0 ? cs.primary : cs.error))),
                    ]),
                  DataRow(
                    color: WidgetStateProperty.all(cs.primaryContainer.withValues(alpha: 0.3)),
                    cells: [
                      DataCell(Text('合計', style: TextStyle(fontWeight: FontWeight.bold, color: cs.onSurface))),
                      DataCell(Text('¥${_nf.format(_totalSales)}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: cs.primary))),
                      DataCell(Text('¥${_nf.format(_totalPurchases)}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: cs.secondary))),
                      DataCell(Text('¥${_nf.format(_totalCost)}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                      DataCell(Text('¥${_nf.format(_totalSales - _totalCost)}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: cs.tertiary))),
                      DataCell(Text('¥${_nf.format(_totalProfit)}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: _totalProfit >= 0 ? cs.primary : cs.error))),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MonthRow {
  final int month;
  final int sales;
  final int purchases;
  final int cost;
  final int grossProfit;
  final int profit;
  const _MonthRow({
    required this.month, required this.sales, required this.purchases,
    required this.cost, required this.grossProfit, required this.profit,
  });
}
