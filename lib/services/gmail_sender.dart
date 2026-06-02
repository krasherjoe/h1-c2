import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:googleapis/gmail/v1.dart' as gmail;
import 'package:http/http.dart' as http;
import 'google_auth_service.dart';
import 'error_reporter.dart';

class GmailSender {
  static const _userId = 'me';

  static Future<bool> sendPdf({
    required String to,
    required String subject,
    required String body,
    required Uint8List pdfBytes,
    required String pdfFilename,
  }) async {
    try {
      final client = await GoogleAuthService.instance.getAuthenticatedClient();
      if (client == null) {
        debugPrint('[GmailSender] No auth client available');
        return false;
      }

      final api = gmail.GmailApi(client);
      
      final boundary = 'boundary${DateTime.now().millisecondsSinceEpoch}';
      final header = 'Content-Type: multipart/mixed; boundary=$boundary\n'
          'MIME-Version: 1.0\n'
          'To: $to\n'
          'Subject: $subject\n\n'
          '--$boundary\n'
          'Content-Type: text/plain; charset=UTF-8\n\n'
          '$body\n\n'
          '--$boundary\n'
          'Content-Type: application/pdf\n'
          'Content-Disposition: attachment; filename="$pdfFilename"\n'
          'Content-Transfer-Encoding: base64\n\n'
          '${base64Encode(pdfBytes)}\n'
          '--$boundary--';

      final encodedMessage = base64UrlEncode(utf8.encode(header));
      
      await api.users.messages.send(
        gmail.Message(raw: encodedMessage),
        _userId,
      );
      
      client.close();
      return true;
    } catch (e, st) {
      ErrorReporter.sendError(message: 'Gmail送信失敗: $e', stackTrace: st);
      debugPrint('[GmailSender] Error: $e');
      return false;
    }
  }
}
