import 'package:flutter/material.dart';
import '../services/debug_service.dart';
import '../services/update_service.dart';
import '../../../widgets/h1_text_field.dart';

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

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await _service.loadConfig();
    if (!mounted) return;
    setState(() => _loading = false);
  }

  Future<void> _sendDb() async {
    setState(() { _sendingDb = true; _dbResult = null; });
    final result = await _service.sendDbReport();
    if (!mounted) return;
    setState(() { _dbResult = result ?? '送信成功'; _sendingDb = false; });
  }

  Future<void> _sendTestReport() async {
    await _service.sendText(
      '### \u{1F9EA} h-1-core 診断テスト\n\n'
      '**時刻:** ${DateTime.now().toIso8601String()}',
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('テスト報告を送信しました')),
    );
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
      appBar: AppBar(title: const Text('デバッグ')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _statusCard(cs),
          const SizedBox(height: 12),
          _actionsCard(cs),
          const SizedBox(height: 12),
          _infoCard(),
          const SizedBox(height: 12),
          _updateCard(cs),
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
            _statusRow(Icons.webhook, 'Webhook', _service.isConfigured),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  const Icon(Icons.cloud, size: 18, color: Colors.grey),
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
                        label: Text(_downloading ? 'ダウンロード中...' : 'APK保存'),
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

  Widget _statusRow(IconData icon, String label, bool ok) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: ok ? Colors.green : Colors.grey),
          const SizedBox(width: 8),
          Text(label),
          const Spacer(),
          Icon(ok ? Icons.check_circle : Icons.cancel, size: 16,
            color: ok ? Colors.green : Colors.grey),
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
}
