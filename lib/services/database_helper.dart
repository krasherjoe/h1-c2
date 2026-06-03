import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;

import 'company_service.dart';
import 'database/database_schema_core.dart';

export 'database/database_utils.dart';
export 'database/database_schema_core.dart';

class DatabaseHelper {
  static const _databaseVersion = 5;
  static int get databaseVersion => _databaseVersion;
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;
  static Future<Database>? _databaseFuture;
  static Database? testDatabase;

  factory DatabaseHelper() => _instance;

  DatabaseHelper._internal();

  Future<Database> get database async {
    if (testDatabase != null) return testDatabase!;
    if (kIsWeb) {
      throw UnsupportedError('WebではDatabaseは使用できません');
    }
    if (_database != null) return _database!;
    _databaseFuture ??= _initDatabase();
    _database = await _databaseFuture!;
    return _database!;
  }

  static Future<Database> createFreshDatabase(String dbPath) async {
    return openDatabase(
      dbPath,
      version: _databaseVersion,
      onCreate: createAllTables,
      onUpgrade: upgradeDatabase,
    );
  }

  static Future<void> closeAndReset() async {
    final db = _database;
    _database = null;
    _databaseFuture = null;
    if (db != null && db.isOpen) {
      try {
        await db.close();
      } catch (e) {
        debugPrint('[DBHelper] close error: $e');
      }
    }
  }

  Future<String> getDatabasePath() async {
    return CompanyService.getCurrentDbPath();
  }

  Future<String> _getDatabaseDirectory() async {
    final dir = await CompanyService.getCompanyDirectory();
    return dir.path;
  }

  /// 旧DBパス（外部ストレージ時代）から新DBパスへ移行
  static Future<void> _migrateFromOldPath(String newDbPath) async {
    try {
      if (await File(newDbPath).exists()) return; // 既に新DBがある
      final oldDir = Directory('/storage/emulated/0/Documents/販売アシスト1号code');
      if (!await oldDir.exists()) return; // 旧DB自体が無い
      final name = p.basenameWithoutExtension(newDbPath);
      final oldFile = File(p.join(oldDir.path, '$name.db'));
      if (!await oldFile.exists()) return; // 旧DBファイルが無い
      await File(newDbPath).parent.create(recursive: true);
      await oldFile.copy(newDbPath);
      debugPrint('[DB] 旧DBから移行完了: $oldFile → $newDbPath');
    } catch (e) {
      debugPrint('[DB] 旧DB移行失敗: $e');
    }
  }

  Future<Database> _initDatabase() async {
    final dbPath = await CompanyService.getCurrentDbPath();
    debugPrint('[DB] データベースパス: $dbPath');
    await _migrateFromOldPath(dbPath);
    final dir = Directory(p.dirname(dbPath));
    if (!await dir.exists()) await dir.create(recursive: true);
    return openDatabase(
      dbPath,
      version: _databaseVersion,
      onCreate: createAllTables,
      onUpgrade: upgradeDatabase,
    );
  }
}

Future<void> createAllTables(Database db, int version) async {
  await createCoreSchema(db);
}

Future<void> upgradeDatabase(Database db, int oldVersion, int newVersion) async {
  for (var v = oldVersion + 1; v <= newVersion; v++) {
    await _migrateToVersion(db, v);
  }
}

Future<void> _migrateToVersion(Database db, int version) async {
  switch (version) {
    case 2:
      break;
    case 3:
      try {
        await db.execute('ALTER TABLE projects ADD COLUMN contract_months INTEGER');
      } catch (_) {}
      break;
    case 4:
      await db.execute('''
        CREATE TABLE IF NOT EXISTS sync_log (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          entity_type TEXT NOT NULL,
          entity_id TEXT NOT NULL,
          action TEXT NOT NULL,
          data TEXT NOT NULL,
          device_id TEXT NOT NULL,
          parent_id TEXT,
          synced_at TEXT,
          created_at TEXT NOT NULL
        )
      ''');
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_sync_log_entity ON sync_log(entity_type, entity_id)',
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_sync_log_unsent ON sync_log(synced_at) WHERE synced_at IS NULL',
      );
      break;
    case 5:
      try {
        await db.execute('ALTER TABLE company_info ADD COLUMN closing_day INTEGER DEFAULT 20');
      } catch (_) {}
      break;
    default:
      break;
  }
}
