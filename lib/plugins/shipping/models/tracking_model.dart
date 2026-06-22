/// 追跡方向
enum TrackingDirection {
  outbound('送信', '発送'),
  inbound('受信', '受取');

  final String displayName;
  final String label;

  const TrackingDirection(this.displayName, this.label);
  
  String get name => toString().split('.').last;
}

/// 追跡ステータス
enum TrackingStatus {
  notShipped('未発送', 0),
  pickedUp('集荷済み', 10),
  inTransit('輸送中', 25),
  outForDelivery('配達中', 75),
  delivered('配達済み', 100),
  failed('配達失敗', 0),
  returned('返送', 0);

  final String displayName;
  final int progress;

  const TrackingStatus(this.displayName, this.progress);
  
  String get name => toString().split('.').last;
}

/// 宅配便会社
enum Carrier {
  yamato('ヤマト', 'クロネコヤマト'),
  sagawa('佐川急便', '佐川急便'),
  jpPost('日本郵便', '日本郵便'),
  other('その他', null);

  final String displayName;
  final String? apiName;

  const Carrier(this.displayName, this.apiName);
  
  String get name => toString().split('.').last;
}

/// 追跡番号
class Tracking {
  final String id;
  final String trackingNumber;
  final Carrier carrier;
  final TrackingDirection direction;
  final TrackingStatus status;
  final DateTime? shippedAt;
  final DateTime? deliveredAt;
  final DateTime? trackingUpdatedAt;
  final String? notes;
  
  // 紐付け先（任意）
  final String? entityType;
  final String? entityId;
  final String? entityName;
  
  // 連携送り状ID（任意）
  final String? labelId;

  Tracking({
    required this.id,
    required this.trackingNumber,
    required this.carrier,
    required this.direction,
    required this.status,
    this.shippedAt,
    this.deliveredAt,
    this.trackingUpdatedAt,
    this.notes,
    this.entityType,
    this.entityId,
    this.entityName,
    this.labelId,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'tracking_number': trackingNumber,
      'carrier': carrier.name,
      'direction': direction.name,
      'status': status.name,
      'shipped_at': shippedAt?.toIso8601String(),
      'delivered_at': deliveredAt?.toIso8601String(),
      'tracking_updated_at': trackingUpdatedAt?.toIso8601String(),
      'notes': notes,
      'entity_type': entityType,
      'entity_id': entityId,
      'entity_name': entityName,
      'label_id': labelId,
    };
  }

  factory Tracking.fromMap(Map<String, dynamic> map) {
    return Tracking(
      id: map['id'] as String,
      trackingNumber: map['tracking_number'] as String,
      carrier: Carrier.values.firstWhere((c) => c.name == map['carrier']),
      direction: TrackingDirection.values.firstWhere((d) => d.name == map['direction']),
      status: TrackingStatus.values.firstWhere((s) => s.name == map['status']),
      shippedAt: map['shipped_at'] != null ? DateTime.parse(map['shipped_at'] as String) : null,
      deliveredAt: map['delivered_at'] != null ? DateTime.parse(map['delivered_at'] as String) : null,
      trackingUpdatedAt: map['tracking_updated_at'] != null ? DateTime.parse(map['tracking_updated_at'] as String) : null,
      notes: map['notes'] as String?,
      entityType: map['entity_type'] as String?,
      entityId: map['entity_id'] as String?,
      entityName: map['entity_name'] as String?,
      labelId: map['label_id'] as String?,
    );
  }

  Tracking copyWith({
    String? id,
    String? trackingNumber,
    Carrier? carrier,
    TrackingDirection? direction,
    TrackingStatus? status,
    DateTime? shippedAt,
    DateTime? deliveredAt,
    DateTime? trackingUpdatedAt,
    String? notes,
    String? entityType,
    String? entityId,
    String? entityName,
    String? labelId,
  }) {
    return Tracking(
      id: id ?? this.id,
      trackingNumber: trackingNumber ?? this.trackingNumber,
      carrier: carrier ?? this.carrier,
      direction: direction ?? this.direction,
      status: status ?? this.status,
      shippedAt: shippedAt ?? this.shippedAt,
      deliveredAt: deliveredAt ?? this.deliveredAt,
      trackingUpdatedAt: trackingUpdatedAt ?? this.trackingUpdatedAt,
      notes: notes ?? this.notes,
      entityType: entityType ?? this.entityType,
      entityId: entityId ?? this.entityId,
      entityName: entityName ?? this.entityName,
      labelId: labelId ?? this.labelId,
    );
  }
}
