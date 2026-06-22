import 'package:intl/intl.dart';

/// copyWith でフィールドを明示的に null にクリアする際に使うセンチネル
const Object _kProductUnset = Object();

/// 電子帳簿保存法対応 - バージョン管理フィールド
extension ProductVersioning on Product {
  /// 現在のバージョンか判定
  bool get isCurrent => isCurrentFlag;

  /// バージョンハッシュ（改ざん検出用）
  String? get contentHashValue => contentHash;

  /// 前バージョンハッシュ（チェーンリンク）
  String? get previousHashValue => previousHash;
}

class Product {
  final String id;
  final String name;
  final int defaultUnitPrice;
  final bool defaultUnitPriceIsTaxInclusive;
  final int wholesalePrice;
  final bool wholesalePriceIsTaxInclusive;
  final String? barcode;
  final String? modelNumber;
  final String? manufacturer;
  final String? category;
  final String? categoryId;
  final String? supplierId;
  final String? supplierName;
  final int? stockQuantity;
  final String? odooId;
  final bool isLocked;
  final bool isHidden;
  final String? parentId;

  // JAN/MOOV標準対応フィールド
  final String? productNameKana;
  final String? classificationCode;
  final String? divisionCode;
  final String? manufacturerCode;

  final DateTime? validFrom;
  final DateTime? validTo;
  final bool isCurrentFlag;
  final int version;
  final String? contentHash;
  final String? previousHash;

  Product({
    required this.id,
    required this.name,
    this.defaultUnitPrice = 0,
    this.defaultUnitPriceIsTaxInclusive = false,
    this.wholesalePrice = 0,
    this.wholesalePriceIsTaxInclusive = false,
    this.barcode,
    this.modelNumber,
    this.manufacturer,
    this.category,
    this.categoryId,
    this.supplierId,
    this.supplierName,
    this.stockQuantity,
    this.odooId,
    this.isLocked = false,
    this.isHidden = false,
    this.parentId,
    this.productNameKana,
    this.classificationCode,
    this.divisionCode,
    this.manufacturerCode,
    this.validFrom,
    this.validTo,
    this.isCurrentFlag = true,
    this.version = 1,
    this.contentHash,
    this.previousHash,
  });

  bool get isVariant => parentId != null;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'default_unit_price': defaultUnitPrice,
      'default_unit_price_is_tax_inclusive': defaultUnitPriceIsTaxInclusive ? 1 : 0,
      'wholesale_price': wholesalePrice,
      'wholesale_price_is_tax_inclusive': wholesalePriceIsTaxInclusive ? 1 : 0,
      'barcode': barcode,
      'model_number': modelNumber,
      'manufacturer': manufacturer,
      'category': category,
      'category_id': categoryId,
      'supplier_id': supplierId,
      'supplier_name': supplierName,
      'stock_quantity': stockQuantity,
      'is_locked': isLocked ? 1 : 0,
      'odoo_id': odooId,
      'is_hidden': isHidden ? 1 : 0,
      'parent_id': parentId,
      'product_name_kana': productNameKana,
      'classification_code': classificationCode,
      'division_code': divisionCode,
      'manufacturer_code': manufacturerCode,
      'valid_from': validFrom?.toIso8601String(),
      'valid_to': validTo?.toIso8601String(),
      'is_current': isCurrentFlag ? 1 : 0,
      'version': version,
      'content_hash': contentHash,
      'previous_hash': previousHash,
      'updated_at': DateTime.now().toIso8601String(),
    };
  }

  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      id: map['id'],
      name: map['name'],
      defaultUnitPrice: map['default_unit_price'] ?? 0,
      defaultUnitPriceIsTaxInclusive: (map['default_unit_price_is_tax_inclusive'] ?? 0) == 1,
      wholesalePrice: map['wholesale_price'] ?? 0,
      wholesalePriceIsTaxInclusive: (map['wholesale_price_is_tax_inclusive'] ?? 0) == 1,
      barcode: map['barcode'],
      modelNumber: map['model_number'] as String?,
      manufacturer: map['manufacturer'] as String?,
      category: map['category'],
      categoryId: map['category_id'],
      supplierId: map['supplier_id'] as String?,
      supplierName: map['supplier_name'] as String?,
      stockQuantity: map['stock_quantity'],
      isLocked: (map['is_locked'] ?? 0) == 1,
      odooId: map['odoo_id'],
      isHidden: (map['is_hidden'] ?? 0) == 1,
      parentId: map['parent_id'] as String?,
      productNameKana: map['product_name_kana'] as String?,
      classificationCode: map['classification_code'] as String?,
      divisionCode: map['division_code'] as String?,
      manufacturerCode: map['manufacturer_code'] as String?,
      validFrom: map['valid_from'] != null
          ? DateTime.parse(map['valid_from'])
          : null,
      validTo: map['valid_to'] != null ? DateTime.parse(map['valid_to']) : null,
      isCurrentFlag: (map['is_current'] ?? 1) == 1,
      version: map['version'] ?? 1,
      contentHash: map['content_hash'],
      previousHash: map['previous_hash'],
    );
  }

  bool get isNonStockCategory {
    if (category == null || category!.isEmpty) return false;
    const nonStock = ['サポート', 'サービス'];
    return nonStock.contains(category!.trim());
  }

  Product copyWith({
    String? id,
    String? name,
    int? defaultUnitPrice,
    bool? defaultUnitPriceIsTaxInclusive,
    int? wholesalePrice,
    bool? wholesalePriceIsTaxInclusive,
    String? barcode,
    String? modelNumber,
    String? manufacturer,
    String? category,
    Object? categoryId = _kProductUnset,
    String? supplierId,
    String? supplierName,
    int? stockQuantity,
    String? odooId,
    bool? isLocked,
    bool? isHidden,
    String? parentId,
    String? productNameKana,
    String? classificationCode,
    String? divisionCode,
    String? manufacturerCode,
    DateTime? validFrom,
    DateTime? validTo,
    bool? isCurrentFlag,
    int? version,
    String? contentHash,
    String? previousHash,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      defaultUnitPrice: defaultUnitPrice ?? this.defaultUnitPrice,
      defaultUnitPriceIsTaxInclusive: defaultUnitPriceIsTaxInclusive ?? this.defaultUnitPriceIsTaxInclusive,
      wholesalePrice: wholesalePrice ?? this.wholesalePrice,
      wholesalePriceIsTaxInclusive: wholesalePriceIsTaxInclusive ?? this.wholesalePriceIsTaxInclusive,
      barcode: barcode ?? this.barcode,
      modelNumber: modelNumber ?? this.modelNumber,
      manufacturer: manufacturer ?? this.manufacturer,
      category: category ?? this.category,
      categoryId: identical(categoryId, _kProductUnset)
          ? this.categoryId
          : categoryId as String?,
      supplierId: supplierId ?? this.supplierId,
      supplierName: supplierName ?? this.supplierName,
      stockQuantity: stockQuantity ?? this.stockQuantity,
      odooId: odooId ?? this.odooId,
      isLocked: isLocked ?? this.isLocked,
      isHidden: isHidden ?? this.isHidden,
      parentId: parentId ?? this.parentId,
      productNameKana: productNameKana ?? this.productNameKana,
      classificationCode: classificationCode ?? this.classificationCode,
      divisionCode: divisionCode ?? this.divisionCode,
      manufacturerCode: manufacturerCode ?? this.manufacturerCode,
      validFrom: validFrom ?? this.validFrom,
      validTo: validTo ?? this.validTo,
      isCurrentFlag: isCurrentFlag ?? this.isCurrentFlag,
      version: version ?? this.version,
      contentHash: contentHash ?? this.contentHash,
      previousHash: previousHash ?? this.previousHash,
    );
  }
}

class ProductOptionGroup {
  final String id;
  final String productId;
  final String name;
  final String priceMode;
  final int sortOrder;

  const ProductOptionGroup({
    required this.id,
    required this.productId,
    required this.name,
    this.priceMode = 'add',
    this.sortOrder = 0,
  });

  bool get isAbsolute => priceMode == 'absolute';

  Map<String, dynamic> toMap() => {
    'id': id,
    'product_id': productId,
    'name': name,
    'price_mode': priceMode,
    'sort_order': sortOrder,
  };

  factory ProductOptionGroup.fromMap(Map<String, dynamic> map) => ProductOptionGroup(
    id: map['id'],
    productId: map['product_id'],
    name: map['name'],
    priceMode: map['price_mode'] ?? 'add',
    sortOrder: map['sort_order'] ?? 0,
  );

  ProductOptionGroup copyWith({String? id, String? productId, String? name, String? priceMode, int? sortOrder}) =>
    ProductOptionGroup(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      name: name ?? this.name,
      priceMode: priceMode ?? this.priceMode,
      sortOrder: sortOrder ?? this.sortOrder,
    );
}

class ProductOptionValue {
  final String id;
  final String groupId;
  final String value;
  final int priceModifier;
  final int sortOrder;

  const ProductOptionValue({
    required this.id,
    required this.groupId,
    required this.value,
    this.priceModifier = 0,
    this.sortOrder = 0,
  });

  String priceLabel(ProductOptionGroup group) {
    if (priceModifier == 0) return group.isAbsolute ? '¥---' : '±¥0';
    final p = NumberFormat('#,###').format(priceModifier.abs());
    return group.isAbsolute ? '¥$p' : '±¥$p';
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'group_id': groupId,
    'value': value,
    'price_modifier': priceModifier,
    'sort_order': sortOrder,
  };

  factory ProductOptionValue.fromMap(Map<String, dynamic> map) => ProductOptionValue(
    id: map['id'],
    groupId: map['group_id'],
    value: map['value'],
    priceModifier: map['price_modifier'] ?? 0,
    sortOrder: map['sort_order'] ?? 0,
  );

  ProductOptionValue copyWith({String? id, String? groupId, String? value, int? priceModifier, int? sortOrder}) =>
    ProductOptionValue(
      id: id ?? this.id,
      groupId: groupId ?? this.groupId,
      value: value ?? this.value,
      priceModifier: priceModifier ?? this.priceModifier,
      sortOrder: sortOrder ?? this.sortOrder,
    );
}

class CustomerProductPrice {
  final String customerId;
  final String productId;
  final int price;

  const CustomerProductPrice({
    required this.customerId,
    required this.productId,
    required this.price,
  });

  Map<String, dynamic> toMap() => {
    'customer_id': customerId,
    'product_id': productId,
    'price': price,
  };

  factory CustomerProductPrice.fromMap(Map<String, dynamic> map) => CustomerProductPrice(
    customerId: map['customer_id'],
    productId: map['product_id'],
    price: map['price'],
  );

  CustomerProductPrice copyWith({String? customerId, String? productId, int? price}) =>
    CustomerProductPrice(
      customerId: customerId ?? this.customerId,
      productId: productId ?? this.productId,
      price: price ?? this.price,
    );
}
