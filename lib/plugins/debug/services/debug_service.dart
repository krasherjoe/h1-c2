import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import '../../../services/database_helper.dart';

class DebugService {
  static const _kPatKey = 'mattermost_pat';
  static const _kTeamKey = 'mattermost_team_name';
  static const _kBaseUrlKey = 'mattermost_base_url';
  static const _kWebhookKey = 'mattermost_webhook_url';
  static const _kRootIdKey = 'mm_root_id';
  static const _kChannelName = 'h1-debug';
  static const _kAppVersion = String.fromEnvironment('APP_VERSION', defaultValue: '1.2.26+1');

  String get appVersion => _kAppVersion;

  String? _pat;
  String? _baseUrl;
  String? _teamName;
  String? _channelId;
  String? _rootId;

  bool get isConfigured => _pat != null && _baseUrl != null;

  String get baseUrl => _baseUrl ?? 'https://mm.ka.sugeee.com';

  Future<void> loadConfig() async {
    final prefs = await SharedPreferences.getInstance();
    _pat = prefs.getString(_kPatKey);
    _baseUrl = prefs.getString(_kBaseUrlKey) ?? 'https://mm.ka.sugeee.com';
    _teamName = prefs.getString(_kTeamKey) ?? 'cyb';
    _rootId = prefs.getString(_kRootIdKey);
  }

  Future<void> saveConfig({
    String? pat,
    String? baseUrl,
    String? teamName,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    if (pat != null) { _pat = pat; await prefs.setString(_kPatKey, pat); }
    if (baseUrl != null) { _baseUrl = baseUrl; await prefs.setString(_kBaseUrlKey, baseUrl); }
    if (teamName != null) { _teamName = teamName; await prefs.setString(_kTeamKey, teamName); }
  }

  Map<String, String> get _headers => {
    'Authorization': 'Bearer $_pat',
    'Content-Type': 'application/json',
  };

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
      debugPrint('[DebugService] channel lookup failed: $e');
      return null;
    }
  }

  Future<String> _getWebhookUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kWebhookKey) ?? 'https://mm.ka.sugeee.com/hooks/x6nxx8q35jdkuetbmh89ogt5ze';
  }

  Future<bool> sendText(String text) async {
    try {
      final url = await _getWebhookUrl();
      if (url.isEmpty) return false;
      final body = <String, dynamic>{'text': text};
      if (_rootId != null) body['root_id'] = _rootId;

      final res = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );
      if (res.statusCode == 200 && _rootId == null && res.body.trim().isNotEmpty) {
        _rootId = res.body.trim();
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_kRootIdKey, _rootId!);
      }
      if (res.statusCode == 404 && _rootId != null) {
        _rootId = null;
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(_kRootIdKey);
        return sendText(text);
      }
      return res.statusCode == 200;
    } catch (e) {
      debugPrint('[DebugService] sendText error: $e');
      return false;
    }
  }

  Future<bool> sendTextViaPat(String text) async {
    if (!isConfigured) return false;
    final channelId = await _ensureChannelId();
    if (channelId == null) return false;
    try {
      final res = await http.post(
        Uri.parse('$_baseUrl/api/v4/posts'),
        headers: _headers,
        body: jsonEncode({
          'channel_id': channelId,
          'message': text,
        }),
      );
      return res.statusCode == 201;
    } catch (e) {
      debugPrint('[DebugService] sendTextViaPat error: $e');
      return false;
    }
  }

  Future<String?> sendDbReport() async {
    if (!isConfigured) return 'PAT未設定';
    final channelId = await _ensureChannelId();
    if (channelId == null) return 'チャンネル取得失敗';

    try {
      final db = await DatabaseHelper().database;
      final dbPath = db.path;
      final dbFile = File(dbPath);
      if (!await dbFile.exists()) return 'DBファイルなし';

      final bytes = await dbFile.readAsBytes();
      final sizeMb = (bytes.length / 1024 / 1024).toStringAsFixed(1);
      final now = DateTime.now();
      final dateStr = '${now.year}${_two(now.month)}${_two(now.day)}_${_two(now.hour)}${_two(now.minute)}';

      final uploadReq = http.MultipartRequest(
        'POST',
        Uri.parse('$_baseUrl/api/v4/files'),
      );
      uploadReq.headers['Authorization'] = 'Bearer $_pat';
      uploadReq.fields['channel_id'] = channelId;
      uploadReq.files.add(await http.MultipartFile.fromBytes(
        'files', bytes, filename: 'h1-core_db_$dateStr.db',
      ));
      final uploadRes = await uploadReq.send();
      final uploadBody = await uploadRes.stream.bytesToString();
      if (uploadRes.statusCode != 201) return 'アップロード失敗(${uploadRes.statusCode})';

      final data = jsonDecode(uploadBody);
      final fileIds = (data['file_infos'] as List)
          .map<String>((f) => f['id'] as String).toList();

      final postRes = await http.post(
        Uri.parse('$_baseUrl/api/v4/posts'),
        headers: _headers,
        body: jsonEncode({
          'channel_id': channelId,
          'message': ':floppy_disk: **h-1-core DB送信** | v$_kAppVersion | ${sizeMb}MB',
          'file_ids': fileIds,
        }),
      );
      if (postRes.statusCode != 201) return '投稿作成失敗(${postRes.statusCode})';
      return null;
    } catch (e) {
      return '例外: $e';
    }
  }

  String _two(int n) => n.toString().padLeft(2, '0');
}
