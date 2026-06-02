import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import '../../../services/database_helper.dart';

class WarehouseStock {
  final String productId;
  final String warehouseId;
  final int quantity;
  final DateTime updatedAt;

  const WarehouseStock({
    required this.productId,
    required this.warehouseId,
    required this.quantity,
    required this.updatedAt,
  });

  factory WarehouseStock.fromMap(Map<String, dynamic> map) {
    return WarehouseStock(
      productId: map['product_id'] as String? ?? '',
      warehouseId: map['warehouse_id'] as String? ?? '',
      quantity: map['quantity'] as int? ?? 0,
      updatedAt: DateTime.parse(map['updated_at'] as String? ?? ''),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'product_id': productId,
      'warehouse_id': warehouseId,
      'quantity': quantity,
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}

class WarehouseStockRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  Future<WarehouseStock?> fetchStock(String productId, String warehouseId, {DatabaseExecutor? executor}) async {
    try {
      final db = await _getExecutor(executor);
      final rows = await db.query(
        'warehouse_stock',
        where: 'product_id = ? AND warehouse_id = ?',
        whereArgs: [productId, warehouseId],
        limit: 1,
      );
      if (rows.isEmpty) return null;
      return WarehouseStock.fromMap(rows.first);
    } catch (e) {
      debugPrint('[WarehouseStockRepo] fetchStock error: $e');
      rethrow;
    }
  }

  Future<int> getQuantity(String productId, String warehouseId, {DatabaseExecutor? executor}) async {
    final stock = await fetchStock(productId, warehouseId, executor: executor);
    return stock?.quantity ?? 0;
  }

  Future<List<WarehouseStock>> fetchByProduct(String productId, {DatabaseExecutor? executor}) async {
    try {
      final db = await _getExecutor(executor);
      final rows = await db.query(
        'warehouse_stock',
        where: 'product_id = ?',
        whereArgs: [productId],
      );
      return rows.map(WarehouseStock.fromMap).toList();
    } catch (e) {
      debugPrint('[WarehouseStockRepo] fetchByProduct error: $e');
      rethrow;
    }
  }

  Future<void> setQuantity(String productId, String warehouseId, int quantity, {DatabaseExecutor? executor}) async {
    try {
      final db = await _getExecutor(executor);
      await db.insert(
        'warehouse_stock',
        {
          'product_id': productId,
          'warehouse_id': warehouseId,
          'quantity': quantity,
          'updated_at': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      debugPrint('[WarehouseStockRepo] setQuantity error: $e');
      rethrow;
    }
  }

  Future<void> adjustQuantity(String productId, String warehouseId, int delta, {DatabaseExecutor? executor}) async {
    final current = await getQuantity(productId, warehouseId, executor: executor);
    final next = current + delta;
    if (next < 0) {
      throw StateError('倉庫[$warehouseId]の商品[$productId]の在庫が不足しています (残量: $current, 変動: $delta)');
    }
    await setQuantity(productId, warehouseId, next, executor: executor);
  }

  Future<int> getTotalQuantity(String productId, {DatabaseExecutor? executor}) async {
    try {
      final db = await _getExecutor(executor);
      final result = await db.rawQuery(
        'SELECT COALESCE(SUM(quantity), 0) AS total FROM warehouse_stock WHERE product_id = ?',
        [productId],
      );
      return (result.first['total'] as int?) ?? 0;
    } catch (e) {
      debugPrint('[WarehouseStockRepo] getTotalQuantity error: $e');
      rethrow;
    }
  }

  Future<DatabaseExecutor> _getExecutor(DatabaseExecutor? executor) async {
    if (executor != null) return executor;
    return await _dbHelper.database;
  }
}
