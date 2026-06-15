class CashTransaction {
  final String? id;
  final DateTime date;
  final String type;
  final int amount;
  final int accountId;
  final String description;

  const CashTransaction({
    this.id,
    required this.date,
    required this.type,
    required this.amount,
    required this.accountId,
    this.description = '',
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'date': '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
    'type': type,
    'amount': amount,
    'account_id': accountId,
    'description': description,
  };

  factory CashTransaction.fromMap(Map<String, dynamic> map) => CashTransaction(
    id: map['id'] as String?,
    date: DateTime.parse(map['date'] as String? ?? DateTime.now().toIso8601String()),
    type: map['type'] as String? ?? 'inflow',
    amount: map['amount'] as int? ?? 0,
    accountId: map['account_id'] as int? ?? 0,
    description: map['description'] as String? ?? '',
  );
}
