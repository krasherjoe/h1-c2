import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

class MasterCsvExporter {
  static Future<void> export({
    required String entityName,
    required List<String> headers,
    required List<List<dynamic>> rows,
  }) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/${entityName}_${DateTime.now().millisecondsSinceEpoch}.csv');
      final buf = StringBuffer();
      buf.writeln(headers.map((h) => _escapeCsv(h)).join(','));
      for (final row in rows) {
        buf.writeln(row.map((cell) => _escapeCsv(cell?.toString() ?? '')).join(','));
      }
      await file.writeAsString(buf.toString());
      debugPrint('[CSV] Exported ${rows.length} rows to ${file.path}');
    } catch (e) {
      debugPrint('[CSV] Export error: $e');
    }
  }

  static String _escapeCsv(String value) {
    if (value.contains(',') || value.contains('"') || value.contains('\n')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }
}
