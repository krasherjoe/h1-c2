enum PaymentStatus {
  unpaid,
  partial,
  paid,
  cancelled,
  overdue;

  String get label {
    switch (this) {
      case PaymentStatus.unpaid:
        return '未払い';
      case PaymentStatus.partial:
        return '一部入金';
      case PaymentStatus.paid:
        return '入金済み';
      case PaymentStatus.cancelled:
        return '取消';
      case PaymentStatus.overdue:
        return '延滞';
    }
  }

  String get dbValue => name;

  static PaymentStatus fromDb(String? value) {
    if (value == null) return PaymentStatus.unpaid;
    return PaymentStatus.values.firstWhere(
      (s) => s.name == value,
      orElse: () => PaymentStatus.unpaid,
    );
  }
}
