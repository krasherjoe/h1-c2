import 'database_helper.dart';

class TrackingEvent {
  final String id;
  final String sourceType;
  final String sourceId;
  final String status;
  final String? location;
  final String? description;
  final DateTime eventTime;
  final DateTime createdAt;

  const TrackingEvent({
    required this.id,
    required this.sourceType,
    required this.sourceId,
    required this.status,
    this.location,
    this.description,
    required this.eventTime,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'source_type': sourceType,
    'source_id': sourceId,
    'status': status,
    'location': location,
    'description': description,
    'event_time': eventTime.toIso8601String(),
    'created_at': createdAt.toIso8601String(),
  };

  factory TrackingEvent.fromMap(Map<String, dynamic> m) => TrackingEvent(
    id: m['id'] as String,
    sourceType: m['source_type'] as String,
    sourceId: m['source_id'] as String,
    status: m['status'] as String,
    location: m['location'] as String?,
    description: m['description'] as String?,
    eventTime: DateTime.tryParse(m['event_time'] as String? ?? '') ?? DateTime.now(),
    createdAt: DateTime.tryParse(m['created_at'] as String? ?? '') ?? DateTime.now(),
  );

  String get statusLabel {
    if (status == 'pending') return '準備中';
    if (status == 'scanned') return '発送';
    if (status == 'in_transit') return '輸送中';
    if (status == 'out_for_delivery') return '配達中';
    if (status == 'delivered') return '配達完了';
    if (status == 'exception') return '異常';
    return status;
  }
}

class TrackingService {
  static final TrackingService instance = TrackingService._();
  TrackingService._();

  final _db = DatabaseHelper();

  Future<List<TrackingEvent>> fetchEvents(String sourceType, String sourceId) async {
    final db = await _db.database;
    final maps = await db.query('tracking_events',
      where: 'source_type = ? AND source_id = ?',
      whereArgs: [sourceType, sourceId],
      orderBy: 'event_time DESC',
    );
    return maps.map(TrackingEvent.fromMap).toList();
  }

  Future<void> addEvent(String sourceType, String sourceId, String status, {String? location, String? description}) async {
    final db = await _db.database;
    final now = DateTime.now();
    await db.insert('tracking_events', {
      'id': '${sourceType}_${sourceId}_${now.millisecondsSinceEpoch}',
      'source_type': sourceType,
      'source_id': sourceId,
      'status': status,
      'location': location,
      'description': description,
      'event_time': now.toIso8601String(),
      'created_at': now.toIso8601String(),
    });
  }

  static String detectCourier(String trackingNumber) {
    final t = trackingNumber.replaceAll(RegExp(r'[\s-]'), '');
    if (t.length == 11 || t.length == 12 && int.tryParse(t) != null) {
      return 'yamato';
    }
    if (t.length == 12 && RegExp(r'^\d{12}$').hasMatch(t)) {
      return 'sagawa';
    }
    if (RegExp(r'^\d{11,20}$').hasMatch(t)) {
      return 'jppost';
    }
    if (RegExp(r'^[A-Z]{2}\d{9}[A-Z]{2}$').hasMatch(t)) {
      return 'fedex';
    }
    if (RegExp(r'^1Z\w{16}$').hasMatch(t)) {
      return 'ups';
    }
    if (RegExp(r'^\d{10}$').hasMatch(t)) {
      return 'seino';
    }
    return 'other';
  }

  static String courierLabel(String courier) {
    return switch (courier) {
      'yamato' => 'ヤマト運輸',
      'sagawa' => '佐川急便',
      'jppost' => '日本郵便',
      'fedex' => 'FedEx',
      'ups' => 'UPS',
      'seino' => '西濃運輸',
      _ => courier,
    };
  }

  static String? trackingUrl(String courier, String trackingNumber) {
    final t = Uri.encodeComponent(trackingNumber);
    return switch (courier) {
      'yamato' => 'https://toi.kuronekoyamato.co.jp/cgi-bin/tneko',
      'sagawa' => 'https://k2k.sagawa-exp.co.jp/p/sagawa/web/okurijo/okurijo.jsp?no=$t',
      'jppost' => 'https://trackings.post.japanpost.jp/services/srv/search/input?searchKind=S002&locale=ja&P001=$t',
      'fedex' => 'https://www.fedex.com/fedextrack/?trknbr=$t',
      'ups' => 'https://www.ups.com/track?tracknum=$t',
      'seino' => 'https://track.seino.co.jp/cgi-bin/gnp/TrackingServlet?butsuryuCd=$t',
      _ => null,
    };
  }
}
