class DocumentEditLog {
  final int? id;
  final String documentId;
  final String action;
  final String details;
  final DateTime createdAt;

  const DocumentEditLog({
    this.id,
    required this.documentId,
    required this.action,
    this.details = '',
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
    'document_id': documentId,
    'action': action,
    'details': details,
    'created_at': createdAt.toIso8601String(),
  };

  factory DocumentEditLog.fromMap(Map<String, dynamic> map) {
    return DocumentEditLog(
      id: map['id'] as int?,
      documentId: map['document_id'] as String? ?? '',
      action: map['action'] as String? ?? '',
      details: map['details'] as String? ?? '',
      createdAt: DateTime.parse(map['created_at'] as String? ?? ''),
    );
  }
}
