import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:googleapis/gmail/v1.dart' as gmail;
import '../google_auth_service.dart';
import '../user_service.dart';

class ChatMessage {
  final String id;
  final String senderEmail;
  final String senderName;
  final String content;
  final DateTime timestamp;
  final bool isRead;
  final String? channelId;

  const ChatMessage({
    required this.id,
    required this.senderEmail,
    required this.senderName,
    required this.content,
    required this.timestamp,
    this.isRead = false,
    this.channelId,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'senderEmail': senderEmail,
    'senderName': senderName,
    'content': content,
    'timestamp': timestamp.toIso8601String(),
    'isRead': isRead,
    'channelId': channelId,
  };

  factory ChatMessage.fromMap(Map<String, dynamic> map) => ChatMessage(
    id: map['id'] as String,
    senderEmail: map['senderEmail'] as String,
    senderName: map['senderName'] as String,
    content: map['content'] as String,
    timestamp: DateTime.parse(map['timestamp'] as String),
    isRead: map['isRead'] as bool? ?? false,
    channelId: map['channelId'] as String?,
  );
}

class GmailChatService {
  static final GmailChatService _instance = GmailChatService._internal();
  factory GmailChatService() => _instance;
  GmailChatService._internal();

  static const _chatLabel = 'Chat-H1';
  String? _chatLabelId;

  /// チャットメッセージを送信
  Future<bool> sendMessage({
    required String toEmail,
    required String content,
    String? channelId,
  }) async {
    try {
      final client = await GoogleAuthService.instance.getAuthenticatedClient();
      if (client == null) return false;

      final gmailApi = gmail.GmailApi(client);
      final currentUser = UserService().currentUser;
      if (currentUser == null) return false;

      final message = gmail.Message();
      final fromEmail = currentUser.email;

      final subject = channelId != null ? '[Chat:$channelId]' : '[Chat]';
      final body = jsonEncode({
        'content': content,
        'channelId': channelId,
        'senderName': currentUser.displayName ?? fromEmail,
        'timestamp': DateTime.now().toIso8601String(),
      });

      final rawMessage = 'From: $fromEmail\r\n'
          'To: $toEmail\r\n'
          'Subject: $subject\r\n'
          'Content-Type: text/plain; charset=utf-8\r\n'
          '\r\n'
          '$body';

      message.raw = base64Url.encode(utf8.encode(rawMessage));

      await gmailApi.users.messages.send(message, 'me');
      _log('メッセージ送信完了: $toEmail');
      return true;
    } catch (e) {
      _log('メッセージ送信失敗: $e');
      return false;
    }
  }

  /// チャットメッセージを受信
  Future<List<ChatMessage>> getMessages({
    String? channelId,
    DateTime? since,
    int maxResults = 50,
  }) async {
    try {
      final client = await GoogleAuthService.instance.getAuthenticatedClient();
      if (client == null) return [];

      final gmailApi = gmail.GmailApi(client);

      // チャットラベルを取得
      final labelId = await _getChatLabelId(gmailApi);
      if (labelId == null) return [];

      // クエリを構築
      final queryParts = <String>['label:$labelId'];
      if (since != null) {
        final dateStr = '${since.year}/${since.month}/${since.day}';
        queryParts.add('after:$dateStr');
      }
      if (channelId != null) {
        queryParts.add('subject:[Chat:$channelId]');
      }

      final listResponse = await gmailApi.users.messages.list(
        'me',
        q: queryParts.join(' '),
        maxResults: maxResults,
      );

      if (listResponse.messages == null) return [];

      final messages = <ChatMessage>[];
      for (final msgRef in listResponse.messages!) {
        if (msgRef.id == null) continue;
        final msg = await gmailApi.users.messages.get('me', msgRef.id!);
        final chatMsg = _parseMessage(msg);
        if (chatMsg != null) messages.add(chatMsg);
      }

      return messages;
    } catch (e) {
      _log('メッセージ受信失敗: $e');
      return [];
    }
  }

  /// メッセージを既読にする
  Future<void> markAsRead(String messageId) async {
    // Gmail APIでは既読フラグの直接操作は複雑
    // 必要に応じて実装
  }

  /// チャットラベルIDを取得
  Future<String?> _getChatLabelId(gmail.GmailApi gmailApi) async {
    if (_chatLabelId != null) return _chatLabelId;

    try {
      final labels = await gmailApi.users.labels.list('me');
      for (final label in labels.labels ?? []) {
        if (label.name == _chatLabel) {
          _chatLabelId = label.id;
          return _chatLabelId;
        }
      }

      // ラベルがなければ作成
      final newLabel = gmail.Label()
        ..name = _chatLabel
        ..labelListVisibility = 'labelHide'
        ..messageListVisibility = 'hide';

      final created = await gmailApi.users.labels.create(newLabel, 'me');
      _chatLabelId = created.id;
      return _chatLabelId;
    } catch (e) {
      _log('ラベル取得失敗: $e');
      return null;
    }
  }

  /// GmailメッセージをChatMessageに変換
  ChatMessage? _parseMessage(gmail.Message msg) {
    try {
      final payload = msg.payload;
      if (payload == null) return null;

      // ボディを取得
      String? body;
      if (payload.body?.data != null) {
        body = utf8.decode(base64Url.decode(payload.body!.data!));
      }

      if (body == null || body.isEmpty) return null;

      // JSONとしてパース
      final data = jsonDecode(body) as Map<String, dynamic>;

      return ChatMessage(
        id: msg.id ?? '',
        senderEmail: payload.headers
            ?.firstWhere((h) => h.name == 'From', orElse: () => gmail.MessagePartHeader()..value = '')
            .value ?? '',
        senderName: data['senderName'] as String? ?? '',
        content: data['content'] as String? ?? '',
        timestamp: DateTime.parse(data['timestamp'] as String),
        isRead: msg.labelIds?.contains('UNREAD') != true,
        channelId: data['channelId'] as String?,
      );
    } catch (e) {
      _log('メッセージパース失敗: $e');
      return null;
    }
  }

  void _log(String msg) {
    debugPrint('[GmailChat] $msg');
  }
}
