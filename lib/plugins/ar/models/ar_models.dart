import 'package:flutter/material.dart';

enum PaymentStatus { unpaid, partial, paid, overdue }

enum PaymentMethod { bankTransfer, cash, creditCard, advancePayment, other }

class PaymentSchedule {
  final String id;
  final String purchaseId;
  final String documentNumber;
  final String supplierName;
  final DateTime dueDate;
  final int amount;
  final PaymentStatus status;
  final DateTime? paidDate;
  final String? paymentId;
  final DateTime createdAt;
  final DateTime updatedAt;

  PaymentSchedule({
    required this.id,
    required this.purchaseId,
    required this.documentNumber,
    required this.supplierName,
    required this.dueDate,
    required this.amount,
    required this.status,
    this.paidDate,
    this.paymentId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  factory PaymentSchedule.fromMap(Map<String, dynamic> map) {
    return PaymentSchedule(
      id: map['id'] as String? ?? '',
      purchaseId: map['purchase_id'] as String? ?? '',
      documentNumber: map['document_number'] as String? ?? '',
      supplierName: map['supplier_name'] as String? ?? '',
      dueDate: DateTime.tryParse(map['due_date'] as String? ?? '') ?? DateTime.now(),
      amount: map['amount'] as int? ?? 0,
      status: PaymentStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => PaymentStatus.unpaid,
      ),
      paidDate: map['paid_date'] != null ? DateTime.tryParse(map['paid_date'] as String? ?? '') : null,
      paymentId: map['payment_id'] as String?,
      createdAt: DateTime.tryParse(map['created_at'] as String? ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(map['updated_at'] as String? ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'purchase_id': purchaseId,
      'document_number': documentNumber,
      'supplier_name': supplierName,
      'due_date': dueDate.toIso8601String(),
      'amount': amount,
      'status': status.name,
      'paid_date': paidDate?.toIso8601String(),
      'payment_id': paymentId,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  String get displayAmount => '¥${amount.toString().replaceAllMapped(
    RegExp(r'(?=(?!^)(\d{3})+$)'),
    (Match m) => ',',
  )}';

  String get statusDisplayName {
    switch (status) {
      case PaymentStatus.unpaid: return '未払';
      case PaymentStatus.partial: return '部分支払';
      case PaymentStatus.paid: return '支払済';
      case PaymentStatus.overdue: return '延滞';
    }
  }

  String get displayTitle => '$documentNumber - $supplierName';

  String get displaySubtitle => '期日: ${dueDate.year}/${dueDate.month}/${dueDate.day} - $statusDisplayName';

  int get daysUntilDue => dueDate.difference(DateTime.now()).inDays;

  bool get isOverdue => DateTime.now().isAfter(dueDate) && status != PaymentStatus.paid;

  bool get isDueSoon {
    final days = daysUntilDue;
    return days >= 0 && days <= 7 && status != PaymentStatus.paid;
  }

  Color getStatusColor(ColorScheme cs) {
    switch (status) {
      case PaymentStatus.unpaid:
        if (isOverdue) return cs.error;
        if (isDueSoon) return cs.secondary;
        return cs.primary;
      case PaymentStatus.partial:
        return cs.tertiary;
      case PaymentStatus.paid:
        return cs.onSurfaceVariant;
      case PaymentStatus.overdue:
        return cs.error;
    }
  }
}

class Payment {
  final String id;
  final String paymentNumber;
  final DateTime paymentDate;
  final String supplierId;
  final String supplierName;
  final int amount;
  final PaymentMethod paymentMethod;
  final String? bankAccount;
  final String purchaseIds;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  Payment({
    required this.id,
    required this.paymentNumber,
    required this.paymentDate,
    required this.supplierId,
    required this.supplierName,
    required this.amount,
    required this.paymentMethod,
    this.bankAccount,
    this.purchaseIds = '',
    this.notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  factory Payment.fromMap(Map<String, dynamic> map) {
    return Payment(
      id: map['id'] as String? ?? '',
      paymentNumber: map['payment_number'] as String? ?? '',
      paymentDate: DateTime.tryParse(map['payment_date'] as String? ?? '') ?? DateTime.now(),
      supplierId: map['supplier_id'] as String? ?? '',
      supplierName: map['supplier_name'] as String? ?? '',
      amount: map['amount'] as int? ?? 0,
      paymentMethod: PaymentMethod.values.firstWhere(
        (e) => e.name == map['payment_method'],
        orElse: () => PaymentMethod.bankTransfer,
      ),
      bankAccount: map['bank_account'],
      purchaseIds: map['purchase_ids'] as String? ?? '',
      notes: map['notes'],
      createdAt: DateTime.tryParse(map['created_at'] as String? ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(map['updated_at'] as String? ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'payment_number': paymentNumber,
      'payment_date': paymentDate.toIso8601String(),
      'supplier_id': supplierId,
      'supplier_name': supplierName,
      'amount': amount,
      'payment_method': paymentMethod.name,
      'bank_account': bankAccount,
      'purchase_ids': purchaseIds,
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  String get displayAmount => '¥${amount.toString().replaceAllMapped(
    RegExp(r'(?=(?!^)(\d{3})+$)'),
    (Match m) => ',',
  )}';

  String get paymentMethodDisplayName {
    switch (paymentMethod) {
      case PaymentMethod.bankTransfer: return '銀行振込';
      case PaymentMethod.cash: return '現金';
      case PaymentMethod.creditCard: return 'クレジットカード';
      case PaymentMethod.advancePayment: return '代表者立替';
      case PaymentMethod.other: return 'その他';
    }
  }
}

class ArInvoiceRow {
  final String id;
  final String customerName;
  final String date;
  final int totalAmount;
  final int receivedAmount;
  final String paymentStatus;
  final bool isRedInvoice;

  const ArInvoiceRow({
    required this.id,
    required this.customerName,
    required this.date,
    required this.totalAmount,
    required this.receivedAmount,
    required this.paymentStatus,
    this.isRedInvoice = false,
  });

  factory ArInvoiceRow.fromMap(Map<String, dynamic> m) => ArInvoiceRow(
    id: m['id'] as String? ?? '',
    customerName: m['customer_formal_name'] as String? ?? '',
    date: m['date'] as String? ?? '',
    totalAmount: (m['total_amount'] as num?)?.toInt() ?? 0,
    receivedAmount: (m['received_amount'] as num?)?.toInt() ?? 0,
    paymentStatus: m['payment_status'] as String? ?? 'unpaid',
    isRedInvoice: m['is_red_invoice'] == 1 || (m['total_amount'] is num && (m['total_amount'] as num) < 0 && m['source_document_id'] != null),
  );
}

class ArLedgerRow {
  final String customerName;
  final int total;
  final int paid;
  final String lastDate;
  final int count;

  const ArLedgerRow({
    required this.customerName,
    required this.total,
    required this.paid,
    required this.lastDate,
    required this.count,
  });

  factory ArLedgerRow.fromMap(Map<String, dynamic> m) => ArLedgerRow(
    customerName: m['customer_name'] as String? ?? '',
    total: (m['total'] as num?)?.toInt() ?? 0,
    paid: (m['paid'] as num?)?.toInt() ?? 0,
    lastDate: m['last_date'] as String? ?? '',
    count: (m['cnt'] as num?)?.toInt() ?? 0,
  );
}

class ApLedgerRow {
  final String supplierName;
  final int total;
  final int paid;
  final String lastDate;
  final int count;

  const ApLedgerRow({
    required this.supplierName,
    required this.total,
    required this.paid,
    required this.lastDate,
    required this.count,
  });

  factory ApLedgerRow.fromMap(Map<String, dynamic> m) => ApLedgerRow(
    supplierName: m['supplier_name'] as String? ?? '',
    total: (m['total'] as num?)?.toInt() ?? 0,
    paid: (m['paid'] as num?)?.toInt() ?? 0,
    lastDate: m['last_date'] as String? ?? '',
    count: (m['cnt'] as num?)?.toInt() ?? 0,
  );
}
