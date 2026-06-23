import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart' show getApplicationDocumentsDirectory;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:h_1_core/services/company_service.dart';
import 'package:h_1_core/services/ssh_tunnel_service.dart';
import 'package:path/path.dart' as p;
import 'package:h_1_core/utils/theme_utils.dart';
import '../../conversion/services/data_migration_service.dart';
import '../services/ice_api_server.dart';

class IceSettingsScreen extends StatefulWidget {
  final IceApiServer apiServer;
  const IceSettingsScreen({super.key, required this.apiServer});

  @override
  State<IceSettingsScreen> createState() => _IceSettingsScreenState();
}

class _IceSettingsScreenState extends State<IceSettingsScreen> {
  final _portController = TextEditingController(text: '8080');
  final _sshConfigController = TextEditingController();
  final _sshPrivateKeyController = TextEditingController();
  bool _running = false;
  String? _error;
  String? _info;
  String? _sshDir;

  // oldh1変換関連
  final _oldh1DirController = TextEditingController();
  List<FileSystemEntity> _foundDbFiles = [];
  bool _isScanning = false;
  bool _isConverting = false;

  @override
  void initState() {
    super.initState();
    _running = widget.apiServer.isRunning;
    _portController.text = widget.apiServer.port.toString();
    _loadSshFiles();
    _resolveOldh1Paths();
  }

  @override
   void dispose() {
     _portController.dispose();
     _sshConfigController.dispose();
     _sshPrivateKeyController.dispose();
     _oldh1DirController.dispose();
     super.dispose();
   }

  Future<void> _loadSshFiles() async {
    try {
      final dir = await CompanyService.getCompanyDirectory();
      final sshDir = Directory('${dir.path}/.ssh');
      _sshDir = sshDir.path;

      final configFile = File('${sshDir.path}/config');
      if (await configFile.exists()) {
        _sshConfigController.text = await configFile.readAsString();
        SshTunnelService.instance.configText = _sshConfigController.text;
      }

      final privateKeyFile = File('${sshDir.path}/id_ed25519');
      if (await privateKeyFile.exists()) {
        _sshPrivateKeyController.text = await privateKeyFile.readAsString();
        SshTunnelService.instance.keyText = _sshPrivateKeyController.text;
      }
    } catch (e) {
      debugPrint('[IceSettings] SSH load error: $e');
    }
  }

  Future<void> _saveSshConfig() async {
    try {
      final dir = await CompanyService.getCompanyDirectory();
      final file = File('${dir.path}/.ssh/config');
      await file.parent.create(recursive: true);
      await file.writeAsString(_sshConfigController.text);

      SshTunnelService.instance.configText = _sshConfigController.text;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('SSH config 保存完了')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存失敗: $e')),
        );
      }
    }
  }

  Future<void> _saveSshPrivateKey() async {
    try {
      final dir = await CompanyService.getCompanyDirectory();
      final file = File('${dir.path}/.ssh/id_ed25519');
      await file.parent.create(recursive: true);
      await file.writeAsString(_sshPrivateKeyController.text);

      SshTunnelService.instance.keyText = _sshPrivateKeyController.text;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('秘密鍵 保存完了')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存失敗: $e')),
        );
      }
    }
  }

  Future<void> _toggleServer() async {
    if (_running) {
      await widget.apiServer.stop();
      setState(() {
        _running = false;
        _info = 'サーバー停止';
        _error = null;
      });
    } else {
      final port = int.tryParse(_portController.text);
      if (port == null || port < 1024 || port > 65535) {
        setState(() {
          _error = 'ポートは1024-65535の範囲で指定';
          _info = null;
        });
        return;
      }
      try {
        await widget.apiServer.restart(port: port);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt('ice_port', port);
        setState(() {
          _running = true;
          _info = 'サーバー起動: http://localhost:$port';
          _error = null;
        });
      } catch (e) {
        setState(() {
          _error = '起動失敗: $e';
          _info = null;
        });
      }
    }
  }

  Future<void> _resolveOldh1Paths() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      _oldh1DirController.text = appDir.path;
    } catch (_) {}
  }

  Future<void> _scanOldh1Dir() async {
    setState(() {
      _isScanning = true;
      _foundDbFiles = [];
      _error = null;
      _info = null;
    });
    try {
      final dirPath = _oldh1DirController.text.trim();
      if (dirPath.isEmpty) {
        setState(() {
          _error = 'ディレクトリパスを入力してください';
          _isScanning = false;
        });
        return;
      }
      final dir = Directory(dirPath);
      if (!await dir.exists()) {
        setState(() {
          _foundDbFiles = [];
          _isScanning = false;
          _info = 'ディレクトリが存在しません: $dirPath\n他のパスを試すか、正しいパスを入力してください。';
        });
        return;
      }

      // 再帰的に .db ファイルを検索（find ライク）
      final results = <FileSystemEntity>[];
      try {
        await for (final entity in dir.list(recursive: true, followLinks: false)) {
          if (entity is File) {
            final name = entity.uri.pathSegments.last.toLowerCase();
            if (name.endsWith('.db') || name.endsWith('.sqlite') || name.endsWith('.sqlite3')) {
              results.add(entity);
            }
          }
        }
      } catch (e) {
        // 権限エラーなどは無視して続行
        debugPrint('[Oldh1Scan] 部分エラー: $e');
      }

      results.sort((a, b) => (b as File).lastModifiedSync().compareTo(
        (a as File).lastModifiedSync()));

      setState(() {
        _foundDbFiles = results;
        _isScanning = false;
        if (results.isEmpty) {
          _info = '「$dirPath」以下に.dbファイルが見つかりませんでした。\n・クイックパスで「SDカード」を試す\n・ファイルマネージャーで.dbファイルの場所を確認';
        } else {
          _info = '${results.length}個のDBファイルを見つけました（$dirPath 以下）';
        }
      });
    } catch (e) {
      setState(() {
        _error = 'スキャンエラー: $e';
        _isScanning = false;
      });
    }
  }

  Future<void> _convertAndOpen(String sourcePath) async {
    setState(() {
      _isConverting = true;
      _error = null;
      _info = '変換中...';
    });
    try {
      final sourceFile = File(sourcePath);
      final baseName = p.basenameWithoutExtension(sourceFile.path);
      final companyName = 'oldh1_$baseName';
      final companyDir = await CompanyService.getCompanyDirectory();
      final destPath = p.join(companyDir.path, '$companyName.db');

      // 既存の変換先DBがあれば削除
      final destFile = File(destPath);
      if (await destFile.exists()) {
        await destFile.delete();
      }

      // DBファイルをコピー
      await sourceFile.copy(destPath);

      // マイグレーションを実行
      final db = await openDatabase(destPath);
      try {
        await DataMigrationService.runConversion(db);
      } finally {
        await db.close();
      }

      // 法人として自動切替
      await CompanyService.switchCompany(companyName);

      if (mounted) {
        setState(() {
          _isConverting = false;
          _info = '変換完了！「$companyName」に自動切替しました。';
        });
        // ルートまで戻ってアプリを再表示
        Navigator.of(context).popUntil((route) => route.isFirst);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('「$companyName」に切り替えました')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = '変換エラー: $e';
          _isConverting = false;
        });
      }
    }
  }

  String _relativePath(String fullPath, String baseDir) {
    if (fullPath.startsWith(baseDir)) {
      final rel = fullPath.substring(baseDir.length);
      return rel.startsWith('/') ? rel.substring(1) : rel;
    }
    return fullPath;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textColor = textColorOn(cs.surface);

    return Scaffold(
      appBar: AppBar(
        title: Text('ICEデバッグ設定 v${widget.apiServer.version}'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildStatusCard(cs, textColor),
          const SizedBox(height: 16),
          _buildServerControl(cs, textColor),
          const SizedBox(height: 16),
          _buildSshKeyInfo(cs, textColor),
          const SizedBox(height: 16),
          _buildSshConfigEditor(cs, textColor),
          const SizedBox(height: 16),
           _buildSshPrivateKeyEditor(cs, textColor),
           const SizedBox(height: 16),
           _buildOldh1Conversion(cs, textColor),
           if (_error != null) ...[
            const SizedBox(height: 12),
            Card(
              color: cs.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: cs.error),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_error!, style: TextStyle(color: cs.onErrorContainer))),
                  ],
                ),
              ),
            ),
          ],
          if (_info != null) ...[
            const SizedBox(height: 12),
            Card(
              color: cs.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: cs.onPrimaryContainer),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_info!, style: TextStyle(color: cs.onPrimaryContainer))),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusCard(ColorScheme cs, Color textColor) {
    final ssh = SshTunnelService.instance;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 12, height: 12,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _running ? Colors.green : Colors.grey,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _running ? 'API稼働中' : 'API停止中',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: textColor),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ValueListenableBuilder<bool>(
              valueListenable: ssh.onlineNotifier,
              builder: (ctx, online, _) => Row(
                children: [
                  Text('SSH', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: textColor)),
                  const SizedBox(width: 8),
                  Switch(
                    value: online,
                    onChanged: (v) {
                      if (v) {
                        ssh.configText = _sshConfigController.text;
                        ssh.keyText = _sshPrivateKeyController.text;
                        ssh.connect();
                      } else {
                        ssh.disconnect();
                      }
                    },
                  ),
                  if (online)
                    OutlinedButton.icon(
                      onPressed: () => ssh.disconnect(),
                      icon: const Icon(Icons.link_off, size: 14),
                      label: const Text('切断', style: TextStyle(fontSize: 12)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: cs.error,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        minimumSize: Size.zero,
                        visualDensity: VisualDensity.compact,
                      ),
                    )
                  else
                    FilledButton.icon(
                      onPressed: () {
                        ssh.configText = _sshConfigController.text;
                        ssh.keyText = _sshPrivateKeyController.text;
                        ssh.connect();
                      },
                      icon: const Icon(Icons.link, size: 14),
                      label: const Text('接続', style: TextStyle(fontSize: 12)),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        minimumSize: Size.zero,
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            ValueListenableBuilder<String>(
              valueListenable: ssh.statusNotifier,
              builder: (ctx, status, _) {
                if (status.isEmpty) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Text(status, style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
                );
              },
            ),
            ValueListenableBuilder<String?>(
              valueListenable: ssh.errorNotifier,
              builder: (ctx, error, _) {
                if (error == null) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(left: 4, top: 2),
                  child: Text(error, style: TextStyle(fontSize: 11, color: cs.error)),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildServerControl(ColorScheme cs, Color textColor) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('サーバー設定', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: textColor)),
            const SizedBox(height: 12),
            Row(
              children: [
                SizedBox(
                  width: 100,
                  child: TextField(
                    controller: _portController,
                    decoration: const InputDecoration(
                      labelText: 'ポート',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    keyboardType: TextInputType.number,
                    enabled: !_running,
                  ),
                ),
                const SizedBox(width: 16),
                FilledButton.icon(
                  onPressed: _toggleServer,
                  icon: Icon(_running ? Icons.stop : Icons.play_arrow),
                  label: Text(_running ? '停止' : '起動'),
                ),
              ],
            ),
            if (_running) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  children: [
                    Icon(Icons.link, size: 14, color: cs.onSurfaceVariant),
                    const SizedBox(width: 6),
                    Text(
                      'http://localhost:${widget.apiServer.port}',
                      style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant, fontFamily: 'monospace'),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSshKeyInfo(ColorScheme cs, Color textColor) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('SSH鍵ディレクトリ', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: textColor)),
            const SizedBox(height: 8),
            Text(
              'Keys are not managed by the application. Use the file manager to place SSH keys.',
              style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 8),
            FutureBuilder<String>(
              future: CompanyService.getCompanyDirectory().then((d) => '${d.path}/.ssh/'),
              builder: (context, snapshot) {
                final path = snapshot.data ?? '...';
                return Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.folder, size: 14, color: cs.onSurfaceVariant),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          path,
                          style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant, fontFamily: 'monospace'),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSshConfigEditor(ColorScheme cs, Color textColor) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('SSH Config', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: textColor)),
            const SizedBox(height: 4),
            Text('${_sshDir ?? ""}/config',
              style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant, fontFamily: 'monospace')),
            const SizedBox(height: 8),
            TextFormField(
              controller: _sshConfigController,
              maxLines: 12,
              style: TextStyle(fontSize: 12, color: textColor, fontFamily: 'monospace'),
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                hintText: '# SSH Config\nHost opencode-box\n  HostName example.com\n  User developer\n  IdentityFile ~/.ssh/id_ed25519\n  RemoteForward 8080 localhost:8080',
                hintStyle: TextStyle(fontSize: 12, color: cs.onSurfaceVariant.withValues(alpha: 0.4), fontFamily: 'monospace'),
                contentPadding: const EdgeInsets.all(12),
                isDense: true,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _saveSshConfig,
                    icon: const Icon(Icons.save, size: 16),
                    label: const Text('保存'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _sshConnectButton(cs),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _sshConnectButton(ColorScheme cs) {
    final ssh = SshTunnelService.instance;
    return ValueListenableBuilder<bool>(
      valueListenable: ssh.onlineNotifier,
      builder: (ctx, online, _) {
        if (online) {
          return OutlinedButton.icon(
            onPressed: () => ssh.disconnect(),
            icon: const Icon(Icons.link_off, size: 16),
            label: const Text('切断'),
            style: OutlinedButton.styleFrom(foregroundColor: cs.error),
          );
        }
        return FilledButton.icon(
          onPressed: () {
            ssh.configText = _sshConfigController.text;
            ssh.keyText = _sshPrivateKeyController.text;
            ssh.connect();
          },
          icon: const Icon(Icons.link, size: 16),
          label: const Text('接続'),
        );
      },
    );
  }

  Widget _buildSshPrivateKeyEditor(ColorScheme cs, Color textColor) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('秘密鍵 (id_ed25519)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: textColor)),
            const SizedBox(height: 4),
            Text('${_sshDir ?? ""}/id_ed25519',
              style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant, fontFamily: 'monospace')),
            const SizedBox(height: 8),
            TextFormField(
              controller: _sshPrivateKeyController,
              maxLines: 16,
              style: TextStyle(fontSize: 12, color: textColor, fontFamily: 'monospace'),
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                hintText: '-----BEGIN OPENSSH PRIVATE KEY-----\nAAAAB3NzaC1...',
                hintStyle: TextStyle(fontSize: 12, color: cs.onSurfaceVariant.withValues(alpha: 0.4), fontFamily: 'monospace'),
                contentPadding: const EdgeInsets.all(12),
                isDense: true,
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: _saveSshPrivateKey,
                icon: const Icon(Icons.save, size: 16),
                label: const Text('保存'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOldh1Conversion(ColorScheme cs, Color textColor) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.swap_horiz, size: 18, color: cs.primary),
                const SizedBox(width: 8),
                Text('oldh1 データ変換',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: textColor)),
              ],
            ),
            const SizedBox(height: 4),
            Text('旧バージョンのDBファイルを変換して開きます',
              style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
            const SizedBox(height: 12),
            // ディレクトリパス入力
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _oldh1DirController,
                    decoration: const InputDecoration(
                      labelText: 'DBディレクトリ',
                      border: OutlineInputBorder(),
                      isDense: true,
                      contentPadding: EdgeInsets.all(12),
                    ),
                    style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: _isScanning ? null : _scanOldh1Dir,
                  icon: _isScanning
                      ? const SizedBox(
                          width: 14, height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.search, size: 16),
                  label: Text(_isScanning ? '検索中' : 'スキャン'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // よく使うパス
            Wrap(
              spacing: 4,
              children: [
                Text('クイックパス: ', style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
                ActionChip(
                  label: const Text('アプリデータ', style: TextStyle(fontSize: 10)),
                  onPressed: () async {
                    final appDir = await getApplicationDocumentsDirectory();
                    _oldh1DirController.text = appDir.path;
                  },
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                ),
                ActionChip(
                  label: const Text('Documents', style: TextStyle(fontSize: 10)),
                  onPressed: () {
                    _oldh1DirController.text = '/storage/emulated/0/Documents';
                  },
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                ),
                ActionChip(
                  label: const Text('SDカード', style: TextStyle(fontSize: 10)),
                  onPressed: () {
                    _oldh1DirController.text = '/storage/emulated/0';
                  },
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // 見つかったDBファイル一覧
            if (_foundDbFiles.isNotEmpty) ...[
              const Divider(),
              Text('見つかったDBファイル:',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: cs.onSurfaceVariant)),
              const SizedBox(height: 4),
              ...(_foundDbFiles as List<File>).map((file) {
                final sizeKB = (file.lengthSync() / 1024).round();
                final modified = file.lastModifiedSync();
                final dateStr = '${modified.year}/${modified.month.toString().padLeft(2, '0')}/${modified.day.toString().padLeft(2, '0')}';
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: cs.outlineVariant),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ListTile(
                      dense: true,
                      leading: Icon(Icons.storage, size: 20, color: cs.primary),
                      title: Text(file.uri.pathSegments.last,
                        style: TextStyle(fontSize: 13, color: textColor, fontFamily: 'monospace')),
                      subtitle: Text('${_relativePath(file.path, _oldh1DirController.text.trim())} | ${sizeKB}KB / $dateStr',
                        style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
                      trailing: _isConverting
                          ? const SizedBox(
                              width: 16, height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : FilledButton.tonalIcon(
                              onPressed: () => _convertAndOpen(file.path),
                              icon: const Icon(Icons.download, size: 14),
                              label: const Text('変換して開く', style: TextStyle(fontSize: 11)),
                              style: FilledButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                minimumSize: Size.zero,
                                visualDensity: VisualDensity.compact,
                              ),
                            ),
                    ),
                  ),
                );
              }),
            ],
            // ヒント
            if (_foundDbFiles.isEmpty && !_isScanning)
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, size: 14, color: cs.onSurfaceVariant),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'スキャンしてDBファイルを探すか、パスを直接入力してください',
                        style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
