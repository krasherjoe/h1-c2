import 'tracking_model.dart';

/// 送り状種別
enum LabelType {
  yamatoNeko('ヤマトネコポス', 'yamato'),
  yamatoCool('ヤマトクール便', 'yamato'),
  sagawa('佐川急便', 'sagawa'),
  jpPostYuupack('ゆうパック', 'jp_post'),
  jpPostLetter('レターパック', 'jp_post'),
  generic('汎用', 'generic');

  final String displayName;
  final String carrier;

  const LabelType(this.displayName, this.carrier);
  
  String get name => toString().split('.').last;
}

/// 送り状
class ShippingLabel {
  final String id;
  final Carrier carrier;
  final LabelType labelType;
  final String trackingNumber;
  final String senderName;
  final String senderZip;
  final String senderAddress;
  final String senderPhone;
  final String recipientName;
  final String recipientZip;
  final String recipientAddress;
  final String recipientPhone;
  final String? recipientCompany;
  final String? contents;
  final int? quantity;
  final int? weight;
  final String? serviceType;
  final String? codAmount;
  final DateTime createdAt;
  final DateTime? printedAt;
  
  // 紐付け先
  final String? entityType;
  final String? entityId;

  ShippingLabel({
    required this.id,
    required this.carrier,
    required this.labelType,
    required this.trackingNumber,
    required this.senderName,
    required this.senderZip,
    required this.senderAddress,
    required this.senderPhone,
    required this.recipientName,
    required this.recipientZip,
    required this.recipientAddress,
    required this.recipientPhone,
    this.recipientCompany,
    this.contents,
    this.quantity,
    this.weight,
    this.serviceType,
    this.codAmount,
    required this.createdAt,
    this.printedAt,
    this.entityType,
    this.entityId,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'carrier': carrier.name,
      'label_type': labelType.name,
      'tracking_number': trackingNumber,
      'sender_name': senderName,
      'sender_zip': senderZip,
      'sender_address': senderAddress,
      'sender_phone': senderPhone,
      'recipient_name': recipientName,
      'recipient_zip': recipientZip,
      'recipient_address': recipientAddress,
      'recipient_phone': recipientPhone,
      'recipient_company': recipientCompany,
      'contents': contents,
      'quantity': quantity,
      'weight': weight,
      'service_type': serviceType,
      'cod_amount': codAmount,
      'created_at': createdAt.toIso8601String(),
      'printed_at': printedAt?.toIso8601String(),
      'entity_type': entityType,
      'entity_id': entityId,
    };
  }

  factory ShippingLabel.fromMap(Map<String, dynamic> map) {
    return ShippingLabel(
      id: map['id'] as String,
      carrier: Carrier.values.firstWhere((c) => c.name == map['carrier']),
      labelType: LabelType.values.firstWhere((l) => l.name == map['label_type']),
      trackingNumber: map['tracking_number'] as String,
      senderName: map['sender_name'] as String,
      senderZip: map['sender_zip'] as String,
      senderAddress: map['sender_address'] as String,
      senderPhone: map['sender_phone'] as String,
      recipientName: map['recipient_name'] as String,
      recipientZip: map['recipient_zip'] as String,
      recipientAddress: map['recipient_address'] as String,
      recipientPhone: map['recipient_phone'] as String,
      recipientCompany: map['recipient_company'] as String?,
      contents: map['contents'] as String?,
      quantity: map['quantity'] as int?,
      weight: map['weight'] as int?,
      serviceType: map['service_type'] as String?,
      codAmount: map['cod_amount'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      printedAt: map['printed_at'] != null ? DateTime.parse(map['printed_at'] as String) : null,
      entityType: map['entity_type'] as String?,
      entityId: map['entity_id'] as String?,
    );
  }

  ShippingLabel copyWith({
    String? id,
    Carrier? carrier,
    LabelType? labelType,
    String? trackingNumber,
    String? senderName,
    String? senderZip,
    String? senderAddress,
    String? senderPhone,
    String? recipientName,
    String? recipientZip,
    String? recipientAddress,
    String? recipientPhone,
    String? recipientCompany,
    String? contents,
    int? quantity,
    int? weight,
    String? serviceType,
    String? codAmount,
    DateTime? createdAt,
    DateTime? printedAt,
    String? entityType,
    String? entityId,
  }) {
    return ShippingLabel(
      id: id ?? this.id,
      carrier: carrier ?? this.carrier,
      labelType: labelType ?? this.labelType,
      trackingNumber: trackingNumber ?? this.trackingNumber,
      senderName: senderName ?? this.senderName,
      senderZip: senderZip ?? this.senderZip,
      senderAddress: senderAddress ?? this.senderAddress,
      senderPhone: senderPhone ?? this.senderPhone,
      recipientName: recipientName ?? this.recipientName,
      recipientZip: recipientZip ?? this.recipientZip,
      recipientAddress: recipientAddress ?? this.recipientAddress,
      recipientPhone: recipientPhone ?? this.recipientPhone,
      recipientCompany: recipientCompany ?? this.recipientCompany,
      contents: contents ?? this.contents,
      quantity: quantity ?? this.quantity,
      weight: weight ?? this.weight,
      serviceType: serviceType ?? this.serviceType,
      codAmount: codAmount ?? this.codAmount,
      createdAt: createdAt ?? this.createdAt,
      printedAt: printedAt ?? this.printedAt,
      entityType: entityType ?? this.entityType,
      entityId: entityId ?? this.entityId,
    );
  }
}
