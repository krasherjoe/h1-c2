import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../main.dart' show themeNotifier, inputStyleNotifier;
import '../../../services/error_reporter.dart';
import '../../../widgets/screen_id_title.dart';
import '../services/settings_repository.dart';

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

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    _repo = SettingsRepository(prefs);
    setState(() {
      _taxRate = _repo.defaultTaxRate;
      _prefix = _repo.documentNumberPrefix;
      _themeMode = _repo.themeMode;
      _webhookUrl = prefs.getString('mattermost_webhook_url') ?? '';
      _inputStyle = _repo.inputFieldStyle;
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
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const ScreenAppBarTitle(screenId: 'SA', title: '設定'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('基本設定', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          ListTile(
            leading: const Icon(Icons.business),
            title: const Text('自社情報'),
            subtitle: const Text('会社名・住所・電話番号など'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.pushNamed(context, '/company'),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.percent),
            title: const Text('デフォルト税率'),
            trailing: DropdownButton<int>(
              value: _taxRate,
              underline: const SizedBox(),
              items: const [
                DropdownMenuItem(value: 10, child: Text('10%')),
                DropdownMenuItem(value: 8, child: Text('8%')),
              ],
              onChanged: (v) {
                if (v == null) return;
                setState(() => _taxRate = v);
                _repo.defaultTaxRate = v;
              },
            ),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.tag),
            title: const Text('伝票番号の接頭辞'),
            trailing: SizedBox(
              width: 120,
              child: TextField(
                controller: TextEditingController(text: _prefix),
                decoration: const InputDecoration(
                  hintText: '例: SK-',
                  isDense: true,
                ),
                onSubmitted: (v) {
                  _prefix = v;
                  _repo.documentNumberPrefix = v;
                },
              ),
            ),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.palette),
            title: const Text('テーマ'),
            trailing: SegmentedButton<ThemeMode>(
              segments: const [
                ButtonSegment(
                  value: ThemeMode.system,
                  label: Text('システム'),
                  icon: Icon(Icons.settings_brightness),
                ),
                ButtonSegment(
                  value: ThemeMode.light,
                  label: Text('ライト'),
                  icon: Icon(Icons.light_mode),
                ),
                ButtonSegment(
                  value: ThemeMode.dark,
                  label: Text('ダーク'),
                  icon: Icon(Icons.dark_mode),
                ),
              ],
              selected: {_themeMode},
              onSelectionChanged: (v) => _setTheme(v.first),
            ),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.text_fields),
            title: const Text('入力フィールドスタイル'),
            trailing: SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'raised', label: Text('立体'), icon: Icon(Icons.layers)),
                ButtonSegment(value: 'outlined', label: Text('縁取り'), icon: Icon(Icons.border_style)),
              ],
              selected: {_inputStyle},
              onSelectionChanged: (v) => _setInputStyle(v.first),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'テスト入力',
                prefixIcon: Icon(Icons.text_fields),
              ),
            ),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.webhook),
            title: const Text('Mattermost Webhook URL'),
            subtitle: const Text('エラー報告送信先'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 200,
                  child: TextField(
                    controller: TextEditingController(text: _webhookUrl),
                    decoration: const InputDecoration(
                      hintText: 'https://mm.ka.sugeee.com/hooks/xxx',
                      isDense: true,
                    ),
                    style: const TextStyle(fontSize: 12),
                    onSubmitted: (v) {
                      _webhookUrl = v.trim();
                      ErrorReporter.setWebhookUrl(_webhookUrl);
                    },
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send, size: 18),
                  tooltip: 'テスト送信',
                  onPressed: () {
                    ErrorReporter.setWebhookUrl(_webhookUrl.trim());
                    ErrorReporter.sendError(
                      message: '設定テスト',
                      detail: '設定画面からのテスト送信です',
                      screenId: 'settings',
                    );
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('テスト送信しました')),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
