import 'dart:convert';
import '../../../../services/database_helper.dart';
import '../models/audit_log.dart';

class AuditLogService {
  final _db = DatabaseHelper();

  Future<void> log({
    required String tableName,
    required String recordId,
    required String action,
    Map<String, dynamic>? oldValues,
    Map<String, dynamic>? newValues,
  }) async {
    final db = await _db.database;
    await db.insert('audit_logs', AuditLog(
      tableName: tableName,
      recordId: recordId,
      action: action,
      oldValues: oldValues != null ? jsonEncode(oldValues) : null,
      newValues: newValues != null ? jsonEncode(newValues) : null,
      createdAt: DateTime.now(),
    ).toMap());
  }

  Future<List<AuditLog>> fetchAll({int limit = 100}) async {
    final db = await _db.database;
    final maps = await db.query('audit_logs', orderBy: 'created_at DESC', limit: limit);
    return maps.map(AuditLog.fromMap).toList();
  }

  Future<List<AuditLog>> fetchByTable(String tableName, {int limit = 50}) async {
    final db = await _db.database;
    final maps = await db.query('audit_logs',
      where: 'table_name = ?', whereArgs: [tableName],
      orderBy: 'created_at DESC', limit: limit);
    return maps.map(AuditLog.fromMap).toList();
  }
}
