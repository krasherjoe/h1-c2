import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../main.dart' show themeNotifier;
import '../../../services/input_style_service.dart' show inputStyleNotifier;
import '../../../services/error_reporter.dart';
import '../../../services/google_auth_service.dart';
import '../../../services/sync_queue.dart';
import '../../../widgets/screen_id_title.dart';
import '../services/settings_repository.dart';
import '../../../widgets/h1_text_field.dart';
import '../../../constants/screen_ids.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late SettingsRepository _repo;
  int _taxRate = 10;
  String _prefix = '';
  ThemeMode _themeMode = ThemeMode.system;
  String _webhookUrl = '';
  String _inputStyle = 'raised';
  String? _googleEmail;
  bool _googleSignedIn = false;
  bool _devExpanded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    _repo = SettingsRepository(prefs);
    final email = await GoogleAuthService.instance.getEmail();
    setState(() {
      _taxRate = _repo.defaultTaxRate;
      _prefix = _repo.documentNumberPrefix;
      _themeMode = _repo.themeMode;
      _webhookUrl = prefs.getString('mattermost_webhook_url') ?? '';
      _inputStyle = _repo.inputFieldStyle;
      _googleEmail = email;
      _googleSignedIn = email != null && email.isNotEmpty;
    });
  }

  void _setTheme(ThemeMode mode) {
    setState(() => _themeMode = mode);
    _repo.themeMode = mode;
    themeNotifier.value = mode;
  }

  void _setInputStyle(String v) {
    setState(() => _inputStyle = v);
    _repo.inputFieldStyle = v;
    inputStyleNotifier.value = v;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const ScreenAppBarTitle(screenId: S.set, title: '設定'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            tooltip: '保存',
            onPressed: () {
              _repo.defaultTaxRate = _taxRate;
              _repo.documentNumberPrefix = _prefix;
              if (_webhookUrl.isNotEmpty) ErrorReporter.setWebhookUrl(_webhookUrl);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('設定を保存しました'), duration: Duration(seconds: 1)),
              );
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _sectionHeader(cs, Icons.business, '企業設定', '伝票に表示する会社情報や基本設定です'),
          const SizedBox(height: 8),
          _settingsCard(cs, children: [
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: cs.primaryContainer, borderRadius: BorderRadius.circular(8)),
                child: Icon(Icons.business, color: cs.primary, size: 20),
              ),
              title: Text('自社情報', style: TextStyle(fontWeight: FontWeight.w600, color: cs.onSurface)),
              subtitle: Text('会社名・住所・電話番号・メール・銀行口座\n伝票やPDFに印刷されます。後で必ず必要になります',
                  style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.pushNamed(context, '/company'),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Row(children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: cs.primaryContainer, borderRadius: BorderRadius.circular(8)),
                  child: Icon(Icons.percent, color: cs.primary, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('デフォルト税率', style: TextStyle(fontWeight: FontWeight.w600, color: cs.onSurface)),
                    const SizedBox(height: 2),
                    Text('新規伝票作成時の初期税率です', style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
                  ],
                )),
                SegmentedButton<int>(
                  segments: const [
                    ButtonSegment(value: 10, label: Text('10%', style: TextStyle(fontSize: 13))),
                    ButtonSegment(value: 8, label: Text('8%', style: TextStyle(fontSize: 13))),
                  ],
                  selected: {_taxRate},
                  onSelectionChanged: (v) {
                    setState(() => _taxRate = v.first);
                    _repo.defaultTaxRate = v.first;
                  },
                  style: SegmentedButton.styleFrom(visualDensity: VisualDensity.compact),
                ),
              ]),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Row(children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: cs.primaryContainer, borderRadius: BorderRadius.circular(8)),
                  child: Icon(Icons.tag, color: cs.primary, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('伝票番号の接頭辞', style: TextStyle(fontWeight: FontWeight.w600, color: cs.onSurface)),
                    const SizedBox(height: 2),
                    Text('自動採番される伝票番号の頭に付ける文字です\n例: SK- と設定すると SK-0001 になります',
                        style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
                  ],
                )),
                SizedBox(
                  width: 120,
                  child: H1TextField(
                    controller: TextEditingController(text: _prefix),
                    decoration: const InputDecoration(hintText: '例: SK-', isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8)),
                    onSubmitted: (v) { _prefix = v; _repo.documentNumberPrefix = v; },
                  ),
                ),
              ]),
            ),
          ]),
          const SizedBox(height: 16),

          _sectionHeader(cs, Icons.cloud, 'Google連携', '控えメールの自動送信とクラウドバックアップに使います'),
          const SizedBox(height: 8),
          _settingsCard(cs, children: [
            Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
              child: Row(children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: cs.primaryContainer,
                  foregroundColor: cs.primary,
                  child: Icon(_googleSignedIn ? Icons.cloud_done : Icons.cloud_off, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Google アカウント', style: TextStyle(fontWeight: FontWeight.w600, color: cs.onSurface)),
                    const SizedBox(height: 2),
                    Text(_googleSignedIn ? (_googleEmail ?? '') : '未設定',
                        style: TextStyle(fontSize: 12, color: _googleSignedIn ? cs.primary : cs.error)),
                    const SizedBox(height: 2),
                    Text('正式発行した伝票の控えを自動メール送信します\nDriveへのバックアップにも使用します',
                        style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant)),
                  ],
                )),
                TextButton(
                  style: _googleSignedIn ? TextButton.styleFrom(foregroundColor: cs.error) : null,
                  onPressed: () async {
                    if (_googleSignedIn) {
                      await GoogleAuthService.instance.signOut();
                      await _load();
                    } else {
                      final ok = await GoogleAuthService.instance.signIn();
                      await _load();
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(ok ? 'ログインしました' : 'ログインに失敗しました')),
                        );
                      }
                    }
                  },
                  child: Text(_googleSignedIn ? '解除' : 'ログイン'),
                ),
              ]),
            ),
          ]),
          const SizedBox(height: 16),

          _sectionHeader(cs, Icons.palette, '表示設定', 'アプリの見た目に関する設定です'),
          const SizedBox(height: 8),
          _settingsCard(cs, children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: cs.primaryContainer, borderRadius: BorderRadius.circular(8)),
                      child: Icon(Icons.palette, color: cs.primary, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Text('テーマ', style: TextStyle(fontWeight: FontWeight.w600, color: cs.onSurface)),
                  ]),
                  const SizedBox(height: 8),
                  SegmentedButton<ThemeMode>(
                    segments: const [
                      ButtonSegment(value: ThemeMode.system, label: Text('自動'), icon: Icon(Icons.settings_brightness)),
                      ButtonSegment(value: ThemeMode.light, label: Text('ライト'), icon: Icon(Icons.light_mode)),
                      ButtonSegment(value: ThemeMode.dark, label: Text('ダーク'), icon: Icon(Icons.dark_mode)),
                    ],
                    selected: {_themeMode},
                    onSelectionChanged: (v) => _setTheme(v.first),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: cs.primaryContainer, borderRadius: BorderRadius.circular(8)),
                      child: Icon(Icons.text_fields, color: cs.primary, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Text('入力フィールド', style: TextStyle(fontWeight: FontWeight.w600, color: cs.onSurface)),
                  ]),
                  const SizedBox(height: 8),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'raised', label: Text('立体'), icon: Icon(Icons.layers)),
                      ButtonSegment(value: 'outlined', label: Text('縁取り'), icon: Icon(Icons.border_style)),
                    ],
                    selected: {_inputStyle},
                    onSelectionChanged: (v) => _setInputStyle(v.first),
                  ),
                  const SizedBox(height: 8),
                  H1TextField(
                    decoration: const InputDecoration(hintText: 'プレビュー: 実際の入力画面でこのスタイルが適用されます'),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
          ]),
          const SizedBox(height: 16),

          _sectionHeader(cs, Icons.backup, 'データ保護', 'データ消失に備えて定期的なバックアップ推奨'),
          const SizedBox(height: 8),
          _settingsCard(cs, children: [
            if (!SyncQueue.instance.isParent)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(children: [
                  Icon(Icons.info_outline, size: 16, color: cs.onSurfaceVariant),
                  const SizedBox(width: 8),
                  Expanded(child: Text('子分モードではデータ保護は親分端末で管理されています',
                      style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant))),
                ]),
              ),
            if (!SyncQueue.instance.isParent)
              const Divider(height: 1),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: SyncQueue.instance.isParent ? Colors.green.shade50 : cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.cloud,
                    color: SyncQueue.instance.isParent ? Colors.green.shade700 : cs.onSurfaceVariant, size: 20),
              ),
              title: Text('Driveバックアップ', style: TextStyle(fontWeight: FontWeight.w600,
                  color: SyncQueue.instance.isParent ? cs.onSurface : cs.onSurfaceVariant)),
              subtitle: Text('Google Driveに自動バックアップ。端末故障や\nアプリ削除時のデータ復旧に使います',
                  style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
              trailing: SyncQueue.instance.isParent
                  ? const Icon(Icons.chevron_right)
                  : Row(mainAxisSize: MainAxisSize.min, children: [
                      Text('子分モード', style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant)),
                      const SizedBox(width: 4),
                      Icon(Icons.lock, size: 14, color: cs.onSurfaceVariant),
                    ]),
              onTap: SyncQueue.instance.isParent ? () => Navigator.pushNamed(context, '/drivebackup') : null,
            ),
            if (SyncQueue.instance.isParent)
              const Divider(height: 1),
            if (SyncQueue.instance.isParent)
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: cs.surfaceContainerHighest, borderRadius: BorderRadius.circular(8)),
                  child: Icon(Icons.folder, color: cs.onSurfaceVariant, size: 20),
                ),
                title: Text('ローカルバックアップ', style: TextStyle(fontWeight: FontWeight.w600, color: cs.onSurface)),
                subtitle: Text('端末内にバックアップ。手動での復元が可能です',
                    style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.pushNamed(context, '/backup'),
              ),
          ]),
          const SizedBox(height: 16),

          InkWell(
            onTap: () => setState(() => _devExpanded = !_devExpanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(children: [
                Icon(Icons.developer_mode, size: 16, color: cs.onSurfaceVariant),
                const SizedBox(width: 6),
                Text('開発者向け設定', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                const Spacer(),
                Icon(_devExpanded ? Icons.expand_less : Icons.expand_more, size: 16, color: cs.onSurfaceVariant),
              ]),
            ),
          ),
          if (_devExpanded) ...[
            const SizedBox(height: 8),
            _settingsCard(cs, children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: cs.surfaceContainerHighest, borderRadius: BorderRadius.circular(8)),
                        child: Icon(Icons.webhook, color: cs.onSurfaceVariant, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('エラー報告 (Mattermost)', style: TextStyle(fontWeight: FontWeight.w600, color: cs.onSurface)),
                          Text('アプリのエラーを開発者に自動報告します', style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
                        ],
                      )),
                    ]),
                    const SizedBox(height: 8),
                    Row(children: [
                      Expanded(
                        child: H1TextField(
                          controller: TextEditingController(text: _webhookUrl),
                          decoration: const InputDecoration(hintText: 'Webhook URL', isDense: true),
                          style: const TextStyle(fontSize: 12),
                          onSubmitted: (v) {
                            _webhookUrl = v.trim();
                            ErrorReporter.setWebhookUrl(_webhookUrl);
                          },
                        ),
                      ),
                    ]),
                  ],
                ),
              ),
            ]),
          ],
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _repo.defaultTaxRate = _taxRate;
          _repo.documentNumberPrefix = _prefix;
          if (_webhookUrl.isNotEmpty) ErrorReporter.setWebhookUrl(_webhookUrl);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('設定を保存しました'), duration: Duration(seconds: 1)),
          );
        },
        child: const Icon(Icons.save),
      ),
    );
  }

  Widget _sectionHeader(ColorScheme cs, IconData icon, String title, String subtitle) {
    return Row(children: [
      Icon(icon, size: 18, color: cs.primary),
      const SizedBox(width: 6),
      Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: cs.onSurface)),
      const Spacer(),
      Text(subtitle, style: TextStyle(fontSize: 9, color: cs.onSurfaceVariant)),
    ]);
  }

  Widget _settingsCard(ColorScheme cs, {required List<Widget> children}) {
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
    );
  }
}
