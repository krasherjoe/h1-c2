import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../plugin_system/plugin_registry.dart';
import '../plugin_system/dashboard_section.dart';
import '../plugin_system/plugin_widgets.dart';
import '../widgets/slide_to_unlock.dart';
import 'package:sqflite/sqflite.dart';
import '../services/database_helper.dart';

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
  List<Map<String, dynamic>> _notifications = [];
  int _unreadCount = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final db = await DatabaseHelper().database;
    final notifs = await db.query('sync_notifications', orderBy: 'created_at DESC', limit: 5);
    final unreadCount = (await db.rawQuery("SELECT COUNT(*) as c FROM sync_notifications WHERE read_at IS NULL")).first['c'] as int? ?? 0;
    if (!mounted) return;
    setState(() {
      _statusEnabled = prefs.getBool('dashboard_status_enabled') ?? true;
      _statusText = prefs.getString('dashboard_status_text') ?? '販売アシスト1号 - 準備中';
      _historyUnlocked = prefs.getBool('dashboard_history_unlocked') ?? false;
      _notifications = notifs;
      _unreadCount = unreadCount;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final sections = _registry.activePlugins
      .map((p) => p.dashboardSection)
      .whereType<DashboardSection>()
      .toList()
      ..sort((a, b) => a.priority.compareTo(b.priority));

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: const Padding(
          padding: EdgeInsets.only(left: 12),
          child: Icon(Icons.home_outlined),
        ),
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
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.only(top: 16, left: 16, right: 16, bottom: 32),
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
    final cs = Theme.of(context).colorScheme;
    final latestNotif = _notifications.isNotEmpty ? _notifications.first : null;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: cs.shadow.withValues(alpha: 0.12), blurRadius: 8, offset: const Offset(0, 2)),
          BoxShadow(color: cs.shadow.withValues(alpha: 0.06), blurRadius: 16, offset: const Offset(0, 4)),
        ],
      ),
      child: InkWell(
        onTap: () {
          // 通知一覧へ
          Navigator.pushNamed(context, '/cases');
        },
        child: Row(
          children: [
            Icon(latestNotif != null ? Icons.notifications_active : Icons.info_outline,
                color: latestNotif != null ? cs.tertiary : cs.secondary, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    latestNotif != null ? '📢 ${latestNotif['title']}' : _statusText,
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: cs.onSurface),
                  ),
                  if (latestNotif != null && latestNotif['detail'] != null)
                    Text('${latestNotif['detail']}',
                        style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant), maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            if (_unreadCount > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: cs.error, borderRadius: BorderRadius.circular(10)),
                child: Text('$_unreadCount', style: TextStyle(fontSize: 10, color: cs.onError, fontWeight: FontWeight.bold)),
              ),
          ],
        ),
      ),
    );
  }
}
