class AuditLog {
  final int? id;
  final String tableName;
  final String recordId;
  final String action;
  final String? oldValues;
  final String? newValues;
  final DateTime createdAt;

  const AuditLog({
    this.id,
    required this.tableName,
    required this.recordId,
    required this.action,
    this.oldValues,
    this.newValues,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
    'table_name': tableName,
    'record_id': recordId,
    'action': action,
    'old_values': oldValues,
    'new_values': newValues,
    'created_at': createdAt.toIso8601String(),
  };

  factory AuditLog.fromMap(Map<String, dynamic> map) => AuditLog(
    id: map['id'] as int?,
    tableName: map['table_name'] as String? ?? '',
    recordId: map['record_id'] as String? ?? '',
    action: map['action'] as String? ?? '',
    oldValues: map['old_values'] as String?,
    newValues: map['new_values'] as String?,
    createdAt: DateTime.parse(map['created_at'] as String? ?? DateTime.now().toIso8601String()),
  );
}
