import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../plugin_system/plugin_registry.dart';
import '../plugin_system/dashboard_section.dart';
import '../plugin_system/plugin_widgets.dart';
import '../widgets/slide_to_unlock.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _registry = PluginRegistry.instance;
  bool _loading = true;
  bool _statusEnabled = true;
  String _statusText = '販売アシスト1号 - 準備中';
  bool _historyUnlocked = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _statusEnabled = prefs.getBool('dashboard_status_enabled') ?? true;
      _statusText = prefs.getString('dashboard_status_text') ?? '販売アシスト1号 - 準備中';
      _historyUnlocked = prefs.getBool('dashboard_history_unlocked') ?? false;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final sections = _registry.allPlugins
      .map((p) => p.dashboardSection)
      .whereType<DashboardSection>()
      .toList()
      ..sort((a, b) => a.priority.compareTo(b.priority));

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const PluginAppBarTitle(fallbackTitle: 'ダッシュボード'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () async {
              await Navigator.pushNamed(context, '/settings');
              await _load();
            },
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildSlideUnlock(),
                  if (_statusEnabled) _buildStatusBar(),
                  ...sections.map((s) => Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: s.builder(context),
                  )),
                ],
              ),
            ),
    );
  }

  Widget _buildSlideUnlock() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: _historyUnlocked
          ? Row(
              children: [
                Icon(Icons.lock_open, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                const Expanded(child: Text('A2 ロック解除済')),
                OutlinedButton.icon(
                  onPressed: () async {
                    setState(() => _historyUnlocked = false);
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setBool('dashboard_history_unlocked', false);
                  },
                  icon: const Icon(Icons.lock),
                  label: const Text('再ロック'),
                ),
              ],
            )
          : SlideToUnlock(
              isLocked: !_historyUnlocked,
              lockedText: 'スライドでロック解除 (A2)',
              unlockedText: 'A2 解除済',
              onUnlocked: () async {
                setState(() => _historyUnlocked = true);
                final prefs = await SharedPreferences.getInstance();
                await prefs.setBool('dashboard_history_unlocked', true);
              },
            ),
    );
  }

  Widget _buildStatusBar() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondaryContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).colorScheme.secondary),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: Theme.of(context).colorScheme.secondary),
          const SizedBox(width: 12),
          Expanded(child: Text(_statusText, style: const TextStyle(fontWeight: FontWeight.bold))),
        ],
      ),
    );
  }
}
