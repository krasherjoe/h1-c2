import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../services/sync_queue.dart';
import '../../../services/google_auth_service.dart';
import 'sync_qr_display_screen.dart';
import 'sync_qr_scanner_screen.dart';
import 'permission_screen.dart';

class SyncHomeScreen extends StatefulWidget {
  const SyncHomeScreen({super.key});
  @override
  State<SyncHomeScreen> createState() => _SyncHomeScreenState();
}

class _SyncHomeScreenState extends State<SyncHomeScreen> {
  String _mode = 'loading';
  String? _parentEmail;
  int _lastSync = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await SyncQueue.instance.init();
    final isParent = SyncQueue.instance.isParent;
    final prefs = await SharedPreferences.getInstance();
    final email = await GoogleAuthService.instance.getEmail();
    final last = prefs.getInt('sync_last_check') ?? 0;
    if (mounted) setState(() {
      _mode = isParent ? 'parent' : 'child';
      _parentEmail = isParent ? email : prefs.getString('sync_parent_email');
      _lastSync = last;
    });
  }

  String _timeAgo(int ts) {
    if (ts == 0) return '未同期';
    final diff = DateTime.now().millisecondsSinceEpoch ~/ 1000 - ts;
    if (diff < 60) return '${diff}秒前';
    if (diff < 3600) return '${diff ~/ 60}分前';
    return '${diff ~/ 3600}時間前';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (_mode == 'loading') return Scaffold(
      appBar: AppBar(title: const Text('SY:グループ同期')),
      body: const Center(child: CircularProgressIndicator()),
    );
    return Scaffold(
      appBar: AppBar(title: const Text('SY:グループ同期')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: _mode == 'parent' ? cs.tertiaryContainer : cs.surfaceContainerLow,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Icon(_mode == 'parent' ? Icons.star : Icons.person, color: _mode == 'parent' ? cs.tertiary : cs.onSurfaceVariant),
                    const SizedBox(width: 8),
                    Text(_mode == 'parent' ? '👑 親分モード' : '📱 子分モード',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _mode == 'parent' ? cs.tertiary : cs.onSurface)),
                  ]),
                  const SizedBox(height: 8),
                  if (_parentEmail != null && _parentEmail!.isNotEmpty)
                    Text('連携先: $_parentEmail', style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
                  Text('最終同期: ${_timeAgo(_lastSync)}', style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (_mode == 'parent') ...[
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                icon: const Icon(Icons.qr_code),
                label: const Text('QRコードを表示（子分を追加）'),
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SyncQrDisplayScreen())),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.admin_panel_settings),
                label: const Text('権限設定'),
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PermissionScreen())),
              ),
            ),
          ] else ...[
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                icon: const Icon(Icons.qr_code_scanner),
                label: const Text('QRコードをスキャン（親分に登録）'),
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const SyncQrScannerScreen()));
                },
              ),
            ),
            const SizedBox(height: 8),
            Text('QRが読めない端末は子分になれません',
                style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
          ],
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('同期の仕組み', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: cs.onSurface)),
                  const SizedBox(height: 4),
                  Text('変更は自動的に2分間隔でGmail経由で同期されます',
                      style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                  Text('親分が72時間以上応答しない場合は「親分昇格」が可能です',
                      style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                  if (_mode == 'parent')
                    Text('親分は複数台存在できません（Sheets非使用）',
                        style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
