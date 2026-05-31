import 'package:flutter/material.dart';
import '../plugin_system/plugin_registry.dart';
import '../plugin_system/plugin_interface.dart';
import '../widgets/screen_id_title.dart';

class PluginManagementScreen extends StatefulWidget {
  const PluginManagementScreen({super.key});

  @override
  State<PluginManagementScreen> createState() => _PluginManagementScreenState();
}

class _PluginManagementScreenState extends State<PluginManagementScreen> {
  final _registry = PluginRegistry.instance;

  @override
  Widget build(BuildContext context) {
    final plugins = _registry.allPlugins;

    return Scaffold(
      appBar: AppBar(
        title: const ScreenAppBarTitle(screenId: 'PM', title: 'プラグイン管理'),
      ),
      body: plugins.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.extension_off, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('インストール済みプラグインはありません',
                      style: TextStyle(color: Colors.grey, fontSize: 16)),
                  SizedBox(height: 8),
                  Text('プラグインはコードから登録してください',
                      style: TextStyle(color: Colors.grey)),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: plugins.length,
              itemBuilder: (context, index) =>
                  _buildPluginCard(context, plugins[index]),
            ),
    );
  }

  Widget _buildPluginCard(BuildContext context, H1Plugin plugin) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: theme.colorScheme.primaryContainer,
          child: Icon(Icons.extension, color: theme.colorScheme.primary),
        ),
        title: Text(plugin.name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('v${plugin.version}  |  ${plugin.id}'),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(plugin.description),
                const SizedBox(height: 12),
                if (plugin.dependencies.isNotEmpty) ...[
                  _buildSection('依存関係', plugin.dependencies),
                  const SizedBox(height: 8),
                ],
                if (plugin.requiredPermissions.isNotEmpty) ...[
                  _buildSection('必要な権限',
                      plugin.requiredPermissions.map((p) => p.label).toList()),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, List<String> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        ...items.map((item) => Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Text('  • $item'),
            )),
      ],
    );
  }
}
