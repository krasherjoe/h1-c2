import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../../../services/database_helper.dart';
import '../../../services/product_repository.dart';
import '../../../services/activity_log_repository.dart';
import '../models/stock_transfer_models.dart';
import 'warehouse_stock_repository.dart';

class StockTransferService {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final WarehouseStockRepository _warehouseStockRepo = WarehouseStockRepository();
  final ProductRepository _productRepo = ProductRepository();
  final ActivityLogRepository _logRepo = ActivityLogRepository();

  Future<StockTransfer> createTransfer({
    required String fromWarehouseId,
    required String toWarehouseId,
    required DateTime transferDate,
    required List<StockTransferLineInput> lines,
    String? memo,
    String? createdByDevice,
  }) async {
    if (fromWarehouseId == toWarehouseId) {
      throw ArgumentError('移動元と移動先の倉庫が同一です');
    }
    final filteredLines = lines.where((l) => l.quantity > 0).toList();
    if (filteredLines.isEmpty) {
      throw ArgumentError('移動する商品がありません');
    }

    final db = await _dbHelper.database;
    final transferId = const Uuid().v4();
    final docNo = _generateDocumentNo(createdByDevice);
    final now = DateTime.now();
    final productIds = <String>{};

    await db.transaction((txn) async {
      await _ensureWarehouseExists(txn, fromWarehouseId);
      await _ensureWarehouseExists(txn, toWarehouseId);

      for (final line in filteredLines) {
        productIds.add(line.productId);
        await _warehouseStockRepo.adjustQuantity(
          line.productId, fromWarehouseId, -line.quantity, executor: txn,
        );
        await _warehouseStockRepo.adjustQuantity(
          line.productId, toWarehouseId, line.quantity, executor: txn,
        );
      }

      await txn.insert('stock_transfers', {
        'id': transferId,
        'document_no': docNo,
        'from_warehouse_id': fromWarehouseId,
        'to_warehouse_id': toWarehouseId,
        'memo': memo,
        'transfer_date': transferDate.toIso8601String(),
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
        'created_by_device': createdByDevice,
      });

      for (final line in filteredLines) {
        await txn.insert('stock_transfer_items', {
          'id': const Uuid().v4(),
          'transfer_id': transferId,
          'product_id': line.productId,
          'quantity': line.quantity,
          'notes': line.notes,
        });
      }
    });

    await _syncProductTotals(productIds.toList());

    await _logRepo.logAction(
      action: 'STOCK_TRANSFER_CREATE',
      targetType: 'STOCK_TRANSFER',
      targetId: transferId,
      details: '倉庫移動: $docNo (${filteredLines.length}件)',
    );

    return StockTransfer(
      id: transferId,
      documentNo: docNo,
      fromWarehouseId: fromWarehouseId,
      toWarehouseId: toWarehouseId,
      memo: memo,
      transferDate: transferDate,
      createdAt: now,
      updatedAt: now,
      createdByDevice: createdByDevice,
      items: filteredLines
          .map((line) => StockTransferItem(
                id: const Uuid().v4(),
                transferId: transferId,
                productId: line.productId,
                quantity: line.quantity,
                notes: line.notes,
              ))
          .toList(),
    );
  }

  Future<void> _syncProductTotals(List<String> productIds) async {
    if (productIds.isEmpty) return;
    final Map<String, int> updates = {};
    for (final pid in productIds) {
      final total = await _warehouseStockRepo.getTotalQuantity(pid);
      updates[pid] = total;
    }
    await _productRepo.updateStockQuantities(updates);
  }

  Future<void> _ensureWarehouseExists(DatabaseExecutor executor, String warehouseId) async {
    final rows = await executor.query('warehouses', where: 'id = ?', whereArgs: [warehouseId], limit: 1);
    if (rows.isEmpty) {
      throw ArgumentError('倉庫が見つかりません (id: $warehouseId)');
    }
  }

  String _generateDocumentNo(String? deviceId) {
    final now = DateTime.now();
    final prefix = deviceId?.substring(0, deviceId.length.clamp(0, 4)) ?? 'M';
    final datePart = '${now.year.toString().padLeft(4, '0')}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    final timePart = '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';
    return '$prefix$datePart-$timePart-${now.millisecondsSinceEpoch % 1000}';
  }
}
