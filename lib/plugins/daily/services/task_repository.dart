import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import '../../../services/database_helper.dart';
import '../models/daily_models.dart';

class TaskRepository {
  final DatabaseHelper _db = DatabaseHelper();

  Future<List<Task>> getByProject(String projectId) async {
    try {
      final database = await _db.database;
      final rows = await database.query(
        'tasks',
        where: 'project_id = ?',
        whereArgs: [projectId],
        orderBy: 'sort_order ASC, created_at ASC',
      );
      return rows.map(Task.fromMap).toList();
    } catch (e) {
      debugPrint('[TaskRepo] getByProject error: $e');
      rethrow;
    }
  }

  Future<List<Task>> getByMilestone(String milestoneId) async {
    try {
      final database = await _db.database;
      final rows = await database.query(
        'tasks',
        where: 'milestone_id = ?',
        whereArgs: [milestoneId],
        orderBy: 'sort_order ASC, created_at ASC',
      );
      return rows.map(Task.fromMap).toList();
    } catch (e) {
      debugPrint('[TaskRepo] getByMilestone error: $e');
      rethrow;
    }
  }

  Future<void> save(Task task) async {
    try {
      final database = await _db.database;
      await database.insert(
        'tasks',
        task.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      debugPrint('[TaskRepo] save error: $e');
      rethrow;
    }
  }

  Future<void> delete(String id) async {
    try {
      final database = await _db.database;
      await database.delete('tasks', where: 'id = ?', whereArgs: [id]);
    } catch (e) {
      debugPrint('[TaskRepo] delete error: $e');
      rethrow;
    }
  }
}
