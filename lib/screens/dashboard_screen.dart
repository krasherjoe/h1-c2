import 'package:flutter/material.dart';
import '../widgets/screen_id_title.dart';
import '../plugin_system/plugin_registry.dart';
import '../plugin_system/menu_item.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _registry = PluginRegistry.instance;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pluginMenus = _registry.getMenuItemsByCategory();

    return Scaffold(
      appBar: AppBar(
        title: const ScreenAppBarTitle(screenId: 'DC', title: 'ダッシュボード'),
        centerTitle: true,
        actions: [
          if (_registry.hasPlugins)
            IconButton(
              icon: const Icon(Icons.extension),
              onPressed: () => Navigator.pushNamed(context, '/plugins'),
              tooltip: 'プラグイン管理',
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildCategorySection(context, 'コア機能', _getCoreMenuItems(), theme),
          ...pluginMenus.entries.map((entry) =>
              _buildCategorySection(context, entry.key, entry.value, theme)),
        ],
      ),
    );
  }

  List<MenuItem> _getCoreMenuItems() {
    return const [
      MenuItem(
        id: 'II', title: '請求書入力', route: '/invoice/input',
        category: '', icon: Icons.description,
        description: '請求書・領収証の発行',
      ),
      MenuItem(
        id: 'IH', title: '請求書履歴', route: '/invoice/history',
        category: '', icon: Icons.history,
        description: '発行済み伝票の一覧',
      ),
      MenuItem(
        id: 'C1', title: '顧客マスター', route: '/customer/master',
        category: '', icon: Icons.people,
        description: '得意先の登録・編集',
      ),
      MenuItem(
        id: 'P1', title: '商品マスター', route: '/product/master',
        category: '', icon: Icons.inventory_2,
        description: '商品の登録・編集',
      ),
    ];
  }

  Widget _buildCategorySection(
    BuildContext context,
    String title,
    List<MenuItem> items,
    ThemeData theme,
  ) {
    if (items.isEmpty) return const SizedBox.shrink();
    final crossAxisCount = MediaQuery.of(context).size.width > 600 ? 4 : 2;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(
            title,
            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.1,
          ),
          itemCount: items.length,
          itemBuilder: (context, index) =>
              _buildMenuCard(context, items[index], theme),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildMenuCard(BuildContext context, MenuItem item, ThemeData theme) {
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
              const SizedBox(height: 8),
              Text(
                item.title,
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              if (item.description != null) ...[
                const SizedBox(height: 4),
                Text(
                  item.description!,
                  style: theme.textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _navigate(BuildContext context, MenuItem item) {
    Navigator.pushNamed(context, item.route);
  }
}
