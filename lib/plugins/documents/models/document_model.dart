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

  const DocumentItem({
    required this.id,
    required this.productId,
    required this.productName,
    this.quantity = 1,
    this.unitPrice = 0,
    this.taxRate = 0.1,
  });

  int get subtotal => (quantity * unitPrice).round();

  DocumentItem copyWith({
    String? id,
    String? productId,
    String? productName,
    double? quantity,
    int? unitPrice,
    double? taxRate,
  }) {
    return DocumentItem(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
      taxRate: taxRate ?? this.taxRate,
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
  };

  factory DocumentItem.fromMap(Map<String, dynamic> map) {
    return DocumentItem(
      id: map['id'] as String,
      productId: map['product_id'] as String? ?? '',
      productName: map['product_name'] as String? ?? '',
      quantity: (map['quantity'] as num?)?.toDouble() ?? 1,
      unitPrice: map['unit_price'] as int? ?? 0,
      taxRate: (map['tax_rate'] as num?)?.toDouble() ?? 0.1,
    );
  }
}
