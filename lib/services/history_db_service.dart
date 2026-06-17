import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'company_service.dart';

class HistoryDbService {
  static final HistoryDbService _instance = HistoryDbService._internal();
  factory HistoryDbService() => _instance;
  HistoryDbService._internal();

  static Database? _historyDb;
  static bool _initialized = false;

  Future<Database> get database async {
    if (_historyDb != null) return _historyDb!;
    throw StateError('HistoryDbService not initialized');
  }

  static Future<void> initialize(Database mainDb) async {
    if (_initialized) return;
    _initialized = true;
    try {
      await mainDb.execute('''
        CREATE TABLE IF NOT EXISTS db_meta (
          key TEXT PRIMARY KEY,
          value TEXT NOT NULL
        )
      ''');
      final rows = await mainDb.query('db_meta',
          where: 'key = ?', whereArgs: ['management_id']);
      if (rows.isEmpty) {
        final id = Random().nextInt(256);
        await mainDb
            .insert('db_meta', {'key': 'management_id', 'value': id.toString()});
        debugPrint('[HistoryDB] 新management_id: $id');
      }

      _historyDb = await _openHistoryDb(mainDb);
      debugPrint('[HistoryDB] 初期化完了');
    } catch (e) {
      debugPrint('[HistoryDB] 初期化エラー: $e');
    }
  }

  static Future<Database> _openHistoryDb(Database mainDb) async {
    final dbPath = await CompanyService.getCurrentDbPath();
    final dir = p.dirname(dbPath);
    final historyPath = p.join(dir, 'history.db');

    final histDb = await openDatabase(
      historyPath,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS change_log (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            table_name TEXT NOT NULL,
            row_id TEXT NOT NULL,
            action TEXT NOT NULL,
            row_json TEXT NOT NULL,
            created_at TEXT NOT NULL,
            synced INTEGER DEFAULT 0
          )
        ''');
        await db.execute(
            'CREATE INDEX IF NOT EXISTS idx_cl_table_row ON change_log(table_name, row_id)');
        await db.execute(
            'CREATE INDEX IF NOT EXISTS idx_cl_created ON change_log(created_at)');
        await db.execute('''
          CREATE TABLE IF NOT EXISTS meta (
            key TEXT PRIMARY KEY,
            value TEXT NOT NULL
          )
        ''');
      },
    );

    // 初回作成時のみmanagement_idを記録（既存のhistory DBのIDは絶対に上書きしない）
    final histRows = await histDb.query('meta',
        where: 'key = ?', whereArgs: ['management_id']);
    if (histRows.isEmpty) {
      final prodRows = await mainDb.query('db_meta',
          where: 'key = ?', whereArgs: ['management_id']);
      final prodId =
          prodRows.isNotEmpty ? prodRows.first['value'] as String : '0';
      await histDb.insert('meta',
          {'key': 'management_id', 'value': prodId},
          conflictAlgorithm: ConflictAlgorithm.replace);
    }

    return histDb;
  }

  static Future<bool> verifyManagementId(Database mainDb) async {
    try {
      if (_historyDb == null) return false;
      final prodRows = await mainDb.query('db_meta',
          where: 'key = ?', whereArgs: ['management_id']);
      if (prodRows.isEmpty) return false;
      final prodId = prodRows.first['value'] as String;

      final histRows = await _historyDb!.query('meta',
          where: 'key = ?', whereArgs: ['management_id']);
      if (histRows.isEmpty) return false;
      final histId = histRows.first['value'] as String;
      return prodId == histId;
    } catch (e) {
      debugPrint('[HistoryDB] management_id確認エラー: $e');
      return false;
    }
  }

  Future<void> recordChange({
    required String tableName,
    required String rowId,
    required String action,
    required Map<String, dynamic> row,
  }) async {
    try {
      final db = await database;
      await db.insert('change_log', {
        'table_name': tableName,
        'row_id': rowId,
        'action': action,
        'row_json': jsonEncode(row),
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('[HistoryDB] recordChange error: $e');
    }
  }

  Future<Map<String, Map<String, dynamic>>> getLatestState(
      String tableName) async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT cl.* FROM change_log cl
      INNER JOIN (
        SELECT row_id, MAX(id) as max_id
        FROM change_log
        WHERE table_name = ?
        GROUP BY row_id
      ) latest ON cl.row_id = latest.row_id AND cl.id = latest.max_id
      WHERE cl.table_name = ?
    ''', [tableName, tableName]);

    final result = <String, Map<String, dynamic>>{};
    for (final row in rows) {
      final action = row['action'] as String;
      if (action == 'DELETE') continue;
      try {
        final rowId = row['row_id'] as String;
        result[rowId] =
            jsonDecode(row['row_json'] as String) as Map<String, dynamic>;
      } catch (_) {}
    }
    return result;
  }

  Future<int> repairDocumentsTable(Database mainDb) async {
    try {
      final match = await verifyManagementId(mainDb);
      if (!match) {
        debugPrint('[HistoryDB] management_id不一致、リペアスキップ');
        return 0;
      }

      final historyState = await getLatestState('documents');
      if (historyState.isEmpty) return 0;

      final existingRows =
          await mainDb.query('documents', columns: ['id', 'deleted_at']);
      final existingIds =
          existingRows.map((r) => r['id'] as String).toSet();

      int restored = 0;
      for (final entry in historyState.entries) {
        if (existingIds.contains(entry.key)) continue;
        final data = Map<String, dynamic>.from(entry.value);
        final itemsRaw = data.remove('_items') as List<dynamic>?;

        try {
          await mainDb.insert('documents', data,
              conflictAlgorithm: ConflictAlgorithm.ignore);
        } catch (e) {
          debugPrint('[HistoryDB] 復元失敗 id=${entry.key}: $e');
          continue;
        }

        if (itemsRaw != null) {
          for (final item in itemsRaw) {
            final itemMap = Map<String, dynamic>.from(item as Map);
            itemMap['document_id'] = entry.key;
            try {
              await mainDb.insert('document_items', itemMap,
                  conflictAlgorithm: ConflictAlgorithm.ignore);
            } catch (_) {}
          }
        }
        restored++;
      }
      if (restored > 0) {
        debugPrint('[HistoryDB] リペア完了: $restored件復元');
      }
      return restored;
    } catch (e) {
      debugPrint('[HistoryDB] repairDocumentsTable error: $e');
      return 0;
    }
  }

  Future<void> purgeOldEntries({int days = 30}) async {
    try {
      final db = await database;
      final cutoff =
          DateTime.now().subtract(Duration(days: days)).toIso8601String();
      final deleted = await db.delete('change_log',
          where: 'created_at < ?', whereArgs: [cutoff]);
      if (deleted > 0) {
        debugPrint('[HistoryDB] パージ完了: $deleted件削除');
      }
    } catch (e) {
      debugPrint('[HistoryDB] パージエラー: $e');
    }
  }

  static Future<void> closeAndReset() async {
    final db = _historyDb;
    _historyDb = null;
    _initialized = false;
    if (db != null && db.isOpen) {
      try {
        await db.close();
      } catch (_) {}
    }
  }
}
