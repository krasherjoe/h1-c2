import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/env_config.dart';

class LogDispatcher {
  static const _kDestKey = 'log_output_dest';
  static const _kWebhookKey = 'mattermost_webhook_url';
  static String _dest = 'mm';

  static Future<void> loadConfig() async {
    final prefs = await SharedPreferences.getInstance();
    _dest = prefs.getString(_kDestKey) ?? 'mm';
  }

  static Future<void> setDest(String d) async {
    _dest = d;
    (await SharedPreferences.getInstance()).setString(_kDestKey, d);
  }

  static String get dest => _dest;

  static Future<void> send(String text) async {
    if (_dest == 'mm' || _dest == 'both') await _sendMm(text);
    if (_dest == 'gmail' || _dest == 'both') await _sendGmail(text);
  }

  static Future<void> _sendMm(String text) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final url = prefs.getString(_kWebhookKey) ?? EnvConfig.mattermostWebhookUrl;
      await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: '{"text":${jsonEncode(text)}}',
      );
    } catch (e) {
      debugPrint('[LogDispatcher] MM送信失敗: $e');
    }
  }

  static Future<void> _sendGmail(String text) async {
    // TODO: Gmail出力（次フェーズ）
    debugPrint('[LogDispatcher] Gmail出力未実装');
  }
}
