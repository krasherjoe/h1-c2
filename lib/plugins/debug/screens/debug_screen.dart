import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/debug_service.dart';
import '../services/update_service.dart';
import '../../../services/preview_settings_service.dart';
import '../../../services/google_auth_service.dart';
import '../../../services/mm_command_service.dart';
import '../../../services/sheets_sync_service.dart';
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
  final _service = DebugService();
  final _updater = UpdateService();
  bool _loading = true;
  String? _dbResult;
  String _patCtrl = '';
  bool _sendingDb = false;
  bool _checkingUpdate = false;
  bool _downloading = false;
  String? _updateError;
  String? _downloadResult;
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
    await _service.loadConfig();
    _maxPages = await loadMaxPreviewPages();
    if (!mounted) return;
    setState(() => _loading = false);
  }

  Future<void> _setMaxPages(int v) async {
    await saveMaxPreviewPages(v);
    if (!mounted) return;
    setState(() => _maxPages = v);
  }

  Future<void> _sendDb() async {
    setState(() { _sendingDb = true; _dbResult = null; });
    final result = await _service.sendDbReport();
    if (!mounted) return;
    setState(() { _dbResult = result ?? '送信成功'; _sendingDb = false; });
  }

  Future<void> _sendTestReport() async {
    if (!_service.isConfigured) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('PAT未設定')));
      return;
    }
    final ok = await _service.sendTextViaPat(
      '### \u{1F9EA} h-1-core 診断テスト\n\n'
      '**時刻:** ${DateTime.now().toIso8601String()}',
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ok ? 'PAT送信成功' : 'PAT送信失敗')),
    );
  }

  Future<void> _googleDiagnostic() async {
    final buf = StringBuffer();
    buf.writeln('### \u{1F50D} Google診断');
    try {
      final email = await GoogleAuthService.instance.getEmail();
      final signedIn = await GoogleAuthService.instance.isSignedIn();
      buf.writeln('**メール:** ${email ?? "未設定"}');
      buf.writeln('**ログイン状態:** ${signedIn ? "済" : "未"}');
      buf.writeln('**パッケージ:** com.h1.core');

      if (_service.isConfigured) {
        final ok = await _service.sendTextViaPat(buf.toString());
        if (ok && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('診断情報を送信しました')));
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('診断送信に失敗しました')));
          debugPrint(buf.toString());
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('PAT未設定のため送信できません')));
        }
        debugPrint(buf.toString());
      }
    } catch (e) {
      debugPrint('[GoogleDiagnostic] error: $e');
    }
  }

  Future<void> _createSpreadsheet() async {
    if (!mounted) return;
    final url = await SheetsSyncService.instance.ensureSpreadsheet();
    if (url == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('作成失敗（ログインしてください）')));
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('📊 $url'),
      duration: const Duration(seconds: 10),
      action: SnackBarAction(label: '開く', onPressed: () => SheetsSyncService.instance.openUrl(url)),
    ));
  }

  Future<void> _configurePat() async {
    final ctl = TextEditingController(text: _patCtrl);
    final pat = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Mattermost PAT設定'),
        content: H1TextField(
          controller: ctl,
          decoration: const InputDecoration(
            labelText: 'Personal Access Token',
            hintText: 'Mattermost の PAT を入力',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('キャンセル')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, ctl.text.trim()),
            child: const Text('保存')),
        ],
      ),
    );
    if (pat != null && pat.isNotEmpty) {
      await _service.saveConfig(pat: pat);
      _patCtrl = pat;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PATを保存しました')),
      );
    }
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

  Future<void> _checkUpdate() async {
    setState(() { _checkingUpdate = true; _updateError = null; });
    final err = await _updater.checkForUpdate();
    if (!mounted) return;
    setState(() { _checkingUpdate = false; _updateError = err; });
  }

  Future<void> _downloadApk() async {
    setState(() { _downloading = true; _downloadResult = null; });
    final err = await _updater.downloadApk();
    if (!mounted) return;
    setState(() {
      _downloading = false;
      _downloadResult = err ?? '保存: ${_updater.downloadedPath}';
    });
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
          _statusCard(cs),
          const SizedBox(height: 12),
          _actionsCard(cs),
          const SizedBox(height: 12),
          _previewCard(cs),
          const SizedBox(height: 12),
          _infoCard(),
          const SizedBox(height: 12),
          _updateCard(cs),
          const SizedBox(height: 12),
          _sshCard(cs),
        ],
      ),
    );
  }

  Widget _statusCard(ColorScheme cs) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('状態', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            _statusRow(Icons.webhook, 'Webhook', _service.isConfigured, cs),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Icon(Icons.cloud, size: 18, color: cs.onSurfaceVariant),
                  const SizedBox(width: 8),
                  const Text('Mattermost'),
                  const Spacer(),
                  Flexible(
                    child: Text(_service.baseUrl,
                      overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _configurePat,
              icon: const Icon(Icons.vpn_key, size: 18),
              label: Text(_service.isConfigured ? 'PAT変更' : 'PAT設定'),
            ),
            const SizedBox(height: 8),
            ValueListenableBuilder<bool>(
              valueListenable: MmCommandService.instance.enabledNotifier,
              builder: (ctx, enabled, _) => Row(
                children: [
                  Icon(Icons.sync, size: 18, color: cs.onSurfaceVariant),
                  const SizedBox(width: 8),
                  const Text('MMポーリング'),
                  const Spacer(),
                  Switch(
                    value: enabled,
                    onChanged: (v) => MmCommandService.instance.setEnabled(v),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _googleAuthStatus(cs),
          ],
        ),
      ),
    );
  }

  Widget _actionsCard(ColorScheme cs) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('診断アクション', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _sendingDb ? null : _sendDb,
              icon: _sendingDb
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.upload_file),
              label: Text(_sendingDb ? '送信中...' : 'DBをMattermostに送信'),
            ),
            if (_dbResult != null) ...[
              const SizedBox(height: 8),
              Text(_dbResult!, style: TextStyle(
                color: _dbResult == '送信成功' ? cs.primary : cs.error,
              )),
            ],
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _sendTestReport,
              icon: const Icon(Icons.bug_report, size: 18),
              label: const Text('テストエラー報告'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _googleDiagnostic,
              icon: const Icon(Icons.vpn_key, size: 18),
              label: const Text('Google診断'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _createSpreadsheet,
              icon: const Icon(Icons.table_chart, size: 18),
              label: const Text('📊 スプレッドシート'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _configureGeminiKey,
              icon: const Icon(Icons.auto_awesome, size: 18),
              label: const Text('Gemini APIキー設定'),
            ),
          ],
        ),
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

  Widget _infoCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('診断情報', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            _infoRow('Mattermost', _service.baseUrl),
            _infoRow('チーム', 'cyb'),
            _infoRow('チャンネル', 'h1-debug'),
            _infoRow('バージョン', _service.appVersion),
          ],
        ),
      ),
    );
  }

  Widget _updateCard(ColorScheme cs) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('アップデート', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _checkingUpdate ? null : _checkUpdate,
              icon: _checkingUpdate
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.update, size: 18),
              label: Text(_checkingUpdate ? '確認中...' : '最新版を確認'),
            ),
            if (_updateError != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(_updateError!, style: TextStyle(color: cs.error)),
              ),
            if (_updater.hasUpdate) ...[
              const SizedBox(height: 8),
              Text('最新: ${_updater.latestVersion}', style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
                  Row(
                    children: [
                      FilledButton.icon(
                        onPressed: _downloading ? null : _downloadApk,
                        icon: _downloading
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.download, size: 18),
                        label: const Text('APK'),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: _updater.openDownloadUrl,
                        icon: const Icon(Icons.open_in_browser, size: 18),
                        label: const Text('ブラウザで開く'),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: _updater.openReleasesPage,
                        icon: const Icon(Icons.language, size: 18),
                        label: const Text('GitHub'),
                      ),
                    ],
                  ),
              if (_downloadResult != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(_downloadResult!, style: const TextStyle(fontSize: 12)),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _googleAuthStatus(ColorScheme cs) {
    return FutureBuilder<bool>(
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

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Text('$label: ', style: const TextStyle(fontWeight: FontWeight.w500)),
          Expanded(child: Text(value, overflow: TextOverflow.ellipsis)),
        ],
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
}
