import 'dart:convert';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:uuid/uuid.dart';
import 'package:sqflite/sqflite.dart';
import 'database_helper.dart';

enum BackupOperationType { create, restore, list }
enum BackupType { local, drive }
enum BackupStatus { pending, inProgress, completed, failed }

class BackupOperation {
  final String id;
  final BackupOperationType operationType;
  final BackupType backupType;
  final BackupStatus status;
  final String? filePath;
  final int? fileSize;
  final String? startedAt;
  final String? completedAt;
  final String? errorMessage;
  final Map<String, dynamic>? metadata;
  final String createdAt;

  BackupOperation({
    required this.id,
    required this.operationType,
    required this.backupType,
    required this.status,
    this.filePath,
    this.fileSize,
    this.startedAt,
    this.completedAt,
    this.errorMessage,
    this.metadata,
    required this.createdAt,
  });

  factory BackupOperation.fromMap(Map<String, dynamic> map) {
    return BackupOperation(
      id: map['id'] as String,
      operationType: BackupOperationType.values.firstWhere(
        (e) => e.name == map['operation_type'],
        orElse: () => BackupOperationType.create,
      ),
      backupType: BackupType.values.firstWhere(
        (e) => e.name == map['backup_type'],
        orElse: () => BackupType.local,
      ),
      status: BackupStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => BackupStatus.pending,
      ),
      filePath: map['file_path'] as String?,
      fileSize: map['file_size'] as int?,
      startedAt: map['started_at'] as String?,
      completedAt: map['completed_at'] as String?,
      errorMessage: map['error_message'] as String?,
      metadata: map['metadata'] != null
          ? jsonDecode(map['metadata'] as String) as Map<String, dynamic>
          : null,
      createdAt: map['created_at'] as String,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'operation_type': operationType.name,
      'backup_type': backupType.name,
      'status': status.name,
      'file_path': filePath,
      'file_size': fileSize,
      'started_at': startedAt,
      'completed_at': completedAt,
      'error_message': errorMessage,
      'metadata': metadata != null ? jsonEncode(metadata) : null,
      'created_at': createdAt,
    };
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'operationType': operationType.name,
      'backupType': backupType.name,
      'status': status.name,
      'filePath': filePath,
      'fileSize': fileSize,
      'startedAt': startedAt,
      'completedAt': completedAt,
      'errorMessage': errorMessage,
      'metadata': metadata,
      'createdAt': createdAt,
    };
  }
}

class BackupOperationService {
  static final BackupOperationService _instance = BackupOperationService._internal();
  factory BackupOperationService() => _instance;
  BackupOperationService._internal();

  final DatabaseHelper _dbHelper = DatabaseHelper();
  final Uuid _uuid = const Uuid();

  Future<String> createOperation({
    required BackupOperationType operationType,
    required BackupType backupType,
    Map<String, dynamic>? metadata,
  }) async {
    final id = _uuid.v4();
    final now = DateTime.now().toIso8601String();
    final operation = BackupOperation(
      id: id,
      operationType: operationType,
      backupType: backupType,
      status: BackupStatus.pending,
      createdAt: now,
      metadata: metadata,
    );

    final db = await _dbHelper.database;
    await db.insert('backup_operations', operation.toMap());
    debugPrint('[BackupOperationService] Created operation: $id');
    return id;
  }

  Future<void> updateStatus(String id, BackupStatus status, {String? errorMessage}) async {
    final db = await _dbHelper.database;
    final updates = <String, dynamic>{
      'status': status.name,
    };
    if (status == BackupStatus.inProgress) {
      updates['started_at'] = DateTime.now().toIso8601String();
    } else if (status == BackupStatus.completed || status == BackupStatus.failed) {
      updates['completed_at'] = DateTime.now().toIso8601String();
    }
    if (errorMessage != null) {
      updates['error_message'] = errorMessage;
    }
    await db.update('backup_operations', updates, where: 'id = ?', whereArgs: [id]);
    debugPrint('[BackupOperationService] Updated operation $id to ${status.name}');
  }

  Future<void> updateFilePath(String id, String filePath, {int? fileSize}) async {
    final db = await _dbHelper.database;
    final updates = <String, dynamic>{
      'file_path': filePath,
    };
    if (fileSize != null) {
      updates['file_size'] = fileSize;
    }
    await db.update('backup_operations', updates, where: 'id = ?', whereArgs: [id]);
    debugPrint('[BackupOperationService] Updated file path for $id: $filePath');
  }

  Future<BackupOperation?> getOperation(String id) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'backup_operations',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isEmpty) return null;
    return BackupOperation.fromMap(maps.first);
  }

  Future<List<BackupOperation>> getRecentOperations({int limit = 20}) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'backup_operations',
      orderBy: 'created_at DESC',
      limit: limit,
    );
    return maps.map((map) => BackupOperation.fromMap(map)).toList();
  }

  Future<List<BackupOperation>> getOperationsByStatus(BackupStatus status) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'backup_operations',
      where: 'status = ?',
      whereArgs: [status.name],
      orderBy: 'created_at DESC',
    );
    return maps.map((map) => BackupOperation.fromMap(map)).toList();
  }

  Future<List<BackupOperation>> getOperationsByType(BackupType backupType) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'backup_operations',
      where: 'backup_type = ?',
      whereArgs: [backupType.name],
      orderBy: 'created_at DESC',
    );
    return maps.map((map) => BackupOperation.fromMap(map)).toList();
  }

  Future<void> deleteOperation(String id) async {
    final db = await _dbHelper.database;
    await db.delete('backup_operations', where: 'id = ?', whereArgs: [id]);
    debugPrint('[BackupOperationService] Deleted operation: $id');
  }

  Future<void> cleanupOldOperations({int daysToKeep = 30}) async {
    final cutoff = DateTime.now().subtract(Duration(days: daysToKeep)).toIso8601String();
    final db = await _dbHelper.database;
    await db.delete(
      'backup_operations',
      where: 'created_at < ? AND status = ?',
      whereArgs: [cutoff, BackupStatus.completed.name],
    );
    debugPrint('[BackupOperationService] Cleaned up old operations');
  }

  Future<Map<String, dynamic>> getSummary() async {
    final db = await _dbHelper.database;
    final recent = await getRecentOperations(limit: 10);
    final pending = await getOperationsByStatus(BackupStatus.pending);
    final inProgress = await getOperationsByStatus(BackupStatus.inProgress);
    final failed = await getOperationsByStatus(BackupStatus.failed);

    return {
      'recent': recent.map((op) => op.toJson()).toList(),
      'pendingCount': pending.length,
      'inProgressCount': inProgress.length,
      'failedCount': failed.length,
      'failed': failed.map((op) => op.toJson()).toList(),
    };
  }
}
