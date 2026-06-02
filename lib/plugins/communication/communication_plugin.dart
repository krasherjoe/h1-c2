import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_email_sender/flutter_email_sender.dart';
import 'package:path_provider/path_provider.dart';
import '../../utils/plugin_base.dart';

class CommunicationPlugin extends PluginBase {
  @override
  String get id => 'com.h1.plugin.communication';

  @override
  Future<void> register() async {}

  @override
  Future<void> unregister() async {}

  /// OSメールアプリを起動してPDFを添付送信
  Future<bool> sendEmailWithPdf({
    required Uint8List pdfBytes,
    required String filename,
    required String subject,
    String body = '',
    List<String> recipients = const [],
    List<String> cc = const [],
  }) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/$filename');
      await file.writeAsBytes(pdfBytes);

      final email = Email(
        body: body,
        subject: subject,
        recipients: recipients,
        cc: cc,
        attachmentPaths: [file.path],
        isHTML: false,
      );
      await FlutterEmailSender.send(email);
      return true;
    } catch (e) {
      debugPrint('[CommunicationPlugin] Email send error: $e');
      return false;
    }
  }
}
