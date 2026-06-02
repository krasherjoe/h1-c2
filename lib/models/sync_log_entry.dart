class SyncLogEntry {
  final int? id;
  final String entityType;
  final String entityId;
  final String action;
  final String? parentId;
  final String data;
  final String deviceId;
  final DateTime? syncedAt;
  final DateTime createdAt;

  SyncLogEntry({
    this.id,
    required this.entityType,
    required this.entityId,
    required this.action,
    this.parentId,
    required this.data,
    required this.deviceId,
    this.syncedAt,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
    if (id != null) 'id': id,
    'entity_type': entityType,
    'entity_id': entityId,
    'action': action,
    'parent_id': parentId,
    'data': data,
    'device_id': deviceId,
    'synced_at': syncedAt?.toIso8601String(),
    'created_at': createdAt.toIso8601String(),
  };

  factory SyncLogEntry.fromMap(Map<String, dynamic> map) => SyncLogEntry(
    id: map['id'] as int?,
    entityType: map['entity_type'] as String,
    entityId: map['entity_id'] as String,
    action: map['action'] as String,
    parentId: map['parent_id'] as String?,
    data: map['data'] as String,
    deviceId: map['device_id'] as String,
    syncedAt: map['synced_at'] != null ? DateTime.parse(map['synced_at'] as String) : null,
    createdAt: DateTime.parse(map['created_at'] as String),
  );

  SyncLogEntry copyWith({
    int? id,
    String? entityType,
    String? entityId,
    String? action,
    String? parentId,
    String? data,
    String? deviceId,
    DateTime? syncedAt,
    DateTime? createdAt,
  }) => SyncLogEntry(
    id: id ?? this.id,
    entityType: entityType ?? this.entityType,
    entityId: entityId ?? this.entityId,
    action: action ?? this.action,
    parentId: parentId ?? this.parentId,
    data: data ?? this.data,
    deviceId: deviceId ?? this.deviceId,
    syncedAt: syncedAt ?? this.syncedAt,
    createdAt: createdAt ?? this.createdAt,
  );
}
