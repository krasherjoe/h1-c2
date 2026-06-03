import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'database_helper.dart';

class MmCommandService {
  static final MmCommandService instance = MmCommandService._();
  MmCommandService._();

  static const _kEnabledKey = 'mm_polling_enabled';
  static const _kLastCheckKey = 'mm_polling_last_check';
  static const _kPatKey = 'mattermost_pat';
  static const _kBaseUrlKey = 'mattermost_base_url';
  static const _kTeamKey = 'mattermost_team_name';
  static const _kChannelName = 'h1-debug';
  static const _kPrefix = '!opencode';
  static const _kAppVersion = String.fromEnvironment('APP_VERSION', defaultValue: '1.2.26+1');

  Timer? _timer;
  bool _enabled = false;
  String? _pat;
  String? _baseUrl;
  String? _teamName;
  String? _channelId;

  bool get isEnabled => _enabled;

  final ValueNotifier<bool> enabledNotifier = ValueNotifier(false);

  Map<String, String> get _headers => {
    'Authorization': 'Bearer $_pat',
    'Content-Type': 'application/json',
  };

  Future<void> loadConfig() async {
    final prefs = await SharedPreferences.getInstance();
    _pat = prefs.getString(_kPatKey);
    _baseUrl = prefs.getString(_kBaseUrlKey) ?? 'https://mm.ka.sugeee.com';
    _teamName = prefs.getString(_kTeamKey) ?? 'cyb';
    _enabled = prefs.getBool(_kEnabledKey) ?? false;
    enabledNotifier.value = _enabled;
  }

  Future<void> setEnabled(bool v) async {
    _enabled = v;
    enabledNotifier.value = v;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kEnabledKey, v);
    if (v) {
      start();
    } else {
      stop();
    }
  }

  Future<String?> _ensureChannelId() async {
    if (_channelId != null) return _channelId;
    if (_baseUrl == null || _teamName == null || _pat == null) return null;
    try {
      final teamRes = await http.get(
        Uri.parse('$_baseUrl/api/v4/teams/name/$_teamName'),
        headers: _headers,
      );
      if (teamRes.statusCode != 200) return null;
      final team = jsonDecode(teamRes.body);
      final teamId = team['id'] as String;

      final chRes = await http.get(
        Uri.parse('$_baseUrl/api/v4/teams/$teamId/channels/name/$_kChannelName'),
        headers: _headers,
      );
      if (chRes.statusCode != 200) return null;
      final ch = jsonDecode(chRes.body);
      _channelId = ch['id'] as String;
      return _channelId;
    } catch (e) {
      debugPrint('[MmCmd] channel lookup failed: $e');
      return null;
    }
  }

  void start() {
    if (!_enabled) return;
    _timer?.cancel();
    _poll();
    _timer = Timer.periodic(const Duration(seconds: 15), (_) => _poll());
    debugPrint('[MmCmd] polling started');
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    debugPrint('[MmCmd] polling stopped');
  }

  Future<void> _poll() async {
    if (_pat == null) return;
    final channelId = await _ensureChannelId();
    if (channelId == null) return;

    final prefs = await SharedPreferences.getInstance();
    final since = prefs.getInt(_kLastCheckKey) ?? 0;

    try {
      final res = await http.get(
        Uri.parse('$_baseUrl/api/v4/channels/$channelId/posts?since=$since'),
        headers: _headers,
      );
      if (res.statusCode != 200) return;

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final posts = data['posts'] as Map<String, dynamic>?;
      if (posts == null || posts.isEmpty) return;

      int latest = since;
      for (final entry in posts.entries) {
        final post = entry.value as Map<String, dynamic>;
        final msg = post['message'] as String? ?? '';
        final createAt = post['create_at'] as int? ?? 0;
        if (createAt > latest) latest = createAt;
        if (!msg.startsWith(_kPrefix)) continue;
        await _executeCommand(msg, post);
      }

      await prefs.setInt(_kLastCheckKey, latest);
    } catch (e) {
      debugPrint('[MmCmd] poll failed: $e');
    }
  }

  Future<void> _executeCommand(String msg, Map<String, dynamic> post) async {
    final parts = msg.split(' ');
    if (parts.length < 2) return;
    final cmd = parts[1].toLowerCase();
    final args = parts.length > 2 ? parts.sublist(2) : <String>[];
    debugPrint('[MmCmd] executing: $cmd $args');

    String result;
    try {
      switch (cmd) {
        case 'ping':
          result = 'pong';
        case 'status':
          result = await _cmdStatus();
        case 'db':
          result = await _cmdDb();
        case 'dump':
          result = await _cmdDump();
        default:
          result = '不明なコマンド: $cmd';
      }
    } catch (e) {
      result = '実行エラー: $e';
    }

    await _postResult(result, post['id'] as String?);
  }

  Future<String> _cmdStatus() async {
    try {
      final db = await DatabaseHelper().database;
      final file = File(db.path);
      final size = await file.length();
      final sizeStr = '${(size / 1024).round()}KB';
      return '✅ 稼働中 | v$_kAppVersion | DB: $sizeStr';
    } catch (e) {
      return 'ステータス取得失敗: $e';
    }
  }

  Future<String> _cmdDump() async {
    try {
      final buf = StringBuffer();
      buf.writeln('```');
      buf.writeln('h-1-core 状態ダンプ');
      buf.writeln('version: $_kAppVersion');
      buf.writeln('---');
      final db = await DatabaseHelper().database;
      final file = File(db.path);
      final size = await file.length();
      buf.writeln('DB path: ${file.path}');
      buf.writeln('DB size: ${(size / 1024).round()}KB (${size} bytes)');
      buf.writeln('---');
      try {
        final tables = await db.rawQuery("SELECT name FROM sqlite_master WHERE type='table' ORDER BY name");
        for (final t in tables) {
          final name = t['name'] as String;
          final cnt = await db.rawQuery('SELECT COUNT(*) as c FROM "$name"');
          final c = cnt.first['c'] ?? 0;
          buf.writeln('  $name: $c rows');
        }
      } catch (_) {}
      buf.writeln('---');
      buf.writeln('MM base: $_baseUrl');
      buf.writeln('MM team: $_teamName');
      buf.writeln('MM channel: $_kChannelName');
      buf.writeln('PAT設定: ${_pat != null ? 'OK' : '未設定'}');
      buf.writeln('ポーリング: ${_enabled ? 'ON' : 'OFF'}');
      buf.writeln('```');
      return buf.toString();
    } catch (e) {
      return 'ダンプ失敗: $e';
    }
  }

  Future<String> _cmdDb() async {
    try {
      final dbPath = await DatabaseHelper().database.then((db) => db.path);
      final file = File(dbPath);
      if (!await file.exists()) return 'DBファイルなし';
      final bytes = await file.readAsBytes();
      final channelId = await _ensureChannelId();
      if (channelId == null) return 'チャンネル取得失敗';

      final uploadReq = http.MultipartRequest(
        'POST',
        Uri.parse('$_baseUrl/api/v4/files'),
      );
      uploadReq.headers['Authorization'] = 'Bearer $_pat';
      uploadReq.fields['channel_id'] = channelId;
      uploadReq.files.add(await http.MultipartFile.fromBytes(
        'files',
        bytes,
        filename: 'h1-core_db_cmd.db',
      ));
      final uploadRes = await uploadReq.send();
      final uploadBody = await uploadRes.stream.bytesToString();
      if (uploadRes.statusCode != 201) return 'アップロード失敗(${uploadRes.statusCode})';
      final data = jsonDecode(uploadBody);
      final fileIds = (data['file_infos'] as List)
          .map<String>((f) => f['id'] as String).toList();

      await http.post(
        Uri.parse('$_baseUrl/api/v4/posts'),
        headers: _headers,
        body: jsonEncode({
          'channel_id': channelId,
          'message': ':floppy_disk: **コマンド経由DB送信**',
          'file_ids': fileIds,
        }),
      );
      return 'DB送信完了';
    } catch (e) {
      return 'DB送信失敗: $e';
    }
  }

  Future<void> _postResult(String text, String? rootId) async {
    final channelId = await _ensureChannelId();
    if (channelId == null) return;
    try {
      await http.post(
        Uri.parse('$_baseUrl/api/v4/posts'),
        headers: _headers,
        body: jsonEncode({
          'channel_id': channelId,
          'message': text,
          if (rootId != null) 'root_id': rootId,
        }),
      );
    } catch (e) {
      debugPrint('[MmCmd] post result failed: $e');
    }
  }
}
