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
  bool _running = false;
  String? _error;
  String? _info;

  @override
  void initState() {
    super.initState();
    _running = widget.apiServer.isRunning;
    _portController.text = widget.apiServer.port.toString();
  }

  @override
  void dispose() {
    _portController.dispose();
    super.dispose();
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
}
