class SupplierProduct {
  final String id;
  final String supplierId;
  final String name;
  final String? variant;
  final String? janCode;
  final int wholesalePrice;
  final int retailPrice;
  final String? orderUnit;
  final String? manufacturer;
  final String? subCategory;
  final String? categoryPath;
  final String createdAt;

  SupplierProduct({
    required this.id,
    required this.supplierId,
    required this.name,
    this.variant,
    this.janCode,
    this.wholesalePrice = 0,
    this.retailPrice = 0,
    this.orderUnit,
    this.manufacturer,
    this.subCategory,
    this.categoryPath,
    String? createdAt,
  }) : createdAt = createdAt ?? DateTime.now().toIso8601String();

  String get fullName => variant != null && variant!.isNotEmpty ? '$name $variant' : name;

  Map<String, dynamic> toMap() => {
    'id': id,
    'supplier_id': supplierId,
    'name': name,
    'variant': variant,
    'jan_code': janCode,
    'wholesale_price': wholesalePrice,
    'retail_price': retailPrice,
    'order_unit': orderUnit,
    'manufacturer': manufacturer,
    'sub_category': subCategory,
    'category_path': categoryPath,
    'created_at': createdAt,
  };

  factory SupplierProduct.fromMap(Map<String, dynamic> map) => SupplierProduct(
    id: map['id'] as String,
    supplierId: map['supplier_id'] as String,
    name: map['name'] as String? ?? '',
    variant: map['variant'] as String?,
    janCode: map['jan_code'] as String?,
    wholesalePrice: (map['wholesale_price'] as num?)?.toInt() ?? 0,
    retailPrice: (map['retail_price'] as num?)?.toInt() ?? 0,
    orderUnit: map['order_unit'] as String?,
    manufacturer: map['manufacturer'] as String?,
    subCategory: map['sub_category'] as String?,
    categoryPath: map['category_path'] as String?,
    createdAt: map['created_at'] as String? ?? '',
  );
}
