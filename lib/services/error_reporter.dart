import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:googleapis/gmail/v1.dart' as gmail;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'google_auth_service.dart';

class ErrorReporter {
  static const _kWebhookUrlKey = 'mattermost_webhook_url';
  static const _kDefaultWebhookUrl = 'https://mm.ka.sugeee.com/hooks/x6nxx8q35jdkuetbmh89ogt5ze';
  static const _kEnvUrl = String.fromEnvironment('MATTERMOST_WEBHOOK_URL');
  static const _kAppVersion = String.fromEnvironment('APP_VERSION', defaultValue: '1.2.26+1');

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

    try {
      await sendErrorViaGmail(
        message: message,
        screenId: screenId,
        stackTrace: stackTrace,
      );
    } catch (_) {}
  }

  static Future<void> sendErrorViaGmail({
    required String message,
    String? screenId,
    StackTrace? stackTrace,
  }) async {
    final client = await GoogleAuthService.instance.getAuthenticatedClient();
    if (client == null) return;
    final email = await GoogleAuthService.instance.getEmail();
    if (email == null) {
      client.close();
      return;
    }

    try {
      final api = gmail.GmailApi(client);
      final shortMsg = message.length > 80 ? '${message.substring(0, 80)}...' : message;
      final subject = screenId != null
          ? '[Error:h1-core] $screenId: $shortMsg'
          : '[Error:h1-core] $shortMsg';
      final stackStr = stackTrace?.toString() ?? '';
      final bodyContent = '''
version: $_kAppVersion
message: $message
screen: ${screenId ?? 'N/A'}

stack:
$stackStr
''';

      final raw = base64UrlEncode(utf8.encode(
        'To: $email\r\n'
        'Subject: $subject\r\n'
        'MIME-Version: 1.0\r\n'
        'Content-Type: text/plain; charset=UTF-8\r\n\r\n'
        '$bodyContent',
      ));

      await api.users.messages.send(gmail.Message(raw: raw), 'me');
    } catch (e) {
      debugPrint('[ErrorReporter] Gmail send failed: $e');
    } finally {
      client.close();
    }
  }

  static Future<void> sendLog({required String message}) async {
    try {
      final url = await _getWebhookUrl();
      if (url.isEmpty) return;
      await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'text': '🧪 **h-1-core ログ** ($_kAppVersion)\n$message',
        }),
      );
    } catch (e) {
      debugPrint('[ErrorReporter] sendLog failed: $e');
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
