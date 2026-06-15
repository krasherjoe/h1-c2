class JournalEntry {
  final String? id;
  final DateTime date;
  final int debitAccountId;
  final int creditAccountId;
  final int amount;
  final String description;
  final String? documentId;
  final String entryType;

  const JournalEntry({
    this.id,
    required this.date,
    required this.debitAccountId,
    required this.creditAccountId,
    required this.amount,
    this.description = '',
    this.documentId,
    this.entryType = 'manual',
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'date': '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
    'debit_account_id': debitAccountId,
    'credit_account_id': creditAccountId,
    'amount': amount,
    'description': description,
    'document_id': documentId,
    'entry_type': entryType,
  };

  factory JournalEntry.fromMap(Map<String, dynamic> map) => JournalEntry(
    id: map['id'] as String?,
    date: DateTime.parse(map['date'] as String? ?? DateTime.now().toIso8601String()),
    debitAccountId: map['debit_account_id'] as int? ?? 0,
    creditAccountId: map['credit_account_id'] as int? ?? 0,
    amount: map['amount'] as int? ?? 0,
    description: map['description'] as String? ?? '',
    documentId: map['document_id'] as String?,
    entryType: map['entry_type'] as String? ?? 'manual',
  );
}
