import 'package:flutter/material.dart';
import '../../../plugins/explorer/h1_explorer_item.dart';

enum DocumentType { estimation, order, delivery, invoice, receipt }

extension DocumentTypeLabel on DocumentType {
  String get label {
    switch (this) {
      case DocumentType.estimation:
        return '見積';
      case DocumentType.order:
        return '受注';
      case DocumentType.delivery:
        return '納品';
      case DocumentType.invoice:
        return '請求';
      case DocumentType.receipt:
        return '領収';
    }
  }
}

DocumentType? documentTypeFromString(String value) {
  for (final t in DocumentType.values) {
    if (t.name == value) return t;
  }
  return null;
}

class DocumentModel extends H1ExplorerItem {
  @override
  final String id;
  final DocumentType documentType;
  final String customerId;
  final String customerName;
  final String documentNumber;
  final DateTime date;
  final int total;
  final String status;
  final String? linkedDocumentId;
  final String? projectId;
  final String? subject;
  final List<DocumentItem> items;
  final bool includeTax;
  final double taxRate;
  final int? totalDiscountAmount;
  final double? totalDiscountRate;
  final String? priceAdjustmentType;
  final int? priceAdjustmentUnit;
  final bool isLocked;
  final String? contentHash;
  final int version;
  final bool isCurrent;
  final String? previousHash;

  DocumentModel({
    required this.id,
    required this.documentType,
    required this.customerId,
    required this.customerName,
    required this.documentNumber,
    required this.date,
    this.total = 0,
    this.status = 'draft',
    this.linkedDocumentId,
    this.projectId,
    this.subject,
    this.items = const [],
    this.includeTax = false,
    this.taxRate = 0.10,
    this.totalDiscountAmount,
    this.totalDiscountRate,
    this.priceAdjustmentType,
    this.priceAdjustmentUnit,
    this.isLocked = false,
    this.contentHash,
    this.version = 1,
    this.isCurrent = true,
    this.previousHash,
  });

  @override
  String get title => documentNumber;

  @override
  String? get subtitle {
    if (subject != null && subject!.isNotEmpty) return subject;
    if (items.isNotEmpty) {
      const max = 3;
      final names = items.take(max).map((i) => i.productName).where((n) => n.isNotEmpty).toList();
      if (names.isNotEmpty) return names.join('、');
    }
    return customerName;
  }

  @override
  String? get badge => documentType.label;

  @override
  IconData? get icon => Icons.description;

  @override
  DateTime? get updatedAt => date;

  bool get isDraft => status == 'draft';
  bool get isConfirmed => status == 'confirmed';

  // --- 税・割引 計算 ---

  int get subtotal => items.fold(0, (sum, item) => sum + item.subtotal);

  int get _regularDiscount {
    int itemDiscount = items.fold(0, (sum, item) {
      if (item.discountAmount != null && item.discountAmount! > 0) {
        return sum + item.discountAmount!;
      }
      if (item.discountRate != null && item.discountRate! > 0) {
        final base = (item.quantity * item.unitPrice).round();
        return sum + (base * item.discountRate!).round();
      }
      return sum;
    });
    if (totalDiscountAmount != null && totalDiscountAmount! > 0) {
      return totalDiscountAmount!;
    }
    if (totalDiscountRate != null && totalDiscountRate! > 0) {
      return (subtotal * totalDiscountRate!).round();
    }
    return itemDiscount;
  }

  int get priceAdjustmentDiscount {
    if (priceAdjustmentType == null || priceAdjustmentUnit == null) return 0;
    if (priceAdjustmentType == 'manual') return priceAdjustmentUnit!;

    final unit = priceAdjustmentUnit!;
    final base = subtotal - _regularDiscount;
    final totalBeforeAdjustment = base;

    int adjustedTotal;
    switch (priceAdjustmentType) {
      case 'round_down':
        adjustedTotal = (totalBeforeAdjustment ~/ unit) * unit;
      case 'round_up':
        adjustedTotal = ((totalBeforeAdjustment + unit - 1) ~/ unit) * unit;
      case 'round_nearest':
        adjustedTotal = ((totalBeforeAdjustment + unit ~/ 2) ~/ unit) * unit;
      default:
        return 0;
    }
    return totalBeforeAdjustment - adjustedTotal;
  }

  int get discountAmount => _regularDiscount + priceAdjustmentDiscount;

  int get taxableAmount {
    return subtotal - discountAmount;
  }

  int get tax {
    if (!includeTax) return 0;
    return (taxableAmount * taxRate).floor();
  }

  int get totalAmount => taxableAmount + tax;

  DocumentModel copyWith({
    String? id,
    DocumentType? documentType,
    String? customerId,
    String? customerName,
    String? documentNumber,
    DateTime? date,
    int? total,
    String? status,
    String? linkedDocumentId,
    String? projectId,
    String? subject,
    List<DocumentItem>? items,
    bool? includeTax,
    double? taxRate,
    int? totalDiscountAmount,
    double? totalDiscountRate,
    String? priceAdjustmentType,
    int? priceAdjustmentUnit,
    bool? isLocked,
    String? contentHash,
    int? version,
    bool? isCurrent,
    String? previousHash,
  }) {
    return DocumentModel(
      id: id ?? this.id,
      documentType: documentType ?? this.documentType,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      documentNumber: documentNumber ?? this.documentNumber,
      date: date ?? this.date,
      total: total ?? this.total,
      status: status ?? this.status,
      linkedDocumentId: linkedDocumentId ?? this.linkedDocumentId,
      projectId: projectId ?? this.projectId,
      subject: subject ?? this.subject,
      items: items ?? this.items,
      includeTax: includeTax ?? this.includeTax,
      taxRate: taxRate ?? this.taxRate,
      totalDiscountAmount: totalDiscountAmount ?? this.totalDiscountAmount,
      totalDiscountRate: totalDiscountRate ?? this.totalDiscountRate,
      priceAdjustmentType: priceAdjustmentType ?? this.priceAdjustmentType,
      priceAdjustmentUnit: priceAdjustmentUnit ?? this.priceAdjustmentUnit,
      isLocked: isLocked ?? this.isLocked,
      contentHash: contentHash ?? this.contentHash,
      version: version ?? this.version,
      isCurrent: isCurrent ?? this.isCurrent,
      previousHash: previousHash ?? this.previousHash,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'document_type': documentType.name,
    'customer_id': customerId,
    'customer_name': customerName,
    'document_number': documentNumber,
    'date': date.toIso8601String().substring(0, 10),
    'total': total,
    'status': status,
    'linked_document_id': linkedDocumentId,
    'project_id': projectId,
    'subject': subject,
    'include_tax': includeTax ? 1 : 0,
    'tax_rate': taxRate,
    'total_discount_amount': totalDiscountAmount,
    'total_discount_rate': totalDiscountRate,
    'price_adjustment_type': priceAdjustmentType,
    'price_adjustment_unit': priceAdjustmentUnit,
    'is_locked': isLocked ? 1 : 0,
    'content_hash': contentHash,
    'version': version,
    'is_current': isCurrent ? 1 : 0,
    'previous_hash': previousHash,
  };

  factory DocumentModel.fromMap(Map<String, dynamic> map, {List<DocumentItem> items = const []}) {
    return DocumentModel(
      id: map['id'] as String,
      documentType: documentTypeFromString(map['document_type'] as String) ?? DocumentType.invoice,
      customerId: map['customer_id'] as String? ?? '',
      customerName: map['customer_name'] as String? ?? '',
      documentNumber: map['document_number'] as String? ?? '',
      date: DateTime.tryParse(map['date'] as String? ?? '') ?? DateTime.now(),
      total: map['total'] as int? ?? 0,
      status: map['status'] as String? ?? 'draft',
      linkedDocumentId: map['linked_document_id'] as String?,
      projectId: map['project_id'] as String?,
      subject: map['subject'] as String?,
      items: items,
      includeTax: (map['include_tax'] as int?) == 1,
      taxRate: (map['tax_rate'] as num?)?.toDouble() ?? 0.10,
      totalDiscountAmount: map['total_discount_amount'] as int?,
      totalDiscountRate: (map['total_discount_rate'] as num?)?.toDouble(),
      priceAdjustmentType: map['price_adjustment_type'] as String?,
      priceAdjustmentUnit: map['price_adjustment_unit'] as int?,
      isLocked: (map['is_locked'] as int?) == 1,
      contentHash: map['content_hash'] as String?,
      version: map['version'] as int? ?? 1,
      isCurrent: (map['is_current'] as int?) != 0,
      previousHash: map['previous_hash'] as String?,
    );
  }
}

class DocumentItem {
  final String id;
  final String productId;
  final String productName;
  final double quantity;
  final int unitPrice;
  final double taxRate;
  final int? discountAmount;
  final double? discountRate;

  const DocumentItem({
    required this.id,
    required this.productId,
    required this.productName,
    this.quantity = 1,
    this.unitPrice = 0,
    this.taxRate = 0.1,
    this.discountAmount,
    this.discountRate,
  });

  int get subtotal {
    final base = (quantity * unitPrice).round();
    if (discountAmount != null && discountAmount! > 0) {
      return base - discountAmount!;
    }
    if (discountRate != null && discountRate! > 0) {
      return (base * (1 - discountRate!)).round();
    }
    return base;
  }

  DocumentItem copyWith({
    String? id,
    String? productId,
    String? productName,
    double? quantity,
    int? unitPrice,
    double? taxRate,
    int? discountAmount,
    double? discountRate,
  }) {
    return DocumentItem(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
      taxRate: taxRate ?? this.taxRate,
      discountAmount: discountAmount ?? this.discountAmount,
      discountRate: discountRate ?? this.discountRate,
    );
  }

  Map<String, dynamic> toMap(String documentId) => {
    'id': id,
    'document_id': documentId,
    'product_id': productId,
    'product_name': productName,
    'quantity': quantity,
    'unit_price': unitPrice,
    'tax_rate': taxRate,
    'discount_amount': discountAmount,
    'discount_rate': discountRate,
  };

  factory DocumentItem.fromMap(Map<String, dynamic> map) {
    return DocumentItem(
      id: map['id'] as String,
      productId: map['product_id'] as String? ?? '',
      productName: map['product_name'] as String? ?? '',
      quantity: (map['quantity'] as num?)?.toDouble() ?? 1,
      unitPrice: map['unit_price'] as int? ?? 0,
      taxRate: (map['tax_rate'] as num?)?.toDouble() ?? 0.1,
      discountAmount: map['discount_amount'] as int?,
      discountRate: (map['discount_rate'] as num?)?.toDouble(),
    );
  }
}
