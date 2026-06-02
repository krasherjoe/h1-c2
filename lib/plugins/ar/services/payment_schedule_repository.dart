import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import '../../../services/database_helper.dart';
import '../models/ar_models.dart';

class PaymentScheduleRepository {
  final DatabaseHelper _db = DatabaseHelper();

  Future<List<PaymentSchedule>> getAllSchedules() async {
    try {
      final database = await _db.database;
      final maps = await database.query('payment_schedules', orderBy: 'due_date ASC');
      return maps.map((map) => PaymentSchedule.fromMap(map)).toList();
    } catch (e) {
      debugPrint('[AR:ScheduleRepo] getAllSchedules error: $e');
      rethrow;
    }
  }

  Future<List<PaymentSchedule>> getOverdueSchedules() async {
    try {
      final database = await _db.database;
      final now = DateTime.now().toIso8601String();
      final maps = await database.query(
        'payment_schedules',
        where: 'due_date < ? AND status != ?',
        whereArgs: [now, 'paid'],
        orderBy: 'due_date ASC',
      );
      return maps.map((map) => PaymentSchedule.fromMap(map)).toList();
    } catch (e) {
      debugPrint('[AR:ScheduleRepo] getOverdueSchedules error: $e');
      rethrow;
    }
  }

  Future<List<PaymentSchedule>> getUpcomingSchedules({int days = 30}) async {
    try {
      final database = await _db.database;
      final now = DateTime.now();
      final futureDate = now.add(Duration(days: days));
      final maps = await database.query(
        'payment_schedules',
        where: 'due_date BETWEEN ? AND ? AND status != ?',
        whereArgs: [now.toIso8601String(), futureDate.toIso8601String(), 'paid'],
        orderBy: 'due_date ASC',
      );
      return maps.map((map) => PaymentSchedule.fromMap(map)).toList();
    } catch (e) {
      debugPrint('[AR:ScheduleRepo] getUpcomingSchedules error: $e');
      rethrow;
    }
  }

  Future<void> saveSchedule(PaymentSchedule schedule) async {
    try {
      final database = await _db.database;
      await database.insert(
        'payment_schedules',
        schedule.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      debugPrint('[AR:ScheduleRepo] saveSchedule error: $e');
      rethrow;
    }
  }

  Future<void> updateScheduleStatus(String id, PaymentStatus status, {String? paymentId}) async {
    try {
      final database = await _db.database;
      final updateData = <String, dynamic>{
        'status': status.name,
        'updated_at': DateTime.now().toIso8601String(),
      };
      if (paymentId != null) {
        updateData['payment_id'] = paymentId;
      }
      if (status == PaymentStatus.paid) {
        updateData['paid_date'] = DateTime.now().toIso8601String();
      }
      await database.update('payment_schedules', updateData, where: 'id = ?', whereArgs: [id]);
    } catch (e) {
      debugPrint('[AR:ScheduleRepo] updateScheduleStatus error: $e');
      rethrow;
    }
  }

  Future<PaymentSchedule?> getSchedule(String id) async {
    try {
      final database = await _db.database;
      final maps = await database.query('payment_schedules', where: 'id = ?', whereArgs: [id], limit: 1);
      if (maps.isEmpty) return null;
      return PaymentSchedule.fromMap(maps.first);
    } catch (e) {
      debugPrint('[AR:ScheduleRepo] getSchedule error: $e');
      rethrow;
    }
  }

  Future<Map<String, int>> getMonthlyScheduleTotals({int months = 12}) async {
    try {
      final database = await _db.database;
      final now = DateTime.now();
      final startDate = DateTime(now.year, now.month - months + 1, 1);
      final maps = await database.rawQuery(
        '''
        SELECT strftime('%Y-%m', due_date) as month, SUM(amount) as total
        FROM payment_schedules
        WHERE due_date >= ? AND status != ?
        GROUP BY strftime('%Y-%m', due_date)
        ORDER BY month
        ''',
        [startDate.toIso8601String(), 'paid'],
      );
      final result = <String, int>{};
      for (final map in maps) {
        result[map['month'] as String? ?? ''] = map['total'] as int? ?? 0;
      }
      return result;
    } catch (e) {
      debugPrint('[AR:ScheduleRepo] getMonthlyScheduleTotals error: $e');
      rethrow;
    }
  }
}
