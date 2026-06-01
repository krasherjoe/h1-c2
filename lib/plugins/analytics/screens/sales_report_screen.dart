import 'package:flutter/material.dart';
import '../../../services/database_helper.dart';

class SalesReportScreen extends StatefulWidget {
  const SalesReportScreen({super.key});

  @override
  State<SalesReportScreen> createState() => _SalesReportScreenState();
}

class _SalesReportScreenState extends State<SalesReportScreen> {
  final _dbHelper = DatabaseHelper();
  List<Map<String, dynamic>> _monthlyData = [];
  bool _isLoading = true;
  String _period = 'month';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final db = await _dbHelper.database;
    final groupBy = _period == 'month'
        ? "substr(date, 1, 7)"
        : _period == 'quarter'
            ? "substr(date, 1, 4) || 'Q' || CAST((CAST(substr(date, 6, 2) AS INTEGER) + 2) / 3 AS TEXT)"
            : "substr(date, 1, 4)";
    final results = await db.rawQuery('''
      SELECT $groupBy as period, COUNT(*) as count, SUM(total) as total
      FROM documents
      WHERE document_type IN ('invoice','receipt') AND status = 'confirmed'
      GROUP BY period
      ORDER BY period DESC
      LIMIT 12
    ''');
    setState(() {
      _monthlyData = results;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('売上レポート'),
        actions: [
          DropdownButton<String>(
            value: _period,
            underline: const SizedBox(),
            items: const [
              DropdownMenuItem(value: 'month', child: Text('月別')),
              DropdownMenuItem(value: 'quarter', child: Text('四半期')),
              DropdownMenuItem(value: 'year', child: Text('年別')),
            ],
            onChanged: (v) {
              if (v != null) {
                setState(() => _period = v);
                _load();
              }
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _monthlyData.isEmpty
              ? const Center(child: Text('データがありません'))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    itemCount: _monthlyData.length,
                    itemBuilder: (ctx, i) {
                      final row = _monthlyData[i];
                      return ListTile(
                        title: Text(row['period'] as String),
                        subtitle: Text('${row['count']}件'),
                        trailing: Text(
                          '¥${_formatAmount((row['total'] as num?)?.toInt() ?? 0)}',
                          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      );
                    },
                  ),
                ),
    );
  }

  String _formatAmount(int amount) =>
    amount.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
}
