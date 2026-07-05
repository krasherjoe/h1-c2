class SyncRecord {
  final String id;
  final String tableName;
  final String recordId;
  final String action;
  final String? data;
  final DateTime createdAt;
  final DateTime? syncedAt;
  final String status;

  const SyncRecord({
    required this.id,
    required this.tableName,
    required this.recordId,
    required this.action,
    this.data,
    required this.createdAt,
    this.syncedAt,
    this.status = 'pending',
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'table_name': tableName,
    'record_id': recordId,
    'action': action,
    'data': data,
    'created_at': createdAt.toIso8601String(),
    'synced_at': syncedAt?.toIso8601String(),
    'status': status,
  };

  factory SyncRecord.fromMap(Map<String, dynamic> map) => SyncRecord(
    id: map['id'] as String,
    tableName: map['table_name'] as String,
    recordId: map['record_id'] as String,
    action: map['action'] as String,
    data: map['data'] as String?,
    createdAt: DateTime.parse(map['created_at'] as String),
    syncedAt: map['synced_at'] != null ? DateTime.parse(map['synced_at'] as String) : null,
    status: map['status'] as String? ?? 'pending',
  );
}
