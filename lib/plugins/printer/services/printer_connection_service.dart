import 'dart:io';
import 'package:path_provider/path_provider.dart';

class PrinterConnectionService {
  static final PrinterConnectionService instance = PrinterConnectionService._();
  PrinterConnectionService._();

  bool get isConnected => false;
  String? get connectedDeviceName => null;

  Future<String?> saveToFile(List<String> lines, {String title = 'receipt'}) async {
    try {
      final text = lines.join('\n');
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/${title}_${DateTime.now().millisecondsSinceEpoch}.txt');
      await file.writeAsString(text, flush: true);
      return file.path;
    } catch (_) {
      return null;
    }
  }

  Future<bool> printLines(List<String> lines, {String title = 'receipt'}) async {
    // ファイル保存のみ（Bluetooth・印刷はOS連携）
    final path = await saveToFile(lines, title: title);
    return path != null;
  }
}
