import 'package:flutter/material.dart';
import '../plugin_system/plugin_registry.dart';
import '../plugin_system/plugin_interface.dart';
import '../plugin_system/plugin_state_service.dart';
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

  bool _isToggleable(String pluginId) {
    const nonToggleable = {
      'com.h1.plugin.settings',
      'com.h1.core',
    };
    return !nonToggleable.contains(pluginId);
  }

  Future<bool> _confirmDisable(H1Plugin plugin) async {
    final dependents = _registry.allPlugins
      .where((p) => p.dependencies.contains(plugin.id) && _registry.isEnabled(p.id))
      .map((p) => p.name)
      .toList();
    if (dependents.isEmpty) return true;
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('依存関係の警告'),
        content: Text(
          '以下のプラグインが ${plugin.name} に依存しています:\n'
          '${dependents.join('\n')}\n\n'
          'これらのプラグインも無効になります。続行しますか？',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('続行'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Widget _buildPluginCard(BuildContext context, H1Plugin plugin) {
    final theme = Theme.of(context);
    final enabled = _registry.isEnabled(plugin.id);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: enabled ? null : theme.colorScheme.surfaceContainerLowest,
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: enabled
              ? theme.colorScheme.primaryContainer
              : theme.colorScheme.surfaceContainerHighest,
          child: Icon(
            Icons.extension,
            color: enabled ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
          ),
        ),
        title: Text(plugin.name,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: enabled ? null : theme.colorScheme.onSurfaceVariant,
          ),
        ),
        subtitle: Text('v${plugin.version}  |  ${plugin.id}'),
        trailing: Switch(
          value: enabled,
          onChanged: _isToggleable(plugin.id)
            ? (val) async {
                if (!val && !await _confirmDisable(plugin)) return;
                _registry.setEnabled(plugin.id, val);
                await PluginStateService().setEnabled(plugin.id, val);
                setState(() {});
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        val
                          ? '${plugin.name} を有効にしました'
                          : '${plugin.name} を無効にしました（一部変更は再起動後に反映）',
                      ),
                      duration: const Duration(seconds: 3),
                    ),
                  );
                }
              }
            : null,
        ),
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
