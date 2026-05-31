class Sales {
  final String id;
  final String documentNumber;
  final DateTime date;
  final dynamic customer;
  final List<dynamic> items;
  final int subtotal;
  final int taxAmount;
  final int total;
  final double taxRate;
  final dynamic status;
  final DateTime? paymentDueDate;
  final String? paymentMethod;
  final String? projectId;
  final String? subject;
  final DateTime createdAt;
  final DateTime updatedAt;

  Sales({
    required this.id,
    this.documentNumber = '',
    required this.date,
    this.customer,
    this.items = const [],
    this.subtotal = 0,
    this.taxAmount = 0,
    this.total = 0,
    this.taxRate = 0.0,
    this.status,
    this.paymentDueDate,
    this.paymentMethod,
    this.projectId,
    this.subject,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'document_number': documentNumber,
    'date': date.toIso8601String(),
    'subtotal': subtotal,
    'tax_amount': taxAmount,
    'total': total,
    'tax_rate': taxRate,
    'payment_due_date': paymentDueDate?.toIso8601String(),
    'payment_method': paymentMethod,
    'project_id': projectId,
    'subject': subject,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
  };

  factory Sales.fromMap(Map<String, dynamic> map) => Sales(
    id: map['id'],
    documentNumber: map['document_number'] ?? '',
    date: DateTime.parse(map['date']),
    subtotal: map['subtotal'] ?? 0,
    taxAmount: map['tax_amount'] ?? 0,
    total: map['total'] ?? 0,
    taxRate: (map['tax_rate'] as num?)?.toDouble() ?? 0.0,
    paymentDueDate: map['payment_due_date'] != null ? DateTime.parse(map['payment_due_date']) : null,
    paymentMethod: map['payment_method'],
    projectId: map['project_id'],
    subject: map['subject'],
    createdAt: map['created_at'] != null ? DateTime.parse(map['created_at']) : DateTime.now(),
    updatedAt: map['updated_at'] != null ? DateTime.parse(map['updated_at']) : DateTime.now(),
  );
}
