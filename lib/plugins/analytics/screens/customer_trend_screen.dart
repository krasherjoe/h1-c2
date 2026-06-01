import 'dart:math';
import 'package:flutter/material.dart';
import '../../../services/database_helper.dart';

class CustomerTrendScreen extends StatefulWidget {
  const CustomerTrendScreen({super.key});

  @override
  State<CustomerTrendScreen> createState() => _CustomerTrendScreenState();
}

class _CustomerTrendScreenState extends State<CustomerTrendScreen> {
  final _dbHelper = DatabaseHelper();
  List<Map<String, dynamic>> _data = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final db = await _dbHelper.database;
    final results = await db.rawQuery('''
      SELECT
        customer_id,
        customer_name,
        COUNT(*) as doc_count,
        SUM(total) as total_amount
      FROM documents
      WHERE document_type IN ('invoice','receipt') AND status = 'confirmed'
      GROUP BY customer_id, customer_name
      ORDER BY total_amount DESC
      LIMIT 30
    ''');
    setState(() {
      _data = results;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('顧客別売上推移')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _data.isEmpty
              ? const Center(child: Text('データがありません'))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    itemCount: min(_data.length, 30),
                    itemBuilder: (ctx, i) {
                      final row = _data[i];
                      final rank = i + 1;
                      final amount = (row['total_amount'] as num?)?.toInt() ?? 0;
                      return ListTile(
                        leading: CircleAvatar(
                          child: Text('$rank'),
                        ),
                        title: Text(row['customer_name'] as String? ?? '(不明)'),
                        subtitle: Text('${row['doc_count']}件'),
                        trailing: Text(
                          '¥${_formatAmount(amount)}',
                          style: theme.textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.bold),
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
