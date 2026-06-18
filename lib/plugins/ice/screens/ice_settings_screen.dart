import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:h_1_core/services/company_service.dart';
import 'package:h_1_core/utils/theme_utils.dart';
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
  final _sshPubKeyController = TextEditingController();
  bool _running = false;
  String? _error;
  String? _info;
  String? _sshDir;

  @override
  void initState() {
    super.initState();
    _running = widget.apiServer.isRunning;
    _portController.text = widget.apiServer.port.toString();
    _loadSshFiles();
  }

  @override
  void dispose() {
    _portController.dispose();
    _sshConfigController.dispose();
    _sshPubKeyController.dispose();
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
      }

      final pubKeyFile = File('${sshDir.path}/id_ed25519.pub');
      if (await pubKeyFile.exists()) {
        _sshPubKeyController.text = await pubKeyFile.readAsString();
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

  Future<void> _saveSshPubKey() async {
    try {
      final dir = await CompanyService.getCompanyDirectory();
      final file = File('${dir.path}/.ssh/id_ed25519.pub');
      await file.parent.create(recursive: true);
      await file.writeAsString(_sshPubKeyController.text);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('公開鍵 保存完了')),
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

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textColor = textColorOn(cs.surface);

    return Scaffold(
      appBar: AppBar(title: const Text('ICEデバッグ設定')),
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
          _buildSshPubKeyEditor(cs, textColor),
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 12, height: 12,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _running ? Colors.green : Colors.grey,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              _running ? 'APIサーバー稼働中' : 'APIサーバー停止中',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor),
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
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: _saveSshConfig,
                icon: const Icon(Icons.save, size: 16),
                label: const Text('保存'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSshPubKeyEditor(ColorScheme cs, Color textColor) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('公開鍵 (id_ed25519.pub)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: textColor)),
            const SizedBox(height: 4),
            Text('${_sshDir ?? ""}/id_ed25519.pub',
              style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant, fontFamily: 'monospace')),
            const SizedBox(height: 8),
            TextFormField(
              controller: _sshPubKeyController,
              maxLines: 4,
              style: TextStyle(fontSize: 12, color: textColor, fontFamily: 'monospace'),
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                hintText: 'ssh-ed25519 AAAA...',
                hintStyle: TextStyle(fontSize: 12, color: cs.onSurfaceVariant.withValues(alpha: 0.4), fontFamily: 'monospace'),
                contentPadding: const EdgeInsets.all(12),
                isDense: true,
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: _saveSshPubKey,
                icon: const Icon(Icons.save, size: 16),
                label: const Text('保存'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
