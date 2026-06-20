import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../services/preview_settings_service.dart';
import '../../../services/google_auth_service.dart';
import '../../../services/gemini_ocr_service.dart';
import '../../../services/ssh_tunnel_service.dart';
import '../../../widgets/h1_text_field.dart';
import '../../../constants/screen_ids.dart';

class DebugScreen extends StatefulWidget {
  const DebugScreen({super.key});
  @override
  State<DebugScreen> createState() => _DebugScreenState();
}

class _DebugScreenState extends State<DebugScreen> {
  bool _loading = true;
  int _maxPages = kDefaultMaxPreviewPages;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    _configCtrl.text = prefs.getString('ssh_config') ?? '';
    _keyCtrl.text = prefs.getString('ssh_key') ?? '';
    _maxPages = await loadMaxPreviewPages();
    if (!mounted) return;
    setState(() => _loading = false);
  }

  Future<void> _setMaxPages(int v) async {
    await saveMaxPreviewPages(v);
    if (!mounted) return;
    setState(() => _maxPages = v);
  }

  Future<void> _configureGeminiKey() async {
    final existing = await GeminiOcrService.getApiKey();
    final ctl = TextEditingController(text: existing ?? '');
    final key = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Gemini APIキー設定'),
        content: H1TextField(
          controller: ctl,
          decoration: const InputDecoration(
            labelText: 'API Key',
            hintText: 'Google AI Studio の API Key を入力',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('キャンセル')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, ctl.text.trim()),
            child: const Text('保存')),
        ],
      ),
    );
    if (key != null && key.isNotEmpty) {
      await GeminiOcrService.setApiKey(key);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gemini APIキーを保存しました')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(title: const Text('${S.db}:デバッグ')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _previewCard(cs),
          const SizedBox(height: 12),
          _googleCard(cs),
          const SizedBox(height: 12),
          _geminiCard(cs),
          const SizedBox(height: 12),
          _sshCard(cs),
        ],
      ),
    );
  }

  Widget _previewCard(ColorScheme cs) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('プレビュー設定', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Row(
              children: [
                const Text('最大ページ数:'),
                const Spacer(),
                Text('$_maxPages ページ (${_maxPages * kItemsPerPage} 明細)', style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 4),
            Text('デフォルト20 / 最小5 / 最大55', style: TextStyle(fontSize: 12, color: cs.onSurface.withOpacity(0.6))),
            Slider(
              value: _maxPages.toDouble(),
              min: 5,
              max: 55,
              divisions: 50,
              label: '$_maxPages',
              onChanged: (v) => _setMaxPages(v.round()),
            ),
          ],
        ),
      ),
    );
  }

  Widget _googleCard(ColorScheme cs) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Google認証', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            FutureBuilder<bool>(
              future: GoogleAuthService.instance.isSignedIn(),
              builder: (ctx, snap) {
                final signedIn = snap.data ?? false;
                return Column(
                  children: [
                    _statusRow(Icons.email, 'Gmail連携', signedIn, cs),
                    if (signedIn)
                      FutureBuilder<String?>(
                        future: GoogleAuthService.instance.getEmail(),
                        builder: (ctx, snap2) => Padding(
                          padding: const EdgeInsets.only(left: 26, bottom: 8),
                          child: Row(
                            children: [
                              Text(snap2.data ?? '', style: const TextStyle(fontSize: 12)),
                              const Spacer(),
                              TextButton(
                                onPressed: () async {
                                  await GoogleAuthService.instance.signOut();
                                  setState(() {});
                                },
                                child: const Text('ログアウト', style: TextStyle(fontSize: 12)),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      Padding(
                        padding: const EdgeInsets.only(left: 26),
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            await GoogleAuthService.instance.signIn();
                            setState(() {});
                          },
                          icon: const Icon(Icons.login, size: 18),
                          label: const Text('Google認証'),
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _geminiCard(ColorScheme cs) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Gemini', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _configureGeminiKey,
              icon: const Icon(Icons.auto_awesome, size: 18),
              label: const Text('APIキー設定'),
            ),
          ],
        ),
      ),
    );
  }

  final _configCtrl = TextEditingController();
  final _keyCtrl = TextEditingController();

  @override
  void dispose() {
    _configCtrl.dispose();
    _keyCtrl.dispose();
    super.dispose();
  }

  Future<void> _sshConnect() async {
    SshTunnelService.instance.configText = _configCtrl.text;
    SshTunnelService.instance.keyText = _keyCtrl.text;
    await SshTunnelService.instance.connect();
  }

  Future<void> _saveSshConfig() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('ssh_config', _configCtrl.text);
    await prefs.setString('ssh_key', _keyCtrl.text);
  }

  Future<void> _sshDisconnect() async {
    await SshTunnelService.instance.disconnect();
  }

  Widget _sshCard(ColorScheme cs) {
    final ssh = SshTunnelService.instance;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('SSHトンネル', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            ValueListenableBuilder<String>(
              valueListenable: ssh.statusNotifier,
              builder: (ctx, status, _) => Row(
                children: [
                  Icon(Icons.tune, size: 18, color: cs.onSurfaceVariant),
                  const SizedBox(width: 8),
                  const Text('SSH接続'),
                  const Spacer(),
                  ValueListenableBuilder<bool>(
                    valueListenable: ssh.onlineNotifier,
                    builder: (ctx, online, _) {
                      return Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: online ? const Color(0xFF4CAF50) : cs.error,
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(status, style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            ),
            if (ssh.errorNotifier.value != null) ...[
              const SizedBox(height: 4),
              Text(ssh.errorNotifier.value!, style: TextStyle(fontSize: 12, color: cs.error)),
            ],
            const SizedBox(height: 8),
            TextField(
              controller: _configCtrl,
              maxLines: 6,
              style: const TextStyle(fontSize: 12),
              onChanged: (_) => _saveSshConfig(),
              decoration: const InputDecoration(
                labelText: 'SSH config',
                hintText: '# Host pve1\n#   HostName answer.mydns.jp\n#   Port 22252\n#\n# Host labo\n#   HostName 192.168.55.103\n#   ProxyJump pve1\n#\n# Host gui1\n#   HostName 10.0.100.130\n#   ProxyJump labo',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _keyCtrl,
              maxLines: 4,
              style: const TextStyle(fontSize: 12),
              onChanged: (_) => _saveSshConfig(),
              decoration: const InputDecoration(
                labelText: '秘密鍵',
                hintText: '-----BEGIN OPENSSH PRIVATE KEY-----\n...',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            ),
            const SizedBox(height: 8),
            ValueListenableBuilder<bool>(
              valueListenable: ssh.onlineNotifier,
              builder: (ctx, online, _) {
                return Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: online ? null : _sshConnect,
                        icon: const Icon(Icons.link, size: 18),
                        label: Text(online ? 'ONLINE' : '接続'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: !online ? null : _sshDisconnect,
                        icon: const Icon(Icons.link_off, size: 18),
                        label: Text(online ? 'OFFLINE' : '切断'),
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusRow(IconData icon, String label, bool ok, ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: ok ? cs.tertiary : cs.onSurfaceVariant),
          const SizedBox(width: 8),
          Text(label),
          const Spacer(),
          Icon(ok ? Icons.check_circle : Icons.cancel, size: 16,
            color: ok ? cs.tertiary : cs.onSurfaceVariant),
        ],
      ),
    );
  }
}
