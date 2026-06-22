import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:path/path.dart' as p;
import '../../../main.dart' show themeNotifier;
import '../../../services/input_style_service.dart' show inputStyleNotifier;
import '../../../services/google_auth_service.dart';
import '../../../services/sync_queue.dart';
import '../../../services/update_service.dart';
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
  String _inputStyle = 'raised';
  String? _googleEmail;
  bool _googleSignedIn = false;
  String _lastBackup = '';
  String _currentVersion = '';
  String _latestVersion = '';
  bool _needsUpdate = false;
  bool _checkingUpdate = false;
  bool _downloading = false;
  bool _autoUpdateEnabled = false;
  UpdateFrequency _updateFrequency = UpdateFrequency.off;
  bool _autoInstallEnabled = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    _repo = SettingsRepository(prefs);
    final email = await GoogleAuthService.instance.getEmail();
    final updateService = UpdateService();
    final currentVersion = await updateService.getCurrentVersion();
    final autoUpdateEnabled = await updateService.isAutoUpdateEnabled();
    final updateFrequency = await updateService.getUpdateFrequency();
    final autoInstallEnabled = await updateService.isAutoInstallEnabled();
    final lastBackupStr = prefs.getString('drive_backup_last');
    String lastBackup = '';
    if (lastBackupStr != null) {
      final dt = DateTime.tryParse(lastBackupStr);
      lastBackup = dt != null ? DateFormat('yyyy/MM/dd HH:mm').format(dt) : '';
    } else {
      lastBackup = '';
    }
    setState(() {
      _taxRate = _repo.defaultTaxRate;
      _prefix = _repo.documentNumberPrefix;
      _themeMode = _repo.themeMode;
      _inputStyle = _repo.inputFieldStyle;
      _googleEmail = email;
      _googleSignedIn = email != null && email.isNotEmpty;
      _currentVersion = currentVersion;
      _autoUpdateEnabled = autoUpdateEnabled;
      _updateFrequency = updateFrequency;
      _autoInstallEnabled = autoInstallEnabled;
      _lastBackup = lastBackup;
    });
  }

  Future<void> _checkUpdate() async {
    setState(() => _checkingUpdate = true);
    final updateService = UpdateService();
    final latest = await updateService.getLatestVersion();
    final needsUpdate = await updateService.needsUpdate();
    setState(() {
      _latestVersion = latest ?? _currentVersion;
      _needsUpdate = needsUpdate;
      _checkingUpdate = false;
    });
  }

  Future<void> _downloadAndInstall() async {
    // ダウンロード確認ダイアログ
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('APKをダウンロード'),
        content: const Text('最新バージョンのAPKをダウンロードしますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('ダウンロード'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _downloading = true);

    try {
      final updateService = UpdateService();
      final latest = await updateService.getLatestVersion();
      
      if (latest != null) {
        // プログレスダイアログ表示
        if (!mounted) return;
        final progressNotifier = ValueNotifier<double>(0.0);
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text('APKをダウンロード中'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ValueListenableBuilder<double>(
                  valueListenable: progressNotifier,
                  builder: (context, progress, child) {
                    return Column(
                      children: [
                        LinearProgressIndicator(value: progress),
                        const SizedBox(height: 16),
                        Text('${(progress * 100).toStringAsFixed(0)}%'),
                      ],
                    );
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  updateService.cancelDownload();
                  Navigator.pop(context);
                  setState(() => _downloading = false);
                },
                child: const Text('キャンセル'),
              ),
            ],
          ),
        );

        final apkPath = await updateService.downloadApk(
          latest,
          onProgress: (progress) {
            progressNotifier.value = progress;
          },
        );
        
        // ダイアログを閉じる
        if (mounted) Navigator.pop(context);
        
        if (apkPath != null) {
          // APKをインストール
          final updateService = UpdateService();
          await updateService.installApk(apkPath);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('APKをインストールダイアログを表示しました')),
            );
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('APKのダウンロードに失敗しました')),
            );
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('最新バージョンの取得に失敗しました')),
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() => _downloading = false);
      }
    }
  }

  Future<void> _setAutoUpdateEnabled(bool enabled) async {
    final updateService = UpdateService();
    await updateService.setAutoUpdateEnabled(enabled);
    setState(() => _autoUpdateEnabled = enabled);
  }

  Future<void> _setAutoInstallEnabled(bool enabled) async {
    final updateService = UpdateService();
    await updateService.setAutoInstallEnabled(enabled);
    setState(() => _autoInstallEnabled = enabled);
  }

  Future<void> _setUpdateFrequency(UpdateFrequency frequency) async {
    final updateService = UpdateService();
    await updateService.setUpdateFrequency(frequency);
    setState(() => _updateFrequency = frequency);
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
                  backgroundColor: _googleSignedIn ? Colors.green.shade50 : cs.surfaceContainerHighest,
                  foregroundColor: _googleSignedIn ? Colors.green.shade700 : cs.onSurfaceVariant,
                  child: Icon(_googleSignedIn ? Icons.cloud_done : Icons.cloud_off, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Google アカウント', style: TextStyle(fontWeight: FontWeight.w600, color: cs.onSurface)),
                    const SizedBox(height: 2),
                    Text(_googleSignedIn ? (_googleEmail ?? '') : '未設定',
                        style: TextStyle(fontSize: 12, color: _googleSignedIn ? Colors.green.shade700 : cs.error)),
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

          _sectionHeader(cs, Icons.system_update, 'アプリ更新', '最新バージョンを確認して更新できます'),
          const SizedBox(height: 8),
          _settingsCard(cs, children: [
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: cs.surfaceContainerHighest, borderRadius: BorderRadius.circular(8)),
                child: Icon(Icons.info, color: cs.onSurfaceVariant, size: 20),
              ),
              title: Text('現在のバージョン', style: TextStyle(fontWeight: FontWeight.w600, color: cs.onSurface)),
              trailing: Text(_currentVersion, style: TextStyle(color: cs.onSurfaceVariant)),
            ),
            const Divider(height: 1),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: cs.surfaceContainerHighest, borderRadius: BorderRadius.circular(8)),
                child: Icon(Icons.cloud_download, color: cs.onSurfaceVariant, size: 20),
              ),
              title: Text('最新バージョン', style: TextStyle(fontWeight: FontWeight.w600, color: cs.onSurface)),
              trailing: _checkingUpdate
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : _downloading
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : _latestVersion.isEmpty
                          ? TextButton.icon(
                              onPressed: _checkUpdate,
                              icon: const Icon(Icons.refresh, size: 16),
                              label: const Text('更新'),
                            )
                          : InkWell(
                              onTap: _downloadAndInstall,
                              child: Text(
                                _latestVersion,
                                style: TextStyle(
                                  color: _needsUpdate ? cs.error : cs.onSurfaceVariant,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
            ),
            const Divider(height: 1),
            SwitchListTile(
              value: _autoUpdateEnabled,
              onChanged: _setAutoUpdateEnabled,
              title: Text('自動アップデート', style: TextStyle(fontWeight: FontWeight.w600, color: cs.onSurface)),
              subtitle: Text('定期的に更新を確認します', style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
            ),
            if (_autoUpdateEnabled)
              Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: SegmentedButton<UpdateFrequency>(
                      segments: const [
                        ButtonSegment(value: UpdateFrequency.threeMinutes, label: Text('3分')),
                        ButtonSegment(value: UpdateFrequency.daily, label: Text('毎日')),
                        ButtonSegment(value: UpdateFrequency.weekly, label: Text('毎週')),
                        ButtonSegment(value: UpdateFrequency.monthly, label: Text('毎月')),
                      ],
                      selected: {_updateFrequency},
                      onSelectionChanged: (v) => _setUpdateFrequency(v.first),
                    ),
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    value: _autoInstallEnabled,
                    onChanged: _setAutoInstallEnabled,
                    title: Text('自動インストール', style: TextStyle(fontWeight: FontWeight.w600, color: cs.onSurface)),
                    subtitle: Text('更新を自動でインストールします', style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
                  ),
                ],
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
              subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Google Driveに自動バックアップ（24時間ごと）',
                        style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
                    if (_lastBackup.isNotEmpty)
                      Text('最終: $_lastBackup',
                          style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant.withValues(alpha: 0.7))),
                  ]),
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
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _repo.defaultTaxRate = _taxRate;
          _repo.documentNumberPrefix = _prefix;
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
