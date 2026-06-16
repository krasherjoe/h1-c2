import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../services/database_helper.dart';
import '../models/analysis_models.dart';
import '../services/analysis_repository.dart';
import '../../../constants/screen_ids.dart';

class SalesAnalysisScreen extends StatefulWidget {
  const SalesAnalysisScreen({super.key});
  @override
  State<SalesAnalysisScreen> createState() => _SalesAnalysisScreenState();
}

class _SalesAnalysisScreenState extends State<SalesAnalysisScreen> {
  final _repo = AnalysisRepository();
  final _nf = NumberFormat('#,###');

  bool _isLoading = true;
  List<MonthlySummary> _monthlyData = [];
  int _year = DateTime.now().year;
  int _totalRevenue = 0;
  int _totalOrders = 0;
  int _totalProfit = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final raw = await _repo.getMonthlySales(12);
      _monthlyData = raw.where((m) => m.year == _year).toList();
      _totalRevenue = _monthlyData.fold(0, (s, m) => s + m.salesAmount);
      _totalOrders = _monthlyData.fold(0, (s, m) => s + m.orderCount);

      final db = await DatabaseHelper().database;
      final yearStr = '$_year';
      final costRows = await db.rawQuery('''
        SELECT
          CAST(substr(d.date, 6, 2) AS INTEGER) as month,
          COALESCE(SUM(p.wholesale_price * di.quantity), 0) as cost
        FROM document_items di
        JOIN documents d ON d.id = di.document_id
        LEFT JOIN products p ON p.id = di.product_id
        WHERE d.status = 'confirmed'
          AND d.document_type IN ('invoice', 'receipt')
          AND substr(d.date, 1, 4) = ?
        GROUP BY substr(d.date, 1, 7)
        ORDER BY month
      ''', [yearStr]);

      int totalCost = 0;
      for (final c in costRows) {
        totalCost += (c['cost'] as num?)?.toInt() ?? 0;
      }
      _totalProfit = _totalRevenue - totalCost;

      if (!mounted) return;
      setState(() => _isLoading = false);
    } catch (e) {
      debugPrint('[SA] _loadData error: $e');
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('\${S.sa}:売上分析'),
        actions: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () => setState(() { _year--; _loadData(); }),
          ),
          Text('$_year', style: const TextStyle(fontSize: 16)),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () => setState(() { _year++; _loadData(); }),
          ),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _monthlyData.isEmpty
              ? const Center(child: Text('データがありません'))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
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
    final margin = _totalRevenue > 0
        ? (_totalProfit / _totalRevenue * 100).toStringAsFixed(1)
        : '0.0';
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _card('総売上', '¥${_nf.format(_totalRevenue)}', Icons.trending_up, cs.primary),
          const SizedBox(width: 8),
          _card('粗利益', '¥${_nf.format(_totalProfit)}', Icons.show_chart, Colors.green),
          const SizedBox(width: 8),
          _card('粗利率', '$margin%', Icons.percent, cs.tertiary),
          const SizedBox(width: 8),
          _card('請求件数', '${_nf.format(_totalOrders)}件', Icons.receipt, cs.secondary),
        ],
      ),
    );
  }

  Widget _card(String title, String value, IconData icon, Color color) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      child: SizedBox(
        width: 180,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      value,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: cs.onSurface,
                      ),
                    ),
                    Text(
                      title,
                      style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant),
                    ),
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
            Text(
              '月別詳細',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('月')),
                  DataColumn(label: Text('売上')),
                  DataColumn(label: Text('件数')),
                ],
                rows: _monthlyData.map((m) => DataRow(cells: [
                  DataCell(Text(m.label)),
                  DataCell(Text('¥${_nf.format(m.salesAmount)}')),
                  DataCell(Text('${m.orderCount}件')),
                ])).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
