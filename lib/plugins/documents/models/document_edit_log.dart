class DocumentEditLog {
  final int? id;
  final String documentId;
  final String action;
  final DateTime createdAt;

  const DocumentEditLog({
    this.id,
    required this.documentId,
    required this.action,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
    'document_id': documentId,
    'action': action,
    'created_at': createdAt.toIso8601String(),
  };

  factory DocumentEditLog.fromMap(Map<String, dynamic> map) {
    return DocumentEditLog(
      id: map['id'] as int?,
      documentId: map['document_id'] as String? ?? '',
      action: map['action'] as String? ?? '',
      createdAt: DateTime.parse(map['created_at'] as String? ?? ''),
    );
  }
}
