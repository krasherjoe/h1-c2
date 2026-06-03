class PriceEntry {
  final String id;
  final String year;
  final String? parentId;
  final String name;
  final int? unitPrice;
  final String? productId;
  final String? supplierId;
  final String? customerId;
  final String? notes;
  final int sortOrder;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isFolder => unitPrice == null;
  bool get isCustomerFolder => customerId != null && isFolder;

  const PriceEntry({
    required this.id,
    required this.year,
    this.parentId,
    required this.name,
    this.unitPrice,
    this.productId,
    this.supplierId,
    this.customerId,
    this.notes,
    this.sortOrder = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'year': year,
    'parent_id': parentId,
    'name': name,
    'unit_price': unitPrice,
    'product_id': productId,
    'supplier_id': supplierId,
    'customer_id': customerId,
    'notes': notes,
    'sort_order': sortOrder,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
  };

  factory PriceEntry.fromMap(Map<String, dynamic> map) => PriceEntry(
    id: map['id'] as String,
    year: map['year'] as String,
    parentId: map['parent_id'] as String?,
    name: map['name'] as String,
    unitPrice: map['unit_price'] as int?,
    productId: map['product_id'] as String?,
    supplierId: map['supplier_id'] as String?,
    customerId: map['customer_id'] as String?,
    notes: map['notes'] as String?,
    sortOrder: map['sort_order'] as int? ?? 0,
    createdAt: DateTime.parse(map['created_at'] as String),
    updatedAt: DateTime.parse(map['updated_at'] as String),
  );

  PriceEntry copyWith({
    String? id,
    String? year,
    String? parentId,
    String? name,
    int? unitPrice,
    bool? clearUnitPrice,
    String? productId,
    String? supplierId,
    String? customerId,
    bool? clearCustomerId,
    String? notes,
    int? sortOrder,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => PriceEntry(
    id: id ?? this.id,
    year: year ?? this.year,
    parentId: clearUnitPrice == true ? null : (parentId ?? this.parentId),
    name: name ?? this.name,
    unitPrice: clearUnitPrice == true ? null : (unitPrice ?? this.unitPrice),
    productId: productId ?? this.productId,
    supplierId: supplierId ?? this.supplierId,
    customerId: clearCustomerId == true ? null : (customerId ?? this.customerId),
    notes: notes ?? this.notes,
    sortOrder: sortOrder ?? this.sortOrder,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
}
