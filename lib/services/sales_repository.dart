import 'package:flutter/foundation.dart' show debugPrint;
import 'package:sqflite/sqflite.dart';
import '../models/sales_model.dart' show Sales;
import 'database_helper.dart';

class SalesRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  Future<List<Map<String, dynamic>>> getAll({String? orderBy}) async {
    try {
      final db = await _dbHelper.database;
      return await db.query(
        'sales',
        orderBy: orderBy ?? 'date DESC',
      );
    } catch (e) {
      debugPrint('[SalesRepo] getAll error: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> getById(String id) async {
    try {
      final db = await _dbHelper.database;
      final maps = await db.query(
        'sales',
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      return maps.isNotEmpty ? maps.first : null;
    } catch (e) {
      debugPrint('[SalesRepo] getById error: $e');
      rethrow;
    }
  }

  Future<void> save(Map<String, dynamic> data) async {
    try {
      final db = await _dbHelper.database;
      await db.insert(
        'sales',
        data,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      debugPrint('[SalesRepo] save error: $e');
      rethrow;
    }
  }

  Future<Sales?> getSales(String invoiceId) async => null;

  Future<void> saveSales(Sales sales) async {}
}
