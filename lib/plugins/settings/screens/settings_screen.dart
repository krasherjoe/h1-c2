import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../main.dart' show themeNotifier;
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
    });
  }

  void _setTheme(ThemeMode mode) {
    setState(() => _themeMode = mode);
    _repo.themeMode = mode;
    themeNotifier.value = mode;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('設定')),
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
                  border: OutlineInputBorder(),
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
        ],
      ),
    );
  }
}
