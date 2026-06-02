import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import '../../../services/database_helper.dart';
import '../models/daily_models.dart';

class TimeLogRepository {
  final DatabaseHelper _db = DatabaseHelper();

  Future<List<TimeLog>> getByProject(String projectId) async {
    try {
      final database = await _db.database;
      final rows = await database.query(
        'time_logs',
        where: 'project_id = ?',
        whereArgs: [projectId],
        orderBy: 'date DESC',
      );
      return rows.map(TimeLog.fromMap).toList();
    } catch (e) {
      debugPrint('[TimeLogRepo] getByProject error: $e');
      rethrow;
    }
  }

  Future<List<TimeLog>> getByTask(String taskId) async {
    try {
      final database = await _db.database;
      final rows = await database.query(
        'time_logs',
        where: 'task_id = ?',
        whereArgs: [taskId],
        orderBy: 'date DESC',
      );
      return rows.map(TimeLog.fromMap).toList();
    } catch (e) {
      debugPrint('[TimeLogRepo] getByTask error: $e');
      rethrow;
    }
  }

  Future<List<TimeLog>> getAll({DateTime? from, DateTime? to}) async {
    try {
      final database = await _db.database;
      String? where;
      List<dynamic>? whereArgs;
      if (from != null && to != null) {
        where = 'date >= ? AND date < ?';
        whereArgs = [from.toIso8601String(), to.toIso8601String()];
      } else if (from != null) {
        where = 'date >= ?';
        whereArgs = [from.toIso8601String()];
      } else if (to != null) {
        where = 'date < ?';
        whereArgs = [to.toIso8601String()];
      }
      final rows = await database.query(
        'time_logs',
        where: where,
        whereArgs: whereArgs,
        orderBy: 'date DESC, created_at DESC',
      );
      return rows.map(TimeLog.fromMap).toList();
    } catch (e) {
      debugPrint('[TimeLogRepo] getAll error: $e');
      rethrow;
    }
  }

  Future<void> save(TimeLog log) async {
    try {
      final database = await _db.database;
      await database.insert(
        'time_logs',
        log.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      debugPrint('[TimeLogRepo] save error: $e');
      rethrow;
    }
  }

  Future<void> delete(String id) async {
    try {
      final database = await _db.database;
      await database.delete('time_logs', where: 'id = ?', whereArgs: [id]);
    } catch (e) {
      debugPrint('[TimeLogRepo] delete error: $e');
      rethrow;
    }
  }

  Future<double> getTotalHoursByProject(String projectId) async {
    try {
      final database = await _db.database;
      final result = await database.rawQuery(
        'SELECT COALESCE(SUM(hours), 0) as total FROM time_logs WHERE project_id = ?',
        [projectId],
      );
      return (result.first['total'] as num?)?.toDouble() ?? 0;
    } catch (e) {
      debugPrint('[TimeLogRepo] getTotalHoursByProject error: $e');
      rethrow;
    }
  }
}
