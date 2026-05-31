import 'package:flutter/material.dart';
import '../widgets/screen_id_title.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  static const _menuItems = [
    _MenuItem('DC1', '請求書入力', '請求書・領収証の発行', Icons.description, '/invoice/input'),
    _MenuItem('DC2', '請求書履歴', '発行済み伝票の一覧', Icons.history, '/invoice/history'),
    _MenuItem('DC3', '顧客マスター', '得意先の登録・編集', Icons.people, '/customer/master'),
    _MenuItem('DC4', '商品マスター', '商品の登録・編集', Icons.inventory_2, '/product/master'),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const ScreenAppBarTitle(screenId: 'DC', title: 'ダッシュボード'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final crossAxisCount = constraints.maxWidth > 600 ? 4 : 2;
            return GridView.builder(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 1.1,
              ),
              itemCount: _menuItems.length,
              itemBuilder: (context, index) => _buildCard(context, _menuItems[index], theme),
            );
          },
        ),
      ),
    );
  }

  Widget _buildCard(BuildContext context, _MenuItem item, ThemeData theme) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _navigate(context, item),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(item.icon, size: 48, color: theme.colorScheme.primary),
              const SizedBox(height: 12),
              Text(item.title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(item.subtitle, style: theme.textTheme.bodySmall, textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }

  void _navigate(BuildContext context, _MenuItem item) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${item.title} - 準備中')),
    );
  }
}

class _MenuItem {
  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  final String route;

  const _MenuItem(this.id, this.title, this.subtitle, this.icon, this.route);
}
