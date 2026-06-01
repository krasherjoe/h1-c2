import 'package:flutter/material.dart';
import '../../../services/database_helper.dart';
import 'sales_report_screen.dart';
import 'product_profit_screen.dart';
import 'customer_trend_screen.dart';

class AnalyticsDashboardScreen extends StatefulWidget {
  const AnalyticsDashboardScreen({super.key});

  @override
  State<AnalyticsDashboardScreen> createState() => _AnalyticsDashboardScreenState();
}

class _AnalyticsDashboardScreenState extends State<AnalyticsDashboardScreen> {
  final _dbHelper = DatabaseHelper();
  int _thisMonthTotal = 0;
  int _lastMonthTotal = 0;
  int _thisYearTotal = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final db = await _dbHelper.database;
    final now = DateTime.now();
    final thisMonth = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    final lastMonth = DateTime(now.year, now.month - 1);
    final lastMonthStr = '${lastMonth.year}-${lastMonth.month.toString().padLeft(2, '0')}';
    final thisYear = '${now.year}';

    final thisMonthResult = await db.rawQuery(
      "SELECT COALESCE(SUM(total), 0) as total FROM documents WHERE date LIKE ? AND document_type IN ('invoice','receipt') AND status = 'confirmed'",
      ['$thisMonth%'],
    );
    final lastMonthResult = await db.rawQuery(
      "SELECT COALESCE(SUM(total), 0) as total FROM documents WHERE date LIKE ? AND document_type IN ('invoice','receipt') AND status = 'confirmed'",
      ['$lastMonthStr%'],
    );
    final thisYearResult = await db.rawQuery(
      "SELECT COALESCE(SUM(total), 0) as total FROM documents WHERE date LIKE ? AND document_type IN ('invoice','receipt') AND status = 'confirmed'",
      ['$thisYear%'],
    );

    setState(() {
      _thisMonthTotal = (thisMonthResult.first['total'] as num?)?.toInt() ?? 0;
      _lastMonthTotal = (lastMonthResult.first['total'] as num?)?.toInt() ?? 0;
      _thisYearTotal = (thisYearResult.first['total'] as num?)?.toInt() ?? 0;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('分析')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildSummaryCard(theme, '今月の売上', _thisMonthTotal, Colors.blue),
                  const SizedBox(height: 12),
                  _buildSummaryCard(theme, '先月の売上', _lastMonthTotal, Colors.grey),
                  const SizedBox(height: 12),
                  _buildSummaryCard(theme, '今年の売上', _thisYearTotal, Colors.green),
                  const SizedBox(height: 24),
                  Text('レポート', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  ListTile(
                    leading: const Icon(Icons.bar_chart),
                    title: const Text('売上レポート'),
                    subtitle: const Text('月別売上推移'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SalesReportScreen()),
                    ),
                  ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.pie_chart),
                    title: const Text('商品別利益分析'),
                    subtitle: const Text('商品ごとの売上'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ProductProfitScreen()),
                    ),
                  ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.show_chart),
                    title: const Text('顧客別売上推移'),
                    subtitle: const Text('顧客ごとの売上ランキング'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const CustomerTrendScreen()),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildSummaryCard(ThemeData theme, String label, int amount, MaterialColor color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.trending_up, color: color.shade700),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: theme.textTheme.bodySmall),
                Text(
                  '¥${_formatAmount(amount)}',
                  style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatAmount(int amount) =>
    amount.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
}
