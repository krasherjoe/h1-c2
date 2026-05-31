import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'database/database_schema_core.dart';

export 'database/database_utils.dart';
export 'database/database_schema_core.dart';

class DatabaseHelper {
  static const _databaseVersion = 1;
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

  String get databaseName => 'h1_core.db';

  Future<String> _getDatabaseDirectory() async {
    final dir = await getApplicationDocumentsDirectory();
    return dir.path;
  }

  Future<Database> _initDatabase() async {
    final dir = await _getDatabaseDirectory();
    final dbPath = p.join(dir, databaseName);
    debugPrint('[DB] データベースパス: $dbPath');
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
}
