import 'dart:async';
import 'package:flutter/material.dart';
import '../../../services/database_helper.dart';
import '../../../widgets/screen_id_title.dart';
import '../services/local_backup_service.dart';

class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});
  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  final _service = LocalBackupService();
  List<BackupEntry> _backups = [];
  bool _loading = true;
  Map<String, dynamic> _storageInfo = {};

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    final backups = await _service.listBackups();
    final info = await _service.getStorageInfo();
    if (!mounted) return;
    setState(() {
      _backups = backups;
      _storageInfo = info;
      _loading = false;
    });
  }

  Future<void> _createBackup() async {
    final dbPath = await DatabaseHelper().getDatabasePath();
    final result = await _service.createAutoBackup(dbPath);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result != null ? 'バックアップ完了' : 'バックアップに失敗しました'),
      ),
    );
    await _refresh();
  }

  Future<void> _confirmRestore(BackupEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('⚠️ リストア確認'),
        content: Text(
          '以下のバックアップファイルから復元します:\n'
          '${entry.filename}\n'
          '${entry.createdAt}\n\n'
          '現在のデータは上書きされます。\n'
          'アプリを再起動してください。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('復元'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final ok = await _service.restoreBackup(entry.path);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ok ? 'リストア完了: アプリを再起動してください' : 'リストアに失敗しました')),
    );
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const ScreenAppBarTitle(screenId: 'BK', title: 'バックアップ管理'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _refresh),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('最終バックアップ',
                            style: theme.textTheme.titleMedium),
                          const SizedBox(height: 8),
                          Text(
                            _backups.isNotEmpty
                              ? _backups.first.createdAt.toString()
                              : 'なし',
                            style: theme.textTheme.bodyLarge,
                          ),
                          const SizedBox(height: 12),
                          FilledButton.icon(
                            icon: const Icon(Icons.backup),
                            label: const Text('今すぐバックアップ'),
                            onPressed: _createBackup,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text('バックアップ一覧', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  if (_backups.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: Text('バックアップがありません')),
                    )
                  else
                    ..._backups.map((e) => Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        title: Text(e.filename, style: const TextStyle(fontSize: 13)),
                        subtitle: Text(
                          '${e.createdAt}\n${_formatSize(e.sizeBytes)}'
                          '${e.hash != null ? ' | SHA256: ${e.hash!.substring(0, 8)}...' : ''}',
                        ),
                        isThreeLine: true,
                        trailing: IconButton(
                          icon: const Icon(Icons.restore),
                          tooltip: 'リストア',
                          onPressed: () => _confirmRestore(e),
                        ),
                      ),
                    )),
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('保存先情報', style: theme.textTheme.titleMedium),
                          const SizedBox(height: 8),
                          Text('使用容量: ${_storageInfo['sizeReadable'] ?? '不明'}'),
                          Text('ファイル数: ${_storageInfo['fileCount'] ?? 0}'),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
