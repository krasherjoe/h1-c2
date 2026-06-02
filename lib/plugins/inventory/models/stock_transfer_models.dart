import 'package:flutter/foundation.dart';

@immutable
class StockTransferItem {
  const StockTransferItem({
    required this.id,
    required this.transferId,
    required this.productId,
    required this.quantity,
    this.notes,
  });

  final String id;
  final String transferId;
  final String productId;
  final int quantity;
  final String? notes;

  StockTransferItem copyWith({
    String? id,
    String? transferId,
    String? productId,
    int? quantity,
    String? notes,
  }) {
    return StockTransferItem(
      id: id ?? this.id,
      transferId: transferId ?? this.transferId,
      productId: productId ?? this.productId,
      quantity: quantity ?? this.quantity,
      notes: notes ?? this.notes,
    );
  }

  factory StockTransferItem.fromMap(Map<String, Object?> map) {
    return StockTransferItem(
      id: map['id'] as String? ?? '',
      transferId: map['transfer_id'] as String? ?? '',
      productId: map['product_id'] as String? ?? '',
      quantity: map['quantity'] as int? ?? 0,
      notes: map['notes'] as String?,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'transfer_id': transferId,
      'product_id': productId,
      'quantity': quantity,
      'notes': notes,
    };
  }
}

@immutable
class StockTransfer {
  const StockTransfer({
    required this.id,
    required this.documentNo,
    required this.fromWarehouseId,
    required this.toWarehouseId,
    required this.transferDate,
    required this.createdAt,
    required this.updatedAt,
    this.memo,
    this.createdByDevice,
    this.items = const [],
  });

  final String id;
  final String documentNo;
  final String fromWarehouseId;
  final String toWarehouseId;
  final DateTime transferDate;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? memo;
  final String? createdByDevice;
  final List<StockTransferItem> items;

  factory StockTransfer.fromMap(Map<String, Object?> map, {List<StockTransferItem> items = const []}) {
    return StockTransfer(
      id: map['id'] as String? ?? '',
      documentNo: map['document_no'] as String? ?? '',
      fromWarehouseId: map['from_warehouse_id'] as String? ?? '',
      toWarehouseId: map['to_warehouse_id'] as String? ?? '',
      memo: map['memo'] as String?,
      transferDate: DateTime.parse(map['transfer_date'] as String? ?? ''),
      createdAt: DateTime.parse(map['created_at'] as String? ?? ''),
      updatedAt: DateTime.parse(map['updated_at'] as String? ?? ''),
      createdByDevice: map['created_by_device'] as String?,
      items: items,
    );
  }
}

class StockTransferLineInput {
  const StockTransferLineInput({
    required this.productId,
    required this.quantity,
    this.notes,
  });

  final String productId;
  final int quantity;
  final String? notes;
}
