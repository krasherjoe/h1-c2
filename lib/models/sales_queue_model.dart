/// 売上処理キュー
/// 商品納入ごとの売上処理待ちキュー
class SalesQueueEntry {
  final String id;
  final String projectId;
  final String documentId; // 納品書ID
  final DateTime deliveryDate; // 納入日
  final int totalAmount; // 納入金額
  final String? customerId;
  final String? customerName;
  final QueueStatus status;
  final DateTime createdAt;
  final DateTime? processedAt;
  final String? invoiceId; // 生成された請求書ID
  final String? errorMessage;

  const SalesQueueEntry({
    required this.id,
    required this.projectId,
    required this.documentId,
    required this.deliveryDate,
    required this.totalAmount,
    this.customerId,
    this.customerName,
    this.status = QueueStatus.pending,
    required this.createdAt,
    this.processedAt,
    this.invoiceId,
    this.errorMessage,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'project_id': projectId,
      'document_id': documentId,
      'delivery_date': deliveryDate.toIso8601String(),
      'total_amount': totalAmount,
      'customer_id': customerId,
      'customer_name': customerName,
      'status': status.name,
      'created_at': createdAt.toIso8601String(),
      'processed_at': processedAt?.toIso8601String(),
      'invoice_id': invoiceId,
      'error_message': errorMessage,
    };
  }

  factory SalesQueueEntry.fromMap(Map<String, dynamic> map) {
    return SalesQueueEntry(
      id: map['id'] as String,
      projectId: map['project_id'] as String,
      documentId: map['document_id'] as String,
      deliveryDate: DateTime.parse(map['delivery_date'] as String),
      totalAmount: map['total_amount'] as int,
      customerId: map['customer_id'] as String?,
      customerName: map['customer_name'] as String?,
      status: QueueStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => QueueStatus.pending,
      ),
      createdAt: DateTime.parse(map['created_at'] as String),
      processedAt: map['processed_at'] != null
          ? DateTime.tryParse(map['processed_at'] as String)
          : null,
      invoiceId: map['invoice_id'] as String?,
      errorMessage: map['error_message'] as String?,
    );
  }

  SalesQueueEntry copyWith({
    String? id,
    String? projectId,
    String? documentId,
    DateTime? deliveryDate,
    int? totalAmount,
    String? customerId,
    String? customerName,
    QueueStatus? status,
    DateTime? createdAt,
    DateTime? processedAt,
    String? invoiceId,
    String? errorMessage,
  }) {
    return SalesQueueEntry(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      documentId: documentId ?? this.documentId,
      deliveryDate: deliveryDate ?? this.deliveryDate,
      totalAmount: totalAmount ?? this.totalAmount,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      processedAt: processedAt ?? this.processedAt,
      invoiceId: invoiceId ?? this.invoiceId,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

/// キューステータス
enum QueueStatus {
  pending,    // 待機中
  processing, // 処理中
  completed,  // 完了
  failed,     // 失敗
}

extension QueueStatusX on QueueStatus {
  String get displayName {
    switch (this) {
      case QueueStatus.pending:
        return '待機中';
      case QueueStatus.processing:
        return '処理中';
      case QueueStatus.completed:
        return '完了';
      case QueueStatus.failed:
        return '失敗';
    }
  }

  String get emoji {
    switch (this) {
      case QueueStatus.pending:
        return '⏳';
      case QueueStatus.processing:
        return '⚙️';
      case QueueStatus.completed:
        return '✅';
      case QueueStatus.failed:
        return '❌';
    }
  }
}
