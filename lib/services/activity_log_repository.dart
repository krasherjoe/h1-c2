import 'package:flutter/foundation.dart' show debugPrint;
import 'database_helper.dart';

class ActivityLog {
  final String id;
  final String action;
  final String targetType;
  final String? targetId;
  final String? details;
  final String? screenId;
  final DateTime timestamp;

  ActivityLog({
    String? id,
    required this.action,
    required this.targetType,
    this.targetId,
    this.details,
    this.screenId,
    DateTime? timestamp,
  }) : id = id ?? DateTime.now().microsecondsSinceEpoch.toString(),
       timestamp = timestamp ?? DateTime.now();

  factory ActivityLog.create({
    required String action,
    required String targetType,
    String? targetId,
    String? details,
    String? screenId,
  }) {
    return ActivityLog(
      action: action,
      targetType: targetType,
      targetId: targetId,
      details: details,
      screenId: screenId,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'action': action,
      'target_type': targetType,
      'target_id': targetId,
      'details': details,
      'screen_id': screenId,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory ActivityLog.fromMap(Map<String, dynamic> map) {
    return ActivityLog(
      id: map['id'],
      action: map['action'],
      targetType: map['target_type'],
      targetId: map['target_id'],
      details: map['details'],
      screenId: map['screen_id'],
      timestamp: DateTime.parse(map['timestamp']),
    );
  }
}

class ActivityLogRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  Future<void> log(ActivityLog log) async {
    try {
      final db = await _dbHelper.database;
      await db.insert('activity_logs', log.toMap());
    } catch (e) {
      debugPrint('[ActivityLogRepo] log error: $e');
      rethrow;
    }
  }

  Future<void> logAction({
    required String action,
    required String targetType,
    String? targetId,
    String? details,
    String? screenId,
  }) async {
    final activity = ActivityLog.create(
      action: action,
      targetType: targetType,
      targetId: targetId,
      details: details,
      screenId: screenId,
    );
    await log(activity);
  }

  Future<List<ActivityLog>> getAllLogs({int limit = 100}) async {
    try {
      final db = await _dbHelper.database;
      final List<Map<String, dynamic>> maps = await db.query(
        'activity_logs',
        orderBy: 'timestamp DESC',
        limit: limit,
      );
      return List.generate(maps.length, (i) => ActivityLog.fromMap(maps[i]));
    } catch (e) {
      debugPrint('[ActivityLogRepo] getAllLogs error: $e');
      rethrow;
    }
  }
}
