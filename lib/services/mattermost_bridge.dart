import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'debug_console.dart';
import '../constants/secure_storage_keys.dart';
import '../constants/env_config.dart';
import 'secure_storage_service.dart';

class MattermostBridge {
  static Timer? _timer;
  static bool _running = false;
  static String? _lastPostId;

  static const _kEnabledKey = 'mm_polling_enabled';
  static const _kChannelId = 'n6fr87ipuj8epc463o7fu7gdao';
  static const _kPollInterval = Duration(seconds: 10);

  static String get _baseUrl => EnvConfig.mattermostBaseUrl;

  static bool get isRunning => _running;

  static Future<bool> get isEnabled async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kEnabledKey) ?? false;
  }

  static Future<void> setEnabled(bool v) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kEnabledKey, v);
    if (v) {
      start();
    } else {
      stop();
    }
  }

  static Future<String?> get botToken async {
    return await SecureStorageService.instance.read(SecureStorageKeys.mmBotToken);
  }

  static Future<void> setBotToken(String v) async {
    await SecureStorageService.instance.write(SecureStorageKeys.mmBotToken, v);
  }

  static Future<String?> get devUserId async {
    return await SecureStorageService.instance.read(SecureStorageKeys.mmDevUserId);
  }

  static Future<void> setDevUserId(String v) async {
    await SecureStorageService.instance.write(SecureStorageKeys.mmDevUserId, v);
  }

  static void start() {
    if (_running) return;
    _running = true;
    _lastPostId = null;
    _timer = Timer.periodic(_kPollInterval, (_) => _poll());
    debugPrint('[MattermostBridge] ポーリング開始');
  }

  static void stop() {
    _running = false;
    _timer?.cancel();
    _timer = null;
    debugPrint('[MattermostBridge] ポーリング停止');
  }

  static Future<void> _poll() async {
    if (!_running) return;
    try {
      final token = await botToken;
      if (token == null || token.isEmpty) return;
      final devId = await devUserId;
      if (devId == null || devId.isEmpty) return;

      final uri = Uri.parse('$_baseUrl/api/v4/channels/$_kChannelId/posts');
      final res = await http.get(uri, headers: {
        'Authorization': 'Bearer $token',
      });
      if (res.statusCode != 200) {
        debugPrint('[MattermostBridge] API error: ${res.statusCode} ${res.body}');
        return;
      }
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final posts = data['posts'] as Map<String, dynamic>;
      final order = (data['order'] as List).cast<String>();

      for (final pid in order.reversed) {
        if (_lastPostId != null && pid == _lastPostId) break;
        final post = posts[pid] as Map<String, dynamic>;
        final userId = post['user_id'] as String?;
        if (userId != devId) continue;
        final msg = (post['message'] as String?)?.trim() ?? '';
        if (!msg.startsWith('!')) continue;
        final cmdLine = msg.substring(1).trim();
        if (cmdLine.isEmpty) continue;
        final parts = cmdLine.split(RegExp(r'\s+'));
        final cmd = parts.first;
        final args = parts.length > 1 ? parts.sublist(1) : <String>[];
        debugPrint('[MattermostBridge] コマンド受信: $cmdLine');
        final result = await DebugConsole.call(cmd, args);
        await _postResult('**$cmdLine**\n```\n$result\n```');
      }
      if (order.isNotEmpty) {
        _lastPostId = order.last;
      }
    } catch (e) {
      debugPrint('[MattermostBridge] poll error: $e');
    }
  }

  static Future<void> _postResult(String text) async {
    try {
      final webhook = EnvConfig.mattermostWebhookUrl;
      if (webhook.isEmpty) return;
      await http.post(
        Uri.parse(webhook),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'text': text}),
      );
    } catch (e) {
      debugPrint('[MattermostBridge] post error: $e');
    }
  }
}
