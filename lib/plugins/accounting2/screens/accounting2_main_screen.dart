import 'package:flutter/material.dart';
import 'account_list_screen.dart';
import 'cash_book_screen.dart';
import 'journal_screen.dart';
import 'ledger_screen.dart';
import 'trial_balance_screen.dart';
import 'financial_statements_screen.dart';

class Accounting2MainScreen extends StatelessWidget {
  const Accounting2MainScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('KJ:会計')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _menuCard(context, cs, Icons.account_balance, '勘定科目', '科目の追加・編集・削除', () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const AccountListScreen()));
          }),
          const SizedBox(height: 8),
          _menuCard(context, cs, Icons.monetization_on, '現金出納帳', '日々の現金入出金を記録', () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const CashBookScreen()));
          }),
          const SizedBox(height: 8),
          _menuCard(context, cs, Icons.book, '仕訳帳', '全仕訳の確認・手動編集', () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const JournalScreen()));
          }),
          const SizedBox(height: 8),
          _menuCard(context, cs, Icons.view_list, '総勘定元帳', '科目別取引一覧', () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const LedgerScreen()));
          }),
          const SizedBox(height: 8),
          _menuCard(context, cs, Icons.table_chart, '試算表', '合計残高試算表', () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const TrialBalanceScreen()));
          }),
          const SizedBox(height: 8),
          _menuCard(context, cs, Icons.description, '決算書', '貸借対照表・損益計算書', () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const FinancialStatementsScreen()));
          }),
        ],
      ),
    );
  }

  Widget _menuCard(BuildContext context, ColorScheme cs, IconData icon, String title, String subtitle, VoidCallback onTap) {
    return Card(
      child: ListTile(
        leading: Icon(icon, color: cs.primary),
        title: Text(title, style: TextStyle(fontWeight: FontWeight.w600, color: cs.onSurface)),
        subtitle: Text(subtitle, style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
