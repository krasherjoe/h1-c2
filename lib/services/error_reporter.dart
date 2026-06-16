import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:googleapis/gmail/v1.dart' as gmail;
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'google_auth_service.dart';

class ErrorReporter {
  static const _kWebhookUrlKey = 'mattermost_webhook_url';
  static const _kDefaultWebhookUrl = 'https://mm.ka.sugeee.com/hooks/x6nxx8q35jdkuetbmh89ogt5ze';
  static const _kEnvUrl = String.fromEnvironment('MATTERMOST_WEBHOOK_URL');
  static const _kAppVersion = String.fromEnvironment('APP_VERSION', defaultValue: 'dev');
  static const _kPatKey = 'mattermost_pat';
  static const _kBaseUrlKey = 'mattermost_base_url';
  static const _kTeamKey = 'mattermost_team_name';
  static const _kChannelName = 'h1-debug';

  static Future<String> _getWebhookUrl() async {
    if (_kEnvUrl.isNotEmpty) return _kEnvUrl;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kWebhookUrlKey) ?? _kDefaultWebhookUrl;
  }

  static Future<void> setWebhookUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kWebhookUrlKey, url);
  }

  static Future<bool> _sendViaPat(String text) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final pat = prefs.getString(_kPatKey);
      final baseUrl = prefs.getString(_kBaseUrlKey) ?? 'https://mm.ka.sugeee.com';
      final teamName = prefs.getString(_kTeamKey) ?? 'cyb';
      if (pat == null) {
        debugPrint('[ErrorReporter] PATキー未設定のため送信できません');
        return false;
      }

      final headers = {'Authorization': 'Bearer $pat', 'Content-Type': 'application/json'};
      final teamRes = await http.get(Uri.parse('$baseUrl/api/v4/teams/name/$teamName'), headers: headers);
      if (teamRes.statusCode != 200) {
        debugPrint('[ErrorReporter] PATチーム取得失敗: ${teamRes.statusCode}');
        return false;
      }
      final teamId = (jsonDecode(teamRes.body)['id'] as String?) ?? '';
      if (teamId.isEmpty) return false;

      final chRes = await http.get(Uri.parse('$baseUrl/api/v4/teams/$teamId/channels/name/$_kChannelName'), headers: headers);
      if (chRes.statusCode != 200) return false;
      final chId = (jsonDecode(chRes.body)['id'] as String?) ?? '';
      if (chId.isEmpty) return false;

      final postRes = await http.post(
        Uri.parse('$baseUrl/api/v4/posts'),
        headers: headers,
        body: jsonEncode({'channel_id': chId, 'message': text}),
      );
      debugPrint('[ErrorReporter] PAT送信${postRes.statusCode == 201 ? "成功" : "失敗(${postRes.statusCode})"}');
      return postRes.statusCode == 201;
    } catch (e) {
      debugPrint('[ErrorReporter] PAT送信例外: $e');
      return false;
    }
  }

  static void sendError({
    required String message,
    String? detail,
    String? screenId,
    StackTrace? stackTrace,
  }) {
    final now = DateFormat('yyyy/MM/dd HH:mm:ss').format(DateTime.now());
    final stackStr = stackTrace?.toString().substring(0, stackTrace.toString().length.clamp(0, 500)) ?? 'N/A';
    final text = '### ⚠️ h-1-core エラー報告 ($now)\n'
        '**version:** $_kAppVersion\n'
        '**message:** $message\n'
        '**screen:** ${screenId ?? "N/A"}\n'
        '**detail:** ${detail ?? "N/A"}\n'
        '**stack:**\n```\n$stackStr\n```\n';
    // PATを最優先で即時fire-and-forget
    unawaited(_sendViaPat(text));
    // Webhookも非同期で
    unawaited(_sendViaWebhook(message, detail, screenId, stackTrace, now));
    // Gmailも
    unawaited(sendErrorViaGmail(message: message, screenId: screenId, stackTrace: stackTrace));
  }

  static Future<void> _sendViaWebhook(String message, String? detail, String? screenId, StackTrace? stackTrace, String now) async {
    try {
      final url = await _getWebhookUrl();
      if (url.isEmpty) return;
      final body = {
        'text': [
          '### ⚠️ h-1-core エラー報告 ($now)',
          '',
          '**version:** $_kAppVersion',
          '**message:** $message',
          if (detail != null) '**detail:** $detail',
          if (screenId != null) '**screen:** $screenId',
          if (stackTrace != null)
            '**stack:**\n```\n${stackTrace.toString().substring(0, stackTrace.toString().length.clamp(0, 500))}\n```',
        ].join('\n'),
      };
      await http.post(Uri.parse(url), headers: {'Content-Type': 'application/json'}, body: jsonEncode(body));
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
      final now = DateFormat('yyyy/MM/dd HH:mm').format(DateTime.now());
      final shortMsg = message.length > 80 ? '${message.substring(0, 80)}...' : message;
      final subject = screenId != null
          ? '$now [Error:h1-core] $screenId: $shortMsg'
          : '$now [Error:h1-core] $shortMsg';
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
      if (url.isNotEmpty) {
        await http.post(
          Uri.parse(url),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'text': '🧪 **h-1-core ログ** ($_kAppVersion)\n$message'}),
        );
      }
    } catch (_) {}
    await _sendViaPat('🧪 **h-1-core ログ** ($_kAppVersion)\n$message');
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

  /// 任意のasync処理を実行し、エラー発生時にMattermostへ報告するラッパー
  static Future<T?> tryWithReport<T>({
    required String label,
    required Future<T?> Function() fn,
    String? screenId,
  }) async {
    try {
      return await fn();
    } catch (e, st) {
      sendError(message: '$label: $e', detail: e.toString(), screenId: screenId, stackTrace: st);
      return null;
    }
  }
}
