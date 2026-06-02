import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import '../../../services/database_helper.dart';
import '../models/daily_models.dart';

class DailyReportRepository {
  final DatabaseHelper _db = DatabaseHelper();

  Future<List<DailyReport>> getByMonth(int year, int month) async {
    try {
      final database = await _db.database;
      final start = '$year-${month.toString().padLeft(2, '0')}-01';
      final end = month == 12
          ? '${year + 1}-01-01'
          : '$year-${(month + 1).toString().padLeft(2, '0')}-01';
      final maps = await database.query(
        'daily_reports',
        where: 'report_date >= ? AND report_date < ?',
        whereArgs: [start, end],
        orderBy: 'report_date DESC, created_at DESC',
      );
      return maps.map((m) => DailyReport.fromMap(m)).toList();
    } catch (e) {
      debugPrint('[DailyReportRepo] getByMonth error: $e');
      rethrow;
    }
  }

  Future<List<DailyReport>> getByProject(String projectId) async {
    try {
      final database = await _db.database;
      final maps = await database.query(
        'daily_reports',
        where: 'project_id = ?',
        whereArgs: [projectId],
        orderBy: 'report_date DESC',
      );
      return maps.map((m) => DailyReport.fromMap(m)).toList();
    } catch (e) {
      debugPrint('[DailyReportRepo] getByProject error: $e');
      rethrow;
    }
  }

  Future<List<String>> getAllTags() async {
    try {
      final database = await _db.database;
      final maps = await database.rawQuery(
          "SELECT DISTINCT tags FROM daily_reports WHERE tags IS NOT NULL AND tags != ''");
      final allTags = <String>{};
      for (final m in maps) {
        final t = m['tags'] as String?;
        if (t != null) {
          for (final tag in t.split(',')) {
            final trimmed = tag.trim();
            if (trimmed.isNotEmpty) allTags.add(trimmed);
          }
        }
      }
      return allTags.toList()..sort();
    } catch (e) {
      debugPrint('[DailyReportRepo] getAllTags error: $e');
      rethrow;
    }
  }

  Future<void> save(DailyReport report) async {
    try {
      final database = await _db.database;
      await database.insert(
        'daily_reports',
        report.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      debugPrint('[DailyReportRepo] save error: $e');
      rethrow;
    }
  }

  Future<void> delete(String id) async {
    try {
      final database = await _db.database;
      await database.delete('daily_reports', where: 'id = ?', whereArgs: [id]);
    } catch (e) {
      debugPrint('[DailyReportRepo] delete error: $e');
      rethrow;
    }
  }
}
