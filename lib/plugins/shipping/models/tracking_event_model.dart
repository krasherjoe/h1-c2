/// 追跡履歴イベント
class TrackingEvent {
  final String id;
  final String trackingId;
  final String status;
  final String location;
  final DateTime timestamp;
  final String? description;

  TrackingEvent({
    required this.id,
    required this.trackingId,
    required this.status,
    required this.location,
    required this.timestamp,
    this.description,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'tracking_id': trackingId,
      'status': status,
      'location': location,
      'timestamp': timestamp.toIso8601String(),
      'description': description,
    };
  }

  factory TrackingEvent.fromMap(Map<String, dynamic> map) {
    return TrackingEvent(
      id: map['id'] as String,
      trackingId: map['tracking_id'] as String,
      status: map['status'] as String,
      location: map['location'] as String,
      timestamp: DateTime.parse(map['timestamp'] as String),
      description: map['description'] as String?,
    );
  }
}
