import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';

Future<void> safeAddColumn(
  Database db,
  String table,
  String columnDef,
) async {
  try {
    final columnName = columnDef.split(' ').first;
    final columns = await db.rawQuery('PRAGMA table_info($table)');
    final exists = columns.any((col) => col['name'] == columnName);
    if (exists) {
      debugPrint(
        'safeAddColumn: カラム $columnName は $table に既に存在します - スキップ',
      );
      return;
    }
    await db.execute('ALTER TABLE $table ADD COLUMN $columnDef');
  } catch (e) {
    debugPrint('safeAddColumn エラー ($table, $columnDef): $e');
  }
}

Future<void> safeExecute(Database db, String sql) async {
  try {
    await db.execute(sql);
  } catch (e) {
    debugPrint('safeExecute: $sql -> $e');
    if (!e.toString().contains('already exists') &&
        !e.toString().contains('duplicate') &&
        !e.toString().contains('no such table')) {
      rethrow;
    }
  }
}

Future<bool> tableExists(Database db, String tableName) async {
  try {
    final result = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
      [tableName],
    );
    return result.isNotEmpty;
  } catch (e) {
    debugPrint('tableExists エラー ($tableName): $e');
    return false;
  }
}

Future<List<String>> getColumnNames(Database db, String table) async {
  final columns = await db.rawQuery('PRAGMA table_info($table)');
  return columns.map((col) => col['name'] as String).toList();
}
