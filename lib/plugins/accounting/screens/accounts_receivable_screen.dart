import 'package:flutter/material.dart';
import '../services/accounting_repository.dart';

class AccountsReceivableScreen extends StatefulWidget {
  const AccountsReceivableScreen({super.key});

  @override
  State<AccountsReceivableScreen> createState() => _AccountsReceivableScreenState();
}

class _AccountsReceivableScreenState extends State<AccountsReceivableScreen> {
  final _repo = AccountingRepository();
  List<Map<String, dynamic>> _data = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final data = await _repo.getAccountsReceivable();
    setState(() {
      _data = data;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('売掛管理')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _data.isEmpty
              ? const Center(child: Text('売掛金はありません'))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    itemCount: _data.length,
                    itemBuilder: (ctx, i) {
                      final row = _data[i];
                      final total = (row['total_amount'] as num?)?.toInt() ?? 0;
                      final paid = (row['paid_amount'] as num?)?.toInt() ?? 0;
                      final balance = total - paid;
                      return ListTile(
                        title: Text(row['customer_name'] as String? ?? ''),
                        subtitle: Text('${row['invoice_count']}件'),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '¥${_formatAmount(balance)}',
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: balance > 0 ? Colors.red : Colors.green,
                              ),
                            ),
                            Text(
                              '¥${_formatAmount(paid)} 入金済',
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
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
