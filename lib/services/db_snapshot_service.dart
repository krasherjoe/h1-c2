import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'database_helper.dart';

class DbSnapshotService {
  static final _snapDir = 'snapshots';
  static const _maxSnapshots = 10;

  static Future<String?> snapshot() async {
    try {
      final db = await DatabaseHelper().database;
      final src = File(db.path);
      if (!await src.exists()) return null;
      final dir = Directory(p.join(p.dirname(db.path), _snapDir));
      await dir.create(recursive: true);
      final stamp = DateTime.now().toIso8601String().replaceAll(':', '-');
      final destPath = p.join(dir.path, 'snap_$stamp.db');
      await src.copy(destPath);
      await _cleanup(dir);
      debugPrint('[DbSnapshot] saved: $destPath');
      return destPath;
    } catch (e) {
      debugPrint('[DbSnapshot] failed: $e');
      return null;
    }
  }

  static Future<List<String>> list() async {
    try {
      final db = await DatabaseHelper().database;
      final dir = Directory(p.join(p.dirname(db.path), _snapDir));
      if (!await dir.exists()) return [];
      final files = (await dir.list().toList())
          .whereType<File>()
          .where((f) => f.path.endsWith('.db'))
          .map((f) => f.path)
          .toList();
      files.sort((a, b) => b.compareTo(a));
      return files;
    } catch (_) {
      return [];
    }
  }

  static Future<String> restore(int index) async {
    final snaps = await list();
    if (index < 0 || index >= snaps.length) return 'インデックス範囲外 (0〜${snaps.length - 1})';
    try {
      final db = await DatabaseHelper().database;
      final src = File(snaps[index]);
      final dest = File(db.path);
      await DatabaseHelper.closeAndReset();
      await src.copy(dest.path);
      debugPrint('[DbSnapshot] restored: ${snaps[index]}');
      return '復元完了: ${p.basename(snaps[index])}';
    } catch (e) {
      return '復元失敗: $e';
    }
  }

  static Future<String> restoreLatest() async {
    final snaps = await list();
    if (snaps.isEmpty) return 'スナップショットなし';
    return restore(0);
  }

  static Future<void> _cleanup(Directory dir) async {
    final files = (await dir.list().toList())
        .whereType<File>()
        .where((f) => f.path.endsWith('.db'))
        .toList();
    files.sort((a, b) => b.path.compareTo(a.path));
    for (var i = _maxSnapshots; i < files.length; i++) {
      await files[i].delete();
    }
  }
}
