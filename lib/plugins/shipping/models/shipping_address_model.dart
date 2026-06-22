/// 送付先
class ShippingAddress {
  final String id;
  final String name;
  final String company;
  final String zip;
  final String address;
  final String phone;
  final bool isDefault;

  ShippingAddress({
    required this.id,
    required this.name,
    this.company = '',
    required this.zip,
    required this.address,
    required this.phone,
    this.isDefault = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'company': company,
      'zip': zip,
      'address': address,
      'phone': phone,
      'is_default': isDefault ? 1 : 0,
    };
  }

  factory ShippingAddress.fromMap(Map<String, dynamic> map) {
    return ShippingAddress(
      id: map['id'] as String,
      name: map['name'] as String,
      company: map['company'] as String? ?? '',
      zip: map['zip'] as String,
      address: map['address'] as String,
      phone: map['phone'] as String,
      isDefault: (map['is_default'] as int?) == 1,
    );
  }

  ShippingAddress copyWith({
    String? id,
    String? name,
    String? company,
    String? zip,
    String? address,
    String? phone,
    bool? isDefault,
  }) {
    return ShippingAddress(
      id: id ?? this.id,
      name: name ?? this.name,
      company: company ?? this.company,
      zip: zip ?? this.zip,
      address: address ?? this.address,
      phone: phone ?? this.phone,
      isDefault: isDefault ?? this.isDefault,
    );
  }
}
