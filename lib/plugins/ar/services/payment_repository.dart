import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import '../../../services/database_helper.dart';
import '../models/ar_models.dart';

class PaymentRepository {
  final DatabaseHelper _db = DatabaseHelper();

  Future<List<Payment>> getAllPayments() async {
    try {
      final database = await _db.database;
      final maps = await database.query('payments', orderBy: 'payment_date DESC');
      return maps.map((map) => Payment.fromMap(map)).toList();
    } catch (e) {
      debugPrint('[AR:PaymentRepo] getAllPayments error: $e');
      rethrow;
    }
  }

  Future<void> savePayment(Payment payment) async {
    try {
      final database = await _db.database;
      await database.insert(
        'payments',
        payment.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      debugPrint('[AR:PaymentRepo] savePayment error: $e');
      rethrow;
    }
  }

  Future<void> deletePayment(String id) async {
    try {
      final database = await _db.database;
      await database.delete('payments', where: 'id = ?', whereArgs: [id]);
    } catch (e) {
      debugPrint('[AR:PaymentRepo] deletePayment error: $e');
      rethrow;
    }
  }

  Future<Payment?> getPayment(String id) async {
    try {
      final database = await _db.database;
      final maps = await database.query('payments', where: 'id = ?', whereArgs: [id], limit: 1);
      if (maps.isEmpty) return null;
      return Payment.fromMap(maps.first);
    } catch (e) {
      debugPrint('[AR:PaymentRepo] getPayment error: $e');
      rethrow;
    }
  }

  String generatePaymentNumber() {
    final now = DateTime.now();
    final year = now.year % 100;
    final month = now.month.toString().padLeft(2, '0');
    return 'PAY$year$month-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}';
  }

  Future<Map<String, int>> getPaymentTotalBySupplier() async {
    try {
      final database = await _db.database;
      final maps = await database.rawQuery('''
        SELECT supplier_id, SUM(amount) as total
        FROM payments
        GROUP BY supplier_id
      ''');
      final result = <String, int>{};
      for (final map in maps) {
        result[map['supplier_id'] as String? ?? ''] = map['total'] as int? ?? 0;
      }
      return result;
    } catch (e) {
      debugPrint('[AR:PaymentRepo] getPaymentTotalBySupplier error: $e');
      rethrow;
    }
  }

  Future<Map<String, int>> getMonthlyPaymentTotals({int months = 12}) async {
    try {
      final database = await _db.database;
      final now = DateTime.now();
      final startDate = DateTime(now.year, now.month - months + 1, 1);
      final maps = await database.rawQuery(
        '''
        SELECT strftime('%Y-%m', payment_date) as month, SUM(amount) as total
        FROM payments
        WHERE payment_date >= ?
        GROUP BY strftime('%Y-%m', payment_date)
        ORDER BY month
        ''',
        [startDate.toIso8601String()],
      );
      final result = <String, int>{};
      for (final map in maps) {
        result[map['month'] as String? ?? ''] = map['total'] as int? ?? 0;
      }
      return result;
    } catch (e) {
      debugPrint('[AR:PaymentRepo] getMonthlyPaymentTotals error: $e');
      rethrow;
    }
  }
}
