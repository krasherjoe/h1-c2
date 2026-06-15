import 'dart:io';
import 'package:flutter/material.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:sqflite/sqflite.dart';
import '../../plugin_system/plugin_interface.dart';
import '../../plugin_system/plugin_context.dart';
import '../../plugin_system/screen_definition.dart';
import '../../services/database_helper.dart';
import '../../services/drive_backup_service.dart';
import '../../services/google_auth_service.dart';
import '../backup/services/local_backup_service.dart';

class DriveBackupPlugin extends H1Plugin {
  @override
  String get id => 'com.h1.plugin.drivebackup';
  @override
  String get name => 'Driveバックアップ';
  @override
  String get version => '1.0.0';
  @override
  String get description => 'Google DriveにDBを自動バックアップ';
  @override
  List<String> get dependencies => ['com.h1.core'];

  @override
  List<ScreenDefinition> get screens => [
    ScreenDefinition(
      id: 'DR',
      title: 'Driveバックアップ',
      route: '/drivebackup',
      category: 'システム',
      icon: Icons.cloud_upload,
      builder: (_) => const DriveBackupScreen(),
    ),
  ];

  @override
  Map<String, WidgetBuilder> getRoutes() => {};
  @override
  Future<void> dispose() async {}
  @override
  Future<void> createTables(Database db) async {}
  @override
  Future<void> initialize(PluginContext context) async {
    GoogleAuthService.instance.init();
    await _autoBackup();
  }

  Future<void> _autoBackup() async {
    try {
      final dbPath = await DatabaseHelper().getDatabasePath();
      final service = LocalBackupService();
      final localPath = await service.createAutoBackup(dbPath);
      if (localPath == null) return;
      await DriveBackupService().uploadBackup(localPath);
    } catch (_) {}
  }
}

class DriveBackupScreen extends StatefulWidget {
  const DriveBackupScreen({super.key});
  @override
  State<DriveBackupScreen> createState() => _DriveBackupScreenState();
}

class _DriveBackupScreenState extends State<DriveBackupScreen> {
  final _driveService = DriveBackupService();
  List<drive.File> _files = [];
  bool _loading = true;
  bool _signedIn = false;
  String? _email;

  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    final auth = GoogleAuthService.instance;
    _email = await auth.getEmail();
    _signedIn = _email != null && _email!.isNotEmpty;
    if (_signedIn) await _loadFiles();
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadFiles() async {
    setState(() => _loading = true);
    _files = await _driveService.listBackups();
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _signIn() async {
    final ok = await GoogleAuthService.instance.signIn();
    if (ok) await _checkAuth();
  }

  Future<void> _uploadNow() async {
    try {
      final dbPath = await DatabaseHelper().getDatabasePath();
      final service = LocalBackupService();
      final localPath = await service.createAutoBackup(dbPath);
      if (localPath == null) return;
      final ok = await _driveService.uploadBackup(localPath);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ok ? 'アップロード完了' : 'アップロード失敗')),
        );
        if (ok) await _loadFiles();
      }
    } catch (_) {}
  }

  Future<void> _restore(drive.File f) async {
    if (f.id == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('リストア確認'),
        content: Text('「${f.name}」(${_size(f.size)}) から復元しますか？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('キャンセル')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('復元')),
        ],
      ),
    );
    if (confirmed != true) return;
    final dbPath = await DatabaseHelper().getDatabasePath();
    final tmpPath = '${dbPath}.restore';
    final ok = await _driveService.downloadBackup(f.id!, tmpPath);
    if (ok) {
      await DatabaseHelper.closeAndReset();
      await File(tmpPath).copy(dbPath);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('復元完了しました')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Driveバックアップ')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : !_signedIn
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.cloud_off, size: 64, color: cs.onSurfaceVariant),
                      const SizedBox(height: 16),
                      Text('Googleアカウントでログイン', style: TextStyle(color: cs.onSurfaceVariant)),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        icon: const Icon(Icons.login),
                        label: const Text('ログイン'),
                        onPressed: _signIn,
                      ),
                    ],
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Card(
                      color: cs.surfaceContainerLow,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(children: [
                          Icon(Icons.cloud_done, color: cs.primary),
                          const SizedBox(width: 8),
                          Expanded(child: Text(_email ?? '', style: TextStyle(color: cs.onSurface))),
                          TextButton(
                            onPressed: () async {
                              await GoogleAuthService.instance.signOut();
                              await _checkAuth();
                            },
                            child: const Text('解除'),
                          ),
                        ]),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        icon: const Icon(Icons.cloud_upload),
                        label: const Text('今すぐバックアップ'),
                        onPressed: _uploadNow,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text('バックアップ一覧', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: cs.onSurface)),
                    const SizedBox(height: 8),
                    if (_files.isEmpty)
                      Center(child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Text('バックアップがありません', style: TextStyle(color: cs.onSurfaceVariant)),
                      ))
                    else
                      ..._files.map((f) => Card(
                        margin: const EdgeInsets.only(bottom: 4),
                        child: ListTile(
                          dense: true,
                          leading: const Icon(Icons.backup, size: 20),
                          title: Text(f.name ?? '', style: TextStyle(fontSize: 12, color: cs.onSurface)),
                          subtitle: Text(_formatDate(f.createdTime) + '  ${_size(f.size)}',
                              style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant)),
                          trailing: IconButton(
                            icon: Icon(Icons.restore, size: 18, color: cs.primary),
                            onPressed: () => _restore(f),
                          ),
                        ),
                      )),
                  ],
                ),
    );
  }

  String _formatDate(DateTime? d) {
    if (d == null) return '';
    return '${d.year}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')} '
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  String _size(String? sizeStr) {
    final bytes = int.tryParse(sizeStr ?? '');
    if (bytes == null) return '';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
