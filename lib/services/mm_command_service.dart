import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'debug_console.dart';

class MmCommandService {
  static final MmCommandService instance = MmCommandService._();
  MmCommandService._();

  static const _kEnabledKey = 'mm_polling_enabled';
  static const _kLastCheckKey = 'mm_polling_last_check';
  static const _kProcessedKey = 'mm_processed_posts';
  static const _kPatKey = 'mattermost_pat';
  static const _kBaseUrlKey = 'mattermost_base_url';
  static const _kTeamKey = 'mattermost_team_name';
  static const _kChannelName = 'h1-debug';
  static const _kPrefix = '!opencode';

  Timer? _timer;
  bool _enabled = false;
  String? _pat;
  String? _baseUrl;
  String? _teamName;
  String? _channelId;

  bool get isEnabled => _enabled;
  String? get baseUrl => _baseUrl;
  String? get pat => _pat;
  Future<String?> get channelId => _ensureChannelId();
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
    (await SharedPreferences.getInstance()).setBool(_kEnabledKey, v);
    if (v) start(); else stop();
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
    final processed = prefs.getStringList(_kProcessedKey) ?? [];

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
      final newProcessed = List<String>.from(processed);
      for (final entry in posts.entries) {
        final post = entry.value as Map<String, dynamic>;
        final msg = post['message'] as String? ?? '';
        final createAt = post['create_at'] as int? ?? 0;
        final postId = post['id'] as String? ?? '';
        if (createAt > latest) latest = createAt;
        if (!msg.startsWith(_kPrefix)) continue;
        final reply = post['parent_id'] != null;
        if (reply) continue;
        if (processed.contains(postId)) continue;
        newProcessed.add(postId);
        await _dispatch(msg, post);
      }
      await prefs.setInt(_kLastCheckKey, latest + 1);
      await prefs.setStringList(_kProcessedKey, newProcessed.take(200).toList());
    } catch (e) {
      debugPrint('[MmCmd] poll failed: $e');
    }
  }

  Future<void> _dispatch(String msg, Map<String, dynamic> post) async {
    final rest = msg.substring(_kPrefix.length).trim();
    if (rest.isEmpty) return;
    final parts = rest.split(' ');
    final name = parts[0];
    final args = parts.length > 1 ? parts.sublist(1) : <String>[];
    debugPrint('[MmCmd] dispatch: $name $args');

    final result = await DebugConsole.call(name, args);
    final channelId = await _ensureChannelId();
    if (channelId == null) return;
    try {
      await http.post(
        Uri.parse('$_baseUrl/api/v4/posts'),
        headers: _headers,
        body: jsonEncode({
          'channel_id': channelId,
          'message': result,
          'root_id': post['id'],
        }),
      );
    } catch (e) {
      debugPrint('[MmCmd] post failed: $e');
    }
  }

  Future<String?> uploadFile(List<int> bytes, String filename, {String? message}) async {
    final channelId = await _ensureChannelId();
    if (channelId == null) return 'チャンネル取得失敗';
    if (_pat == null || _baseUrl == null) return 'PAT未設定';
    try {
      final uploadReq = http.MultipartRequest(
        'POST', Uri.parse('$_baseUrl/api/v4/files'),
      );
      uploadReq.headers['Authorization'] = 'Bearer $_pat';
      uploadReq.fields['channel_id'] = channelId;
      uploadReq.files.add(await http.MultipartFile.fromBytes('files', bytes, filename: filename));
      final uploadRes = await uploadReq.send();
      final uploadBody = await uploadRes.stream.bytesToString();
      if (uploadRes.statusCode != 201) return 'アップロード失敗(${uploadRes.statusCode})';
      final data = jsonDecode(uploadBody);
      final fileIds = (data['file_infos'] as List).map<String>((f) => f['id'] as String).toList();
      if (message != null && fileIds.isNotEmpty) {
        await http.post(
          Uri.parse('$_baseUrl/api/v4/posts'),
          headers: _headers,
          body: jsonEncode({'channel_id': channelId, 'message': message, 'file_ids': fileIds}),
        );
      }
      return null;
    } catch (e) {
      return 'アップロード例外: $e';
    }
  }
}
