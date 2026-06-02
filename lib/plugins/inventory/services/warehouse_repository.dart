import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import '../../../services/database_helper.dart';
import '../../../services/activity_log_repository.dart';
import '../models/warehouse_model.dart';

class WarehouseRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final ActivityLogRepository _logRepo = ActivityLogRepository();

  Future<List<Warehouse>> fetchWarehouses({bool includeHidden = false}) async {
    try {
      final db = await _dbHelper.database;
      final rows = await db.query(
        'warehouses',
        where: includeHidden ? null : 'is_hidden = 0',
        orderBy: 'name COLLATE NOCASE ASC',
      );
      return rows.map((row) => Warehouse.fromMap(row)).toList();
    } catch (e) {
      debugPrint('[WarehouseRepo] fetchWarehouses error: $e');
      rethrow;
    }
  }

  Future<List<Warehouse>> getAllWarehouses() async {
    return fetchWarehouses(includeHidden: true);
  }

  Future<void> saveWarehouse(Warehouse warehouse) async {
    try {
      final db = await _dbHelper.database;
      await db.insert(
        'warehouses',
        warehouse.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      await _logRepo.logAction(
        action: 'SAVE_WAREHOUSE',
        targetType: 'WAREHOUSE',
        targetId: warehouse.id,
        details: '倉庫名: ${warehouse.name}',
      );
    } catch (e) {
      debugPrint('[WarehouseRepo] saveWarehouse error: $e');
      rethrow;
    }
  }

  Future<void> deleteWarehouse(String warehouseId) async {
    try {
      final db = await _dbHelper.database;
      await db.delete('warehouses', where: 'id = ?', whereArgs: [warehouseId]);

      await _logRepo.logAction(
        action: 'DELETE_WAREHOUSE',
        targetType: 'WAREHOUSE',
        targetId: warehouseId,
        details: '倉庫を削除しました',
      );
    } catch (e) {
      debugPrint('[WarehouseRepo] deleteWarehouse error: $e');
      rethrow;
    }
  }

  Future<void> setHidden(String id, bool hidden) async {
    try {
      final db = await _dbHelper.database;
      await db.update(
        'warehouses',
        {'is_hidden': hidden ? 1 : 0},
        where: 'id = ?',
        whereArgs: [id],
      );

      await _logRepo.logAction(
        action: hidden ? 'HIDE_WAREHOUSE' : 'UNHIDE_WAREHOUSE',
        targetType: 'WAREHOUSE',
        targetId: id,
        details: hidden ? '倉庫を非表示にしました' : '倉庫を再表示しました',
      );
    } catch (e) {
      debugPrint('[WarehouseRepo] setHidden error: $e');
      rethrow;
    }
  }

  Future<Warehouse> ensureDefaultWarehouse() async {
    const defaultId = 'warehouse-main-default';
    const defaultName = 'メイン倉庫';
    try {
      final db = await _dbHelper.database;
      final rows = await db.query('warehouses', where: 'id = ?', whereArgs: [defaultId]);
      if (rows.isNotEmpty) {
        return Warehouse.fromMap(rows.first);
      }
      final defaultWarehouse = Warehouse(
        id: defaultId,
        name: defaultName,
        updatedAt: DateTime.now(),
        notes: '自動生成された倉庫',
      );
      await saveWarehouse(defaultWarehouse);
      return defaultWarehouse;
    } catch (e) {
      debugPrint('[WarehouseRepo] ensureDefaultWarehouse error: $e');
      rethrow;
    }
  }
}
