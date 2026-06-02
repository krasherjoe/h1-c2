import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import '../../../services/database_helper.dart';
import '../models/daily_models.dart';

class TodoRepository {
  final DatabaseHelper _db = DatabaseHelper();

  Future<List<TodoTask>> getAll({String? status}) async {
    try {
      final database = await _db.database;
      final rows = status != null
          ? await database.query(
              'todo_tasks',
              where: 'status = ?',
              whereArgs: [status],
              orderBy: 'due_date ASC, created_at DESC',
            )
          : await database.query('todo_tasks', orderBy: 'due_date ASC, created_at DESC');
      return rows.map(TodoTask.fromMap).toList();
    } catch (e) {
      debugPrint('[TodoRepo] getAll error: $e');
      rethrow;
    }
  }

  Future<int> getPendingCount() async {
    try {
      final database = await _db.database;
      final result = await database.rawQuery(
          "SELECT COUNT(*) as c FROM todo_tasks WHERE status = 'pending'");
      return result.first['c'] as int? ?? 0;
    } catch (e) {
      debugPrint('[TodoRepo] getPendingCount error: $e');
      rethrow;
    }
  }

  Future<void> save(TodoTask todo) async {
    try {
      final database = await _db.database;
      await database.insert(
        'todo_tasks',
        todo.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      debugPrint('[TodoRepo] save error: $e');
      rethrow;
    }
  }

  Future<void> markDone(String id) async {
    try {
      final database = await _db.database;
      await database.update(
        'todo_tasks',
        {'status': 'done'},
        where: 'id = ?',
        whereArgs: [id],
      );
    } catch (e) {
      debugPrint('[TodoRepo] markDone error: $e');
      rethrow;
    }
  }

  Future<void> delete(String id) async {
    try {
      final database = await _db.database;
      await database.delete('todo_tasks', where: 'id = ?', whereArgs: [id]);
    } catch (e) {
      debugPrint('[TodoRepo] delete error: $e');
      rethrow;
    }
  }

  Future<List<TodoTask>> getByReference(String referenceId, String referenceType) async {
    try {
      final database = await _db.database;
      final rows = await database.query(
        'todo_tasks',
        where: 'reference_id = ? AND reference_type = ?',
        whereArgs: [referenceId, referenceType],
        orderBy: 'created_at DESC',
      );
      return rows.map(TodoTask.fromMap).toList();
    } catch (e) {
      debugPrint('[TodoRepo] getByReference error: $e');
      rethrow;
    }
  }
}
