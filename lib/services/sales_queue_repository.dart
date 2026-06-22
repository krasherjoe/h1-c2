import 'package:flutter/foundation.dart' show debugPrint;
import 'package:uuid/uuid.dart';
import '../models/sales_queue_model.dart';
import 'database_helper.dart';

class SalesQueueRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final _uuid = const Uuid();

  /// キューにエントリ追加
  Future<void> addEntry({
    required String projectId,
    required String documentId,
    required DateTime deliveryDate,
    required int totalAmount,
    String? customerId,
    String? customerName,
  }) async {
    try {
      final db = await _dbHelper.database;
      final now = DateTime.now();
      
      final entry = SalesQueueEntry(
        id: _uuid.v4(),
        projectId: projectId,
        documentId: documentId,
        deliveryDate: deliveryDate,
        totalAmount: totalAmount,
        customerId: customerId,
        customerName: customerName,
        status: QueueStatus.pending,
        createdAt: now,
      );

      await db.insert('sales_queue', entry.toMap());
      debugPrint('[SalesQueue] Entry added: ${entry.id} for project: $projectId');
    } catch (e) {
      debugPrint('[SalesQueue] addEntry error: $e');
      rethrow;
    }
  }

  /// 顧客別の待機中エントリを取得
  Future<List<SalesQueueEntry>> getPendingEntries() async {
    try {
      final db = await _dbHelper.database;
      final maps = await db.query(
        'sales_queue',
        where: 'status = ?',
        whereArgs: [QueueStatus.pending.name],
        orderBy: 'delivery_date ASC',
      );

      return maps.map((map) => SalesQueueEntry.fromMap(map)).toList();
    } catch (e) {
      debugPrint('[SalesQueue] getPendingEntries error: $e');
      rethrow;
    }
  }

  /// 案件別の待機中エントリを取得
  Future<List<SalesQueueEntry>> getPendingEntriesByProject(String projectId) async {
    try {
      final db = await _dbHelper.database;
      final maps = await db.query(
        'sales_queue',
        where: 'project_id = ? AND status = ?',
        whereArgs: [projectId, QueueStatus.pending.name],
        orderBy: 'delivery_date ASC',
      );

      return maps.map((map) => SalesQueueEntry.fromMap(map)).toList();
    } catch (e) {
      debugPrint('[SalesQueue] getPendingEntriesByProject error: $e');
      rethrow;
    }
  }

  /// 期間内のエントリを取得
  Future<List<SalesQueueEntry>> getEntriesInPeriod({
    required DateTime startDate,
    required DateTime endDate,
    QueueStatus? status,
  }) async {
    try {
      final db = await _dbHelper.database;
      var where = 'delivery_date >= ? AND delivery_date <= ?';
      final whereArgs = [startDate.toIso8601String(), endDate.toIso8601String()];

      if (status != null) {
        where += ' AND status = ?';
        whereArgs.add(status.name);
      }

      final maps = await db.query(
        'sales_queue',
        where: where,
        whereArgs: whereArgs,
        orderBy: 'delivery_date ASC',
      );

      return maps.map((map) => SalesQueueEntry.fromMap(map)).toList();
    } catch (e) {
      debugPrint('[SalesQueue] getEntriesInPeriod error: $e');
      rethrow;
    }
  }

  /// エントリのステータス更新
  Future<void> updateStatus(String id, QueueStatus status, {
    String? invoiceId,
    String? errorMessage,
  }) async {
    try {
      final db = await _dbHelper.database;
      final updates = <String, dynamic>{
        'status': status.name,
        'processed_at': DateTime.now().toIso8601String(),
      };

      if (invoiceId != null) {
        updates['invoice_id'] = invoiceId;
      }

      if (errorMessage != null) {
        updates['error_message'] = errorMessage;
      }

      await db.update(
        'sales_queue',
        updates,
        where: 'id = ?',
        whereArgs: [id],
      );

      debugPrint('[SalesQueue] Entry status updated: $id -> ${status.name}');
    } catch (e) {
      debugPrint('[SalesQueue] updateStatus error: $e');
      rethrow;
    }
  }

  /// エントリ削除
  Future<void> deleteEntry(String id) async {
    try {
      final db = await _dbHelper.database;
      await db.delete(
        'sales_queue',
        where: 'id = ?',
        whereArgs: [id],
      );
      debugPrint('[SalesQueue] Entry deleted: $id');
    } catch (e) {
      debugPrint('[SalesQueue] deleteEntry error: $e');
      rethrow;
    }
  }

  /// 完了したエントリを削除（クリーンアップ）
  Future<int> purgeCompletedEntries({int daysToKeep = 30}) async {
    try {
      final db = await _dbHelper.database;
      final cutoff = DateTime.now().subtract(Duration(days: daysToKeep));
      
      final result = await db.delete(
        'sales_queue',
        where: 'status = ? AND processed_at < ?',
        whereArgs: [QueueStatus.completed.name, cutoff.toIso8601String()],
      );

      final count = result;
      debugPrint('[SalesQueue] Purged $count completed entries');
      return count;
    } catch (e) {
      debugPrint('[SalesQueue] purgeCompletedEntries error: $e');
      return 0;
    }
  }

  /// 統計情報取得
  Future<Map<String, int>> getStatistics() async {
    try {
      final db = await _dbHelper.database;
      
      final pendingResult = await db.rawQuery(
        'SELECT COUNT(*) as count FROM sales_queue WHERE status = ?',
        [QueueStatus.pending.name],
      );
      final pendingCount = (pendingResult.first['count'] as int?) ?? 0;

      final processingResult = await db.rawQuery(
        'SELECT COUNT(*) as count FROM sales_queue WHERE status = ?',
        [QueueStatus.processing.name],
      );
      final processingCount = (processingResult.first['count'] as int?) ?? 0;

      final completedResult = await db.rawQuery(
        'SELECT COUNT(*) as count FROM sales_queue WHERE status = ?',
        [QueueStatus.completed.name],
      );
      final completedCount = (completedResult.first['count'] as int?) ?? 0;

      final failedResult = await db.rawQuery(
        'SELECT COUNT(*) as count FROM sales_queue WHERE status = ?',
        [QueueStatus.failed.name],
      );
      final failedCount = (failedResult.first['count'] as int?) ?? 0;

      return {
        'pending': pendingCount,
        'processing': processingCount,
        'completed': completedCount,
        'failed': failedCount,
      };
    } catch (e) {
      debugPrint('[SalesQueue] getStatistics error: $e');
      return {
        'pending': 0,
        'processing': 0,
        'completed': 0,
        'failed': 0,
      };
    }
  }
}
