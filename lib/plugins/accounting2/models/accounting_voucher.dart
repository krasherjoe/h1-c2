import 'package:flutter/material.dart';
import '../../../plugins/explorer/h1_explorer_item.dart';

enum AccountingVoucherType {
  sales,      // 売上伝票
  cashIn,     // 入金伝票
  cashOut,    // 出金伝票
  transfer,   // 振替伝票
}

extension AccountingVoucherTypeExtension on AccountingVoucherType {
  String get label => switch (this) {
    AccountingVoucherType.sales => '売上',
    AccountingVoucherType.cashIn => '入金',
    AccountingVoucherType.cashOut => '出金',
    AccountingVoucherType.transfer => '振替',
  };

  String get fullName => switch (this) {
    AccountingVoucherType.sales => '売上伝票',
    AccountingVoucherType.cashIn => '入金伝票',
    AccountingVoucherType.cashOut => '出金伝票',
    AccountingVoucherType.transfer => '振替伝票',
  };

  static AccountingVoucherType fromString(String value) => switch (value) {
    'sales' => AccountingVoucherType.sales,
    'cashIn' => AccountingVoucherType.cashIn,
    'cashOut' => AccountingVoucherType.cashOut,
    'transfer' => AccountingVoucherType.transfer,
    _ => AccountingVoucherType.sales,
  };
}

class AccountingVoucher extends H1ExplorerItem {
  final String voucherId;
  final AccountingVoucherType type;
  final String voucherNumber;
  final DateTime date;
  final int amount;
  final String? customerId;
  final String? customerName;
  final String? accountId;
  final String? accountName;
  final String? description;
  final String? reference;
  final String status; // draft, confirmed, cancelled
  final DateTime createdAt;
  final DateTime? voucherUpdatedAt;

  AccountingVoucher({
    required this.voucherId,
    required this.type,
    required this.voucherNumber,
    required this.date,
    required this.amount,
    this.customerId,
    this.customerName,
    this.accountId,
    this.accountName,
    this.description,
    this.reference,
    required this.status,
    required this.createdAt,
    this.voucherUpdatedAt,
  });

  factory AccountingVoucher.fromMap(Map<String, dynamic> map) {
    return AccountingVoucher(
      voucherId: map['id'] as String,
      type: AccountingVoucherTypeExtension.fromString(map['type'] as String),
      voucherNumber: map['voucher_number'] as String,
      date: DateTime.parse(map['date'] as String),
      amount: map['amount'] as int,
      customerId: map['customer_id'] as String?,
      customerName: map['customer_name'] as String?,
      accountId: map['account_id'] as String?,
      accountName: map['account_name'] as String?,
      description: map['description'] as String?,
      reference: map['reference'] as String?,
      status: map['status'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
      voucherUpdatedAt: map['updated_at'] != null ? DateTime.parse(map['updated_at'] as String) : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': voucherId,
      'type': type.name,
      'voucher_number': voucherNumber,
      'date': date.toIso8601String(),
      'amount': amount,
      'customer_id': customerId,
      'customer_name': customerName,
      'account_id': accountId,
      'account_name': accountName,
      'description': description,
      'reference': reference,
      'status': status,
      'created_at': createdAt.toIso8601String(),
      'updated_at': voucherUpdatedAt?.toIso8601String(),
    };
  }

  bool get isDraft => status == 'draft';
  bool get isConfirmed => status == 'confirmed';
  bool get isCancelled => status == 'cancelled';

  // H1ExplorerItem interface
  @override
  String get id => voucherId;
  @override
  String get title => voucherNumber;
  @override
  String? get subtitle => description;
  @override
  String? get badge => status == 'draft' ? '下書き' : null;
  @override
  IconData? get icon => switch (type) {
    AccountingVoucherType.sales => Icons.trending_up,
    AccountingVoucherType.cashIn => Icons.account_balance_wallet,
    AccountingVoucherType.cashOut => Icons.payment,
    AccountingVoucherType.transfer => Icons.swap_horiz,
  };
  @override
  DateTime? get updatedAt => voucherUpdatedAt;
}
