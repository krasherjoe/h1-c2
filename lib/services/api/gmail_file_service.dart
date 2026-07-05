import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:googleapis/gmail/v1.dart' as gmail;
import 'package:mime/mime.dart';
import '../google_auth_service.dart';
import '../user_service.dart';

class GmailFileService {
  static final GmailFileService _instance = GmailFileService._internal();
  factory GmailFileService() => _instance;
  GmailFileService._internal();

  static const _fileLabel = 'Files-H1';
  String? _fileLabelId;
  static const _maxAttachmentSize = 25 * 1024 * 1024; // 25MB

  /// ファイルを送信
  Future<bool> sendFile({
    required String toEmail,
    required File file,
    String? message,
    String? entityType,
    String? entityId,
  }) async {
    try {
      final client = await GoogleAuthService.instance.getAuthenticatedClient();
      if (client == null) return false;

      final gmailApi = gmail.GmailApi(client);
      final currentUser = UserService().currentUser;
      if (currentUser == null) return false;

      // ファイルサイズチェック
      final fileSize = await file.length();
      if (fileSize > _maxAttachmentSize) {
        _log('ファイルサイズが制限を超えています: $fileSize bytes');
        return false;
      }

      final fileName = file.path.split('/').last;
      final mimeType = lookupMimeType(file.path) ?? 'application/octet-stream';
      final fileBytes = await file.readAsBytes();

      // MIMEメッセージを構築
      final boundary = 'boundary_${DateTime.now().millisecondsSinceEpoch}';
      final fromEmail = currentUser.email;

      final metadata = {
        'to': toEmail,
        'from': fromEmail,
        'subject': '[File:${entityType ?? "general"}] $fileName',
      };

      final body = StringBuffer();
      // メタデータヘッダー
      for (final entry in metadata.entries) {
        body.writeln('${entry.key}: ${entry.value}');
      }
      body.writeln('Content-Type: multipart/mixed; boundary="$boundary"');
      body.writeln();
      body.writeln('--$boundary');

      // テキストパート
      if (message != null && message.isNotEmpty) {
        body.writeln('Content-Type: text/plain; charset=utf-8');
        body.writeln();
        body.writeln(message);
        body.writeln('--$boundary');
      }

      // ファイルパート（ヘッダーのみ、ボディはバイナリ）
      body.writeln('Content-Type: $mimeType; name="$fileName"');
      body.writeln('Content-Disposition: attachment; filename="$fileName"');
      body.writeln('Content-Transfer-Encoding: base64');
      body.writeln();

      // メッセージ全体を構築
      final fullMessage = '${body.toString()}${base64Encode(fileBytes)}\r\n--$boundary--';

      final messageObj = gmail.Message();
      messageObj.raw = base64Url.encode(utf8.encode(fullMessage));

      await gmailApi.users.messages.send(messageObj, 'me');
      _log('ファイル送信完了: $fileName -> $toEmail');
      return true;
    } catch (e) {
      _log('ファイル送信失敗: $e');
      return false;
    }
  }

  /// 添付ファイルを受信
  Future<List<ReceivedFile>> getFiles({
    String? entityType,
    DateTime? since,
    int maxResults = 20,
  }) async {
    try {
      final client = await GoogleAuthService.instance.getAuthenticatedClient();
      if (client == null) return [];

      final gmailApi = gmail.GmailApi(client);
      final labelId = await _getFileLabelId(gmailApi);
      if (labelId == null) return [];

      // クエリを構築
      final queryParts = <String>['label:$labelId', 'has:attachment'];
      if (since != null) {
        final dateStr = '${since.year}/${since.month}/${since.day}';
        queryParts.add('after:$dateStr');
      }
      if (entityType != null) {
        queryParts.add('subject:[File:$entityType]');
      }

      final listResponse = await gmailApi.users.messages.list(
        'me',
        q: queryParts.join(' '),
        maxResults: maxResults,
      );

      if (listResponse.messages == null) return [];

      final files = <ReceivedFile>[];
      for (final msgRef in listResponse.messages!) {
        if (msgRef.id == null) continue;
        final msg = await gmailApi.users.messages.get('me', msgRef.id!);
        final receivedFiles = _parseAttachments(msg);
        files.addAll(receivedFiles);
      }

      return files;
    } catch (e) {
      _log('ファイル受信失敗: $e');
      return [];
    }
  }

  /// 添付ファイルをダウンロード
  Future<List<int>?> downloadAttachment(String messageId, String attachmentId) async {
    try {
      final client = await GoogleAuthService.instance.getAuthenticatedClient();
      if (client == null) return null;

      final gmailApi = gmail.GmailApi(client);
      final attachment = await gmailApi.users.messages.attachments.get(
        'me',
        messageId,
        attachmentId,
      );

      if (attachment.data != null) {
        return base64Url.decode(attachment.data!);
      }
      return null;
    } catch (e) {
      _log('ダウンロード失敗: $e');
      return null;
    }
  }

  /// ファイルラベルIDを取得
  Future<String?> _getFileLabelId(gmail.GmailApi gmailApi) async {
    if (_fileLabelId != null) return _fileLabelId;

    try {
      final labels = await gmailApi.users.labels.list('me');
      for (final label in labels.labels ?? []) {
        if (label.name == _fileLabel) {
          _fileLabelId = label.id;
          return _fileLabelId;
        }
      }

      // ラベルがなければ作成
      final newLabel = gmail.Label()
        ..name = _fileLabel
        ..labelListVisibility = 'labelShow'
        ..messageListVisibility = 'show';

      final created = await gmailApi.users.labels.create(newLabel, 'me');
      _fileLabelId = created.id;
      return _fileLabelId;
    } catch (e) {
      _log('ラベル取得失敗: $e');
      return null;
    }
  }

  /// Gmailメッセージから添付ファイルを解析
  List<ReceivedFile> _parseAttachments(gmail.Message msg) {
    final files = <ReceivedFile>[];
    final payload = msg.payload;
    if (payload == null) return files;

    _extractAttachments(payload, files, msg.id ?? '', msg.internalDate);

    return files;
  }

  void _extractAttachments(
    gmail.MessagePart part,
    List<ReceivedFile> files,
    String messageId,
    String? internalDate,
  ) {
    if (part.filename != null && part.filename!.isNotEmpty) {
      files.add(ReceivedFile(
        messageId: messageId,
        filename: part.filename!,
        mimeType: part.mimeType ?? 'application/octet-stream',
        attachmentId: part.body?.attachmentId,
        size: part.body?.size ?? 0,
        timestamp: internalDate != null
            ? DateTime.fromMillisecondsSinceEpoch(int.parse(internalDate))
            : DateTime.now(),
      ));
    }

    // パートを再帰的に処理
    if (part.parts != null) {
      for (final subPart in part.parts!) {
        _extractAttachments(subPart, files, messageId, internalDate);
      }
    }
  }

  void _log(String msg) {
    debugPrint('[GmailFile] $msg');
  }
}

class ReceivedFile {
  final String messageId;
  final String filename;
  final String mimeType;
  final String? attachmentId;
  final int size;
  final DateTime timestamp;

  const ReceivedFile({
    required this.messageId,
    required this.filename,
    required this.mimeType,
    this.attachmentId,
    this.size = 0,
    required this.timestamp,
  });
}
