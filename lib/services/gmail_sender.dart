import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:googleapis/gmail/v1.dart' as gmail;
import 'package:http/http.dart' as http;
import 'google_auth_service.dart';
import 'error_reporter.dart';
import 'sync_service.dart';

class GmailSender {
  static const _userId = 'me';

  static Future<bool> sendPdf({
    required String to,
    String? bcc,
    String? replyTo,
    required String subject,
    required String body,
    required Uint8List pdfBytes,
    required String pdfFilename,
  }) async {
    return sendPdfs(
      to: to,
      bcc: bcc,
      replyTo: replyTo,
      subject: subject,
      body: body,
      attachments: [
        {'filename': pdfFilename, 'bytes': pdfBytes},
      ],
    );
  }

  static Future<bool> sendPdfs({
    required String to,
    String? bcc,
    String? replyTo,
    required String subject,
    required String body,
    required List<Map<String, dynamic>> attachments,
  }) async {
    try {
      final client = await GoogleAuthService.instance.getAuthenticatedClient();
      if (client == null) {
        debugPrint('[GmailSender] No auth client available');
        return false;
      }

      final api = gmail.GmailApi(client);
      
      final boundary = 'boundary${DateTime.now().millisecondsSinceEpoch}';
      String header = 'Content-Type: multipart/mixed; boundary=$boundary\n'
          'MIME-Version: 1.0\n'
          'To: $to\n';
      if (bcc != null && bcc.isNotEmpty) {
        header += 'Bcc: $bcc\n';
      }
      if (replyTo != null && replyTo.isNotEmpty) {
        header += 'Reply-To: $replyTo\n';
      }
      final encodedSubject = '=?UTF-8?B?${base64Encode(utf8.encode(subject))}?=';
      header += 'Subject: $encodedSubject\n\n'
          '--$boundary\n'
          'Content-Type: text/plain; charset=UTF-8\n\n'
          '$body\n\n';

      // 添付ファイルを追加
      for (final attachment in attachments) {
        final filename = attachment['filename'] as String;
        final bytes = attachment['bytes'] as Uint8List;
        header += '--$boundary\n'
            'Content-Type: application/pdf\n'
            'Content-Disposition: attachment; filename="$filename"\n'
            'Content-Transfer-Encoding: base64\n\n'
            '${base64Encode(bytes)}\n\n';
      }

      header += '--$boundary--';

      final encodedMessage = base64UrlEncode(utf8.encode(header));
      
      final sent = await api.users.messages.send(
        gmail.Message(raw: encodedMessage),
        _userId,
      );
      
      if (sent.id != null) {
        SyncService.labelSentPdf(sent.id!);
      }
      
      client.close();
      return true;
    } catch (e, st) {
      ErrorReporter.sendError(message: 'Gmail送信失敗: $e', stackTrace: st);
      debugPrint('[GmailSender] Error: $e');
      return false;
    }
  }
}
