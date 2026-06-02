import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../../../services/database_helper.dart';
import '../models/stock_transaction_model.dart';

class StockTransactionRepository {
  final DatabaseHelper _db = DatabaseHelper();

  Future<List<StockTransaction>> getAll({String? productId, int limit = 100}) async {
    try {
      final db = await _db.database;
      final where = <String>[];
      final args = <Object?>[];
      if (productId != null) { where.add('product_id = ?'); args.add(productId); }
      final rows = await db.query('stock_transactions',
        where: where.isEmpty ? null : where.join(' AND '),
        whereArgs: args.isEmpty ? null : args,
        orderBy: 'created_at DESC',
        limit: limit,
      );
      return rows.map(StockTransaction.fromMap).toList();
    } catch (e) {
      debugPrint('[StockTransactionRepo] getAll error: $e');
      rethrow;
    }
  }

  Future<void> inbound({
    required String productId,
    required String productName,
    required int quantity,
    String? warehouseId,
    String? warehouseName,
    String? type,
    String? referenceId,
    String? referenceNumber,
    String? notes,
  }) async {
    try {
      final db = await _db.database;
      await db.insert('stock_transactions', StockTransaction(
        id: const Uuid().v4(),
        productId: productId,
        productName: productName,
        warehouseId: warehouseId,
        warehouseName: warehouseName,
        quantity: quantity.abs(),
        type: type ?? 'inbound',
        referenceId: referenceId,
        referenceNumber: referenceNumber,
        notes: notes,
        createdAt: DateTime.now(),
      ).toMap());
      await _updateStock(productId, quantity.abs(), warehouseId);
    } catch (e) {
      debugPrint('[StockTransactionRepo] inbound error: $e');
      rethrow;
    }
  }

  Future<void> outbound({
    required String productId,
    required String productName,
    required int quantity,
    String? warehouseId,
    String? warehouseName,
    String? type,
    String? referenceId,
    String? referenceNumber,
    String? notes,
  }) async {
    try {
      final db = await _db.database;
      await db.insert('stock_transactions', StockTransaction(
        id: const Uuid().v4(),
        productId: productId,
        productName: productName,
        warehouseId: warehouseId,
        warehouseName: warehouseName,
        quantity: -quantity.abs(),
        type: type ?? 'outbound',
        referenceId: referenceId,
        referenceNumber: referenceNumber,
        notes: notes,
        createdAt: DateTime.now(),
      ).toMap());
      await _updateStock(productId, -quantity.abs(), warehouseId);
    } catch (e) {
      debugPrint('[StockTransactionRepo] outbound error: $e');
      rethrow;
    }
  }

  Future<void> _updateStock(String productId, int deltaQty, String? warehouseId) async {
    try {
      final db = await _db.database;
      if (warehouseId != null) {
        await db.execute('''
          INSERT INTO warehouse_stock (product_id, warehouse_id, quantity, updated_at)
          VALUES (?, ?, ?, ?)
          ON CONFLICT(product_id, warehouse_id) DO UPDATE SET
            quantity = quantity + ?,
            updated_at = ?
        ''', [productId, warehouseId, deltaQty > 0 ? deltaQty : 0, DateTime.now().toIso8601String(), deltaQty, DateTime.now().toIso8601String()]);
      }
      await db.execute('''
        UPDATE products SET stock_quantity = COALESCE((
          SELECT SUM(quantity) FROM warehouse_stock WHERE product_id = ?
        ), 0) WHERE id = ?
      ''', [productId, productId]);
      await db.execute('''
        UPDATE products SET stock_quantity = COALESCE(stock_quantity, 0) + ?
        WHERE id = ? AND (SELECT COUNT(*) FROM warehouse_stock WHERE product_id = ?) = 0
      ''', [deltaQty, productId, productId]);
    } catch (e) {
      debugPrint('[StockTransactionRepo] _updateStock error: $e');
      rethrow;
    }
  }
}
