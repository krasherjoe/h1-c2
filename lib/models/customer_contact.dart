class CustomerContact {
  final String id;
  final String customerId;
  final String? email;
  final String? tel;
  final String? address;
  final int version;
  final bool isActive;
  final DateTime createdAt;

  CustomerContact({
    required this.id,
    required this.customerId,
    this.email,
    this.tel,
    this.address,
    required this.version,
    this.isActive = true,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory CustomerContact.fromMap(Map<String, dynamic> map) {
    return CustomerContact(
      id: map['id'],
      customerId: map['customer_id'],
      email: map['email'],
      tel: map['tel'],
      address: map['address'],
      version: map['version'],
      isActive: (map['is_active'] ?? 0) == 1,
      createdAt: DateTime.parse(map['created_at']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'customer_id': customerId,
      'email': email,
      'tel': tel,
      'address': address,
      'version': version,
      'is_active': isActive ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
