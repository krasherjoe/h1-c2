import 'package:flutter/material.dart';
import '../../../explorer/h1_explorer_item.dart';

enum PurchaseType { order, receipt, return_, payment }

extension PurchaseTypeLabel on PurchaseType {
  String get label {
    switch (this) {
      case PurchaseType.order:
        return '発注';
      case PurchaseType.receipt:
        return '入荷';
      case PurchaseType.return_:
        return '返品';
      case PurchaseType.payment:
        return '支払';
    }
  }
}

PurchaseType? purchaseTypeFromString(String value) {
  for (final t in PurchaseType.values) {
    if (t.name == value) return t;
  }
  return null;
}

class PurchaseItem {
  final String id;
  final String productId;
  final String productName;
  final double quantity;
  final int unitPrice;
  final double taxRate;

  const PurchaseItem({
    required this.id,
    required this.productId,
    required this.productName,
    this.quantity = 1,
    this.unitPrice = 0,
    this.taxRate = 0.1,
  });

  int get subtotal => (quantity * unitPrice).round();

  Map<String, dynamic> toMap(String purchaseId) => {
    'id': id,
    'purchase_id': purchaseId,
    'product_id': productId,
    'product_name': productName,
    'quantity': quantity,
    'unit_price': unitPrice,
    'tax_rate': taxRate,
  };

  factory PurchaseItem.fromMap(Map<String, dynamic> map) {
    return PurchaseItem(
      id: map['id'] as String,
      productId: map['product_id'] as String? ?? '',
      productName: map['product_name'] as String? ?? '',
      quantity: (map['quantity'] as num?)?.toDouble() ?? 1,
      unitPrice: map['unit_price'] as int? ?? 0,
      taxRate: (map['tax_rate'] as num?)?.toDouble() ?? 0.1,
    );
  }

  PurchaseItem copyWith({
    String? id,
    String? productId,
    String? productName,
    double? quantity,
    int? unitPrice,
    double? taxRate,
  }) {
    return PurchaseItem(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
      taxRate: taxRate ?? this.taxRate,
    );
  }
}

class PurchaseModel extends H1ExplorerItem {
  @override
  final String id;
  final PurchaseType purchaseType;
  final String supplierId;
  final String supplierName;
  final String documentNumber;
  final DateTime date;
  final int total;
  final String status;
  final String? linkedDocumentId;
  final List<PurchaseItem> items;

  PurchaseModel({
    required this.id,
    required this.purchaseType,
    this.supplierId = '',
    this.supplierName = '',
    this.documentNumber = '',
    required this.date,
    this.total = 0,
    this.status = 'draft',
    this.linkedDocumentId,
    this.items = const [],
  });

  @override
  String get title => documentNumber.isNotEmpty ? documentNumber : '(新規)';

  @override
  String? get subtitle => supplierName.isNotEmpty ? supplierName : null;

  @override
  String? get badge => purchaseType.label;

  @override
  IconData? get icon => Icons.shopping_cart;

  @override
  DateTime? get updatedAt => date;

  bool get isDraft => status == 'draft';
  bool get isConfirmed => status == 'confirmed';

  PurchaseModel copyWith({
    String? id,
    PurchaseType? purchaseType,
    String? supplierId,
    String? supplierName,
    String? documentNumber,
    DateTime? date,
    int? total,
    String? status,
    String? linkedDocumentId,
    List<PurchaseItem>? items,
  }) {
    return PurchaseModel(
      id: id ?? this.id,
      purchaseType: purchaseType ?? this.purchaseType,
      supplierId: supplierId ?? this.supplierId,
      supplierName: supplierName ?? this.supplierName,
      documentNumber: documentNumber ?? this.documentNumber,
      date: date ?? this.date,
      total: total ?? this.total,
      status: status ?? this.status,
      linkedDocumentId: linkedDocumentId ?? this.linkedDocumentId,
      items: items ?? this.items,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'purchase_type': purchaseType.name,
    'supplier_id': supplierId,
    'supplier_name': supplierName,
    'document_number': documentNumber,
    'date': date.toIso8601String().substring(0, 10),
    'total': total,
    'status': status,
    'linked_document_id': linkedDocumentId,
  };

  factory PurchaseModel.fromMap(Map<String, dynamic> map, {List<PurchaseItem> items = const []}) {
    return PurchaseModel(
      id: map['id'] as String,
      purchaseType: purchaseTypeFromString(map['purchase_type'] as String) ?? PurchaseType.order,
      supplierId: map['supplier_id'] as String? ?? '',
      supplierName: map['supplier_name'] as String? ?? '',
      documentNumber: map['document_number'] as String? ?? '',
      date: DateTime.tryParse(map['date'] as String? ?? '') ?? DateTime.now(),
      total: map['total'] as int? ?? 0,
      status: map['status'] as String? ?? 'draft',
      linkedDocumentId: map['linked_document_id'] as String?,
      items: items,
    );
  }
}
