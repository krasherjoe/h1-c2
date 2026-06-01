import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ErrorReporter {
  static const _kWebhookUrlKey = 'mattermost_webhook_url';
  static const _kDefaultWebhookUrl = 'https://mm.ka.sugeee.com/hooks/x6nxx8q35jdkuetbmh89ogt5ze';
  static const _kEnvUrl = String.fromEnvironment('MATTERMOST_WEBHOOK_URL');
  static const _kAppVersion = String.fromEnvironment('APP_VERSION', defaultValue: '1.2.4+1');

  static Future<String> _getWebhookUrl() async {
    if (_kEnvUrl.isNotEmpty) return _kEnvUrl;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kWebhookUrlKey) ?? _kDefaultWebhookUrl;
  }

  static Future<void> setWebhookUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kWebhookUrlKey, url);
  }

  static Future<void> sendError({
    required String message,
    String? detail,
    String? screenId,
    StackTrace? stackTrace,
  }) async {
    try {
      final url = await _getWebhookUrl();
      if (url.isEmpty) {
        debugPrint('[ErrorReporter] webhook URL未設定');
        return;
      }
      debugPrint('[ErrorReporter] sending to $url');
      final body = {
        'text': [
          '### ⚠️ h-1-core エラー報告',
          '',
          '**version:** $_kAppVersion',
          '**message:** $message',
          if (detail != null) '**detail:** $detail',
          if (screenId != null) '**screen:** $screenId',
          if (stackTrace != null)
            '**stack:**\n```\n${stackTrace.toString().substring(0, stackTrace.toString().length.clamp(0, 500))}\n```',
        ].join('\n'),
      };
      await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );
      debugPrint('[ErrorReporter] sent successfully');
    } catch (e) {
      debugPrint('[ErrorReporter] send failed: $e');
    }
  }

  static void showError(
    BuildContext context, {
    required String message,
    String? detail,
    String? screenId,
    StackTrace? stackTrace,
  }) {
    sendError(
      message: message,
      detail: detail,
      screenId: screenId,
      stackTrace: stackTrace,
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
      ),
    );
  }
}
