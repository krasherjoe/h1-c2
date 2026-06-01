import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/settings_repository.dart';
import 'company_profile_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late SettingsRepository _repo;
  int _taxRate = 10;
  String _prefix = '';

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
    });
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
            title: const Text('会社情報'),
            subtitle: const Text('会社名・住所・電話番号など'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CompanyProfileScreen()),
            ),
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
        ],
      ),
    );
  }
}
