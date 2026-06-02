import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import '../../../services/database_helper.dart';
import '../models/memorandum_model.dart';

class MemorandumRepository {
  final DatabaseHelper _db = DatabaseHelper();

  Future<List<Memorandum>> getAll({MemorandumStatus? status}) async {
    try {
      final database = await _db.database;
      final rows = status != null
          ? await database.query('memorandums', where: 'status = ?', whereArgs: [status.name], orderBy: 'created_at DESC')
          : await database.query('memorandums', orderBy: 'created_at DESC');
      return rows.map(Memorandum.fromMap).toList();
    } catch (e) {
      debugPrint('[MemorandumRepo] getAll error: $e');
      rethrow;
    }
  }

  Future<Memorandum?> getById(String id) async {
    try {
      final database = await _db.database;
      final rows = await database.query('memorandums', where: 'id = ?', whereArgs: [id]);
      if (rows.isEmpty) return null;
      return Memorandum.fromMap(rows.first);
    } catch (e) {
      debugPrint('[MemorandumRepo] getById error: $e');
      rethrow;
    }
  }

  Future<void> save(Memorandum memo) async {
    try {
      final database = await _db.database;
      await database.insert('memorandums', memo.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
    } catch (e) {
      debugPrint('[MemorandumRepo] save error: $e');
      rethrow;
    }
  }

  Future<void> delete(String id) async {
    try {
      final database = await _db.database;
      await database.delete('memorandums', where: 'id = ?', whereArgs: [id]);
    } catch (e) {
      debugPrint('[MemorandumRepo] delete error: $e');
      rethrow;
    }
  }

  Future<List<Memorandum>> getByProject(String projectId) async {
    try {
      final database = await _db.database;
      final rows = await database.query('memorandums',
          where: 'project_id = ?', whereArgs: [projectId],
          orderBy: 'created_at DESC');
      return rows.map((r) => Memorandum.fromMap(r)).toList();
    } catch (e) {
      debugPrint('[MemoRepo] getByProject error: $e');
      rethrow;
    }
  }

  Future<List<Memorandum>> search(String query) async {
    try {
      final database = await _db.database;
      final rows = await database.query(
        'memorandums',
        where: 'customer_name LIKE ? OR document_number LIKE ?',
        whereArgs: ['%$query%', '%$query%'],
        orderBy: 'created_at DESC',
      );
      return rows.map(Memorandum.fromMap).toList();
    } catch (e) {
      debugPrint('[MemorandumRepo] search error: $e');
      rethrow;
    }
  }
}
