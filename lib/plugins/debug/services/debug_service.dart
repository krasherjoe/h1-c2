import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import '../../../services/database_helper.dart';
import '../../../constants/secure_storage_keys.dart';
import '../../../constants/env_config.dart';
import '../../../services/secure_storage_service.dart';

class DebugService {
  static const _kChannelName = 'h1-debug';
  static String _appVersion = '';

  String get appVersion => _appVersion;

  static Future<void> initVersion() async {
    if (_appVersion.isNotEmpty) return;
    _appVersion = const String.fromEnvironment('APP_VERSION', defaultValue: '');
    if (_appVersion.isEmpty) {
      try {
        final info = await PackageInfo.fromPlatform();
        _appVersion = info.version;
      } catch (_) {
        _appVersion = 'dev';
      }
    }
  }

  String? _pat;
  String? _baseUrl;
  String? _teamName;
  String? _channelId;
  String? _rootId;

  bool get isConfigured => _pat != null && _baseUrl != null;

  String get baseUrl => _baseUrl ?? EnvConfig.mattermostBaseUrl;

  Future<void> loadConfig() async {
    final secure = SecureStorageService.instance;
    _pat = await secure.read(SecureStorageKeys.mattermostPat);
    _baseUrl = await secure.read(SecureStorageKeys.mattermostBaseUrl) ?? EnvConfig.mattermostBaseUrl;
    _teamName = await secure.read(SecureStorageKeys.mattermostTeamName) ?? EnvConfig.mattermostTeamName;
    _rootId = await secure.read(SecureStorageKeys.mmRootId);
  }

  Future<void> saveConfig({
    String? pat,
    String? baseUrl,
    String? teamName,
  }) async {
    final secure = SecureStorageService.instance;
    if (pat != null) { _pat = pat; await secure.write(SecureStorageKeys.mattermostPat, pat); }
    if (baseUrl != null) { _baseUrl = baseUrl; await secure.write(SecureStorageKeys.mattermostBaseUrl, baseUrl); }
    if (teamName != null) { _teamName = teamName; await secure.write(SecureStorageKeys.mattermostTeamName, teamName); }
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
    final secure = SecureStorageService.instance;
    final saved = await secure.read(SecureStorageKeys.mattermostWebhookUrl);
    return saved ?? EnvConfig.mattermostWebhookUrl;
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
        final secure = SecureStorageService.instance;
        await secure.write(SecureStorageKeys.mmRootId, _rootId!);
      }
      if (res.statusCode == 404 && _rootId != null) {
        _rootId = null;
        final secure = SecureStorageService.instance;
        await secure.delete(SecureStorageKeys.mmRootId);
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
          'message': ':floppy_disk: **h-1-core DB送信** | v$_appVersion | ${sizeMb}MB',
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
