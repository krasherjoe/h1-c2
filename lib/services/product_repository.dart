import 'package:flutter/foundation.dart' show debugPrint;
import 'package:uuid/uuid.dart';
import 'package:sqflite/sqflite.dart';
import '../models/product_model.dart';
import 'database_helper.dart';
import 'activity_log_repository.dart';
import 'barcode_utils.dart';

class ResolvedPrice {
  final int unitPrice;
  final PriceSource source;
  final int? rankDiscountRate;
  final String? note;

  const ResolvedPrice({
    required this.unitPrice,
    required this.source,
    this.rankDiscountRate,
    this.note,
  });
}

enum PriceSource {
  master,
  variantMaster,
  customerSpecific,
  customerSpecificParent,
  rankDiscount,
}

class ProductRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final ActivityLogRepository _logRepo = ActivityLogRepository();

  Future<Product?> getProduct(String id) async {
    try {
      final db = await _dbHelper.database;
      final maps = await db.rawQuery('''
        SELECT p.*, COALESCE(mh.is_hidden, p.is_hidden, 0) AS is_hidden
        FROM products p
        LEFT JOIN master_hidden mh ON mh.master_type = 'product' AND mh.master_id = p.id
        WHERE p.id = ? AND COALESCE(p.is_current, 1) = 1
          AND COALESCE(p.valid_to, '9999-12-31') > datetime('now')
      ''', [id]);
      if (maps.isEmpty) return null;
      return Product.fromMap(maps.first);
    } catch (e) {
      debugPrint('[ProductRepo] getProduct error: $e');
      rethrow;
    }
  }

  Future<List<Product>> getAllProducts({bool includeHidden = false}) async {
    try {
      final db = await _dbHelper.database;
      final String baseWhere = "WHERE COALESCE(p.is_current, 1) = 1 AND COALESCE(p.valid_to, '9999-12-31') > datetime('now')";
      final String where = includeHidden
          ? baseWhere
          : '$baseWhere AND COALESCE(mh.is_hidden, p.is_hidden, 0) = 0';
      final List<Map<String, dynamic>> maps = await db.rawQuery('''
        SELECT p.*, COALESCE(mh.is_hidden, p.is_hidden, 0) AS is_hidden
        FROM products p
        LEFT JOIN master_hidden mh ON mh.master_type = 'product' AND mh.master_id = p.id
        $where
        ORDER BY ${includeHidden ? 'p.id DESC' : 'p.name ASC'}
      ''');

      return List.generate(maps.length, (i) => Product.fromMap(maps[i]));
    } catch (e) {
      debugPrint('[ProductRepo] getAllProducts error: $e');
      rethrow;
    }
  }

  Future<List<Product>> fetchByCategory(String categoryId, {String query = ''}) async {
    try {
      final db = await _dbHelper.database;
      final List<Map<String, dynamic>> maps;
      if (query.isNotEmpty) {
        maps = await db.rawQuery('''
          SELECT p.*, COALESCE(mh.is_hidden, p.is_hidden, 0) AS is_hidden
          FROM products p
          LEFT JOIN master_hidden mh ON mh.master_type = 'product' AND mh.master_id = p.id
          WHERE p.category_id = ?
            AND COALESCE(p.is_current, 1) = 1
            AND COALESCE(p.valid_to, '9999-12-31') > datetime('now')
            AND (p.name LIKE ? OR p.barcode LIKE ?)
          ORDER BY p.name ASC
        ''', [categoryId, '%$query%', '%$query%']);
      } else {
        maps = await db.rawQuery('''
          SELECT p.*, COALESCE(mh.is_hidden, p.is_hidden, 0) AS is_hidden
          FROM products p
          LEFT JOIN master_hidden mh ON mh.master_type = 'product' AND mh.master_id = p.id
          WHERE p.category_id = ?
            AND COALESCE(p.is_current, 1) = 1
            AND COALESCE(p.valid_to, '9999-12-31') > datetime('now')
          ORDER BY p.name ASC
        ''', [categoryId]);
      }
      return maps.map((m) => Product.fromMap(m)).toList();
    } catch (e) {
      debugPrint('[ProductRepo] fetchByCategory error: $e');
      rethrow;
    }
  }

  Future<List<Product>> searchProducts(
    String query, {
    bool includeHidden = false,
  }) async {
    try {
      final db = await _dbHelper.database;
      final args = ['%$query%', '%$query%', '%$query%'];
      final String whereHidden = includeHidden
          ? ''
          : 'AND COALESCE(mh.is_hidden, p.is_hidden, 0) = 0';
      final List<Map<String, dynamic>> maps = await db.rawQuery('''
        SELECT p.*, COALESCE(mh.is_hidden, p.is_hidden, 0) AS is_hidden
        FROM products p
        LEFT JOIN master_hidden mh ON mh.master_type = 'product' AND mh.master_id = p.id
        WHERE COALESCE(p.is_current, 1) = 1
          AND COALESCE(p.valid_to, '9999-12-31') > datetime('now')
          AND (p.name LIKE ? OR p.barcode LIKE ? OR p.category LIKE ?)
        $whereHidden
        ORDER BY ${includeHidden ? 'p.id DESC' : 'p.name ASC'}
        LIMIT 50
      ''', args);
      return List.generate(maps.length, (i) => Product.fromMap(maps[i]));
    } catch (e) {
      debugPrint('[ProductRepo] searchProducts error: $e');
      rethrow;
    }
  }

  Future<Product?> getProductByBarcode(String barcode) async {
    try {
      final db = await _dbHelper.database;
      final maps = await db.rawQuery('''
        SELECT p.*, COALESCE(mh.is_hidden, p.is_hidden, 0) AS is_hidden
        FROM products p
        LEFT JOIN master_hidden mh ON mh.master_type = 'product' AND mh.master_id = p.id
        WHERE p.barcode = ? AND COALESCE(p.is_current, 1) = 1
          AND COALESCE(p.valid_to, '9999-12-31') > datetime('now')
        LIMIT 1
      ''', [barcode]);
      if (maps.isEmpty) return null;
      return Product.fromMap(maps.first);
    } catch (e) {
      debugPrint('[ProductRepo] getProductByBarcode error: $e');
      rethrow;
    }
  }

  Future<void> saveProduct(Product product) async {
    try {
      var adjusted = product;
      if (product.barcode != null && product.barcode!.isNotEmpty) {
        final raw = product.barcode!.replaceAll(RegExp(r'[\s-]'), '');
        final normalized = BarcodeUtils.normalize(raw);
        if (normalized == null) {
          throw FormatException('バーコードのチェックデジットが不正です: ${product.barcode}');
        }
        if (normalized != raw) {
          adjusted = product.copyWith(barcode: normalized);
        }
        final dbCheck = await _dbHelper.database;
        final dupRows = await dbCheck.query(
          'products',
          where: 'barcode = ? AND id != ? AND is_current = 1',
          whereArgs: [normalized, product.id],
          limit: 1,
        );
        if (dupRows.isNotEmpty) {
          throw ArgumentError('バーコード「$normalized」は別の商品ですでに使用されています');
        }
      }

      final db = await _dbHelper.database;

      await db.transaction((txn) async {
        final existing = await txn.query(
          'products',
          where: 'id = ? AND is_current = 1',
          whereArgs: [adjusted.id],
        );
        if (existing.isNotEmpty) {
          await txn.update(
            'products',
            {'is_current': 0, 'valid_to': DateTime.now().toIso8601String()},
            where: 'id = ? AND is_current = 1',
            whereArgs: [adjusted.id],
          );
        }
        final productMap = adjusted.toMap();
        productMap['is_current'] = 1;
        final currentVersion =
            (existing.isNotEmpty ? existing.first['version'] : 0) as int? ?? 0;
        productMap['version'] = currentVersion + 1;
        productMap['valid_from'] = DateTime.now().toIso8601String();
        productMap['valid_to'] = null;
        await txn.insert(
          'products',
          productMap,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      });

      await _logRepo.logAction(
        action: "SAVE_PRODUCT",
        targetType: "PRODUCT",
        targetId: adjusted.id,
        details:
            "商品名：${adjusted.name}, 単価：${adjusted.defaultUnitPrice}, カテゴリ：${adjusted.category ?? '未設定'} (version up)",
      );
    } catch (e) {
      debugPrint('[ProductRepo] saveProduct error: $e');
      rethrow;
    }
  }

  Future<void> deleteProduct(String id) async {
    try {
      final db = await _dbHelper.database;
      await db.transaction((txn) async {
        final references = await _checkProductReferences(txn, id);
        if (references.isNotEmpty) {
          throw ProductInUseException(id, references);
        }
        await txn.delete('products', where: 'id = ?', whereArgs: [id]);
      });

      await _logRepo.logAction(
        action: "DELETE_PRODUCT",
        targetType: "PRODUCT",
        targetId: id,
        details: "商品を完全削除しました",
      );
    } catch (e) {
      debugPrint('[ProductRepo] deleteProduct error: $e');
      rethrow;
    }
  }

  Future<List<String>> _checkProductReferences(DatabaseExecutor txn, String productId) async {
    final references = <String>[];
    for (final table in ['document_items', 'invoice_items', 'customer_product_prices']) {
      try {
        final rows = await txn.query(table, where: 'product_id = ?', whereArgs: [productId], limit: 1);
        if (rows.isNotEmpty) references.add(table);
      } catch (_) {}
    }
    try {
      final pur = await txn.query('purchase_items', where: 'product_id = ?', whereArgs: [productId], limit: 1);
      if (pur.isNotEmpty) references.add('purchase_items');
    } catch (_) {}
    try {
      final stk = await txn.query('warehouse_stock', where: 'product_id = ?', whereArgs: [productId], limit: 1);
      if (stk.isNotEmpty) references.add('warehouse_stock');
    } catch (_) {}
    return references;
  }

  Future<void> setHiddenProduct(String id, bool hidden) async {
    try {
      final db = await _dbHelper.database;
      await db.update(
        'products',
        {'is_hidden': hidden ? 1 : 0},
        where: 'id = ? AND is_current = 1',
        whereArgs: [id],
      );
      await _logRepo.logAction(
        action: hidden ? "HIDE_PRODUCT" : "UNHIDE_PRODUCT",
        targetType: "PRODUCT",
        targetId: id,
        details: hidden ? "商品を非表示にしました" : "商品を再表示しました",
      );
    } catch (e) {
      debugPrint('[ProductRepo] setHiddenProduct error: $e');
      rethrow;
    }
  }

  Future<void> setHidden(String id, bool hidden) async {
    try {
      final db = await _dbHelper.database;
      await db.insert('master_hidden', {
        'master_type': 'product',
        'master_id': id,
        'is_hidden': hidden ? 1 : 0,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      await _logRepo.logAction(
        action: hidden ? "HIDE_PRODUCT" : "UNHIDE_PRODUCT",
        targetType: "PRODUCT",
        targetId: id,
        details: hidden ? "商品を非表示にしました" : "商品を再表示しました",
      );
    } catch (e) {
      debugPrint('[ProductRepo] setHidden error: $e');
      rethrow;
    }
  }

  Future<void> updateStockQuantities(Map<String, int> adjustments) async {
    if (adjustments.isEmpty) return;
    try {
      final db = await _dbHelper.database;
      await db.transaction((txn) async {
        for (final entry in adjustments.entries) {
          await txn.update(
            'products',
            {'stock_quantity': entry.value},
            where: 'id = ?',
            whereArgs: [entry.key],
          );
        }
      });

      for (final entry in adjustments.entries) {
        await _logRepo.logAction(
          action: 'STOCKTAKE_ADJUST',
          targetType: 'PRODUCT',
          targetId: entry.key,
          details: '棚卸で在庫数を${entry.value}に更新',
        );
      }
    } catch (e) {
      debugPrint('[ProductRepo] updateStockQuantities error: $e');
      rethrow;
    }
  }

  /// 同じ商品名で複数の現行レコードがある場合、古い方を非現行化する
  Future<int> cleanupDuplicateVersions() async {
    try {
      final db = await _dbHelper.database;
      final products = await db.query(
        'products',
        where: 'is_current = 1',
      );

      final Map<String, List<Map<String, dynamic>>> grouped = {};
      for (final p in products) {
        final name = (p['name'] as String?)?.trim() ?? '';
        if (name.isEmpty) continue;
        grouped.putIfAbsent(name, () => []).add(p);
      }

      int fixedCount = 0;
      for (final entry in grouped.entries) {
        if (entry.value.length <= 1) continue;
        entry.value.sort((a, b) {
          final va = (a['version'] as int?) ?? 1;
          final vb = (b['version'] as int?) ?? 1;
          return va.compareTo(vb);
        });
        final Map<String, dynamic> newest = entry.value.last;
        for (int i = 0; i < entry.value.length - 1; i++) {
          final old = entry.value[i];
          await db.update(
            'products',
            {
              'is_current': 0,
              'is_hidden': 1,
              'valid_to': DateTime.now().toIso8601String(),
            },
            where: 'id = ?',
            whereArgs: [old['id']],
          );
          fixedCount++;
        }
        await db.insert('master_hidden', {
          'master_type': 'product',
          'master_id': newest['id'],
          'is_hidden': 0,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }

      if (fixedCount > 0) {
        await _logRepo.logAction(
          action: 'CLEANUP_PRODUCT_DUPLICATES',
          targetType: 'PRODUCT',
          targetId: null,
          details: '重複商品バージョンを$fixedCount件整理しました',
        );
      }
      return fixedCount;
    } catch (e) {
      debugPrint('[ProductRepo] cleanupDuplicateVersions error: $e');
      rethrow;
    }
  }

  // ===== バリエーション =====

  Future<List<Product>> getVariants(String parentId) async {
    try {
      final db = await _dbHelper.database;
      final maps = await db.rawQuery('''
        SELECT p.*, COALESCE(mh.is_hidden, p.is_hidden, 0) AS is_hidden
        FROM products p
        LEFT JOIN master_hidden mh ON mh.master_type = 'product' AND mh.master_id = p.id
        WHERE p.parent_id = ?
          AND COALESCE(p.is_current, 1) = 1
          AND COALESCE(p.valid_to, '9999-12-31') > datetime('now')
        ORDER BY p.name ASC
      ''', [parentId]);
      return maps.map((m) => Product.fromMap(m)).toList();
    } catch (e) {
      debugPrint('[ProductRepo] getVariants error: $e');
      rethrow;
    }
  }

  // ===== 顧客別価格 =====

  Future<List<CustomerProductPrice>> getCustomerPrices(String productId) async {
    try {
      final db = await _dbHelper.database;
      final maps = await db.query('customer_product_prices',
        where: 'product_id = ?', whereArgs: [productId],
      );
      return maps.map((m) => CustomerProductPrice.fromMap(m)).toList();
    } catch (e) {
      debugPrint('[ProductRepo] getCustomerPrices error: $e');
      rethrow;
    }
  }

  Future<void> setCustomerPrice(CustomerProductPrice price) async {
    try {
      final db = await _dbHelper.database;
      await db.insert('customer_product_prices', price.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      debugPrint('[ProductRepo] setCustomerPrice error: $e');
      rethrow;
    }
  }

  Future<void> deleteCustomerPrice(String customerId, String productId) async {
    try {
      final db = await _dbHelper.database;
      await db.delete('customer_product_prices',
        where: 'customer_id = ? AND product_id = ?',
        whereArgs: [customerId, productId],
      );
    } catch (e) {
      debugPrint('[ProductRepo] deleteCustomerPrice error: $e');
      rethrow;
    }
  }

  // ===== 単価解決 =====

  Future<ResolvedPrice> resolveUnitPrice({
    required String productId,
    String? customerId,
  }) async {
    try {
      final product = await getProduct(productId);
      if (product == null) {
        return const ResolvedPrice(unitPrice: 0, source: PriceSource.master);
      }

      if (customerId == null || customerId.isEmpty) {
        return ResolvedPrice(
          unitPrice: product.defaultUnitPrice,
          source: product.parentId != null
              ? PriceSource.variantMaster
              : PriceSource.master,
        );
      }

      final db = await _dbHelper.database;

      final direct = await db.query(
        'customer_product_prices',
        where: 'customer_id = ? AND product_id = ?',
        whereArgs: [customerId, productId],
        limit: 1,
      );
      if (direct.isNotEmpty) {
        return ResolvedPrice(
          unitPrice: direct.first['price'] as int? ?? 0,
          source: PriceSource.customerSpecific,
          note: '顧客別固定価格',
        );
      }

      if (product.parentId != null) {
        final parent = await db.query(
          'customer_product_prices',
          where: 'customer_id = ? AND product_id = ?',
          whereArgs: [customerId, product.parentId!],
          limit: 1,
        );
        if (parent.isNotEmpty) {
          return ResolvedPrice(
            unitPrice: parent.first['price'] as int? ?? 0,
            source: PriceSource.customerSpecificParent,
            note: '親商品の顧客別固定価格を継承',
          );
        }
      }

      return ResolvedPrice(
        unitPrice: product.defaultUnitPrice,
        source: product.parentId != null
            ? PriceSource.variantMaster
            : PriceSource.master,
      );
    } catch (e) {
      debugPrint('[ProductRepo] resolveUnitPrice error: $e');
      rethrow;
    }
  }

  // ===== オプショングループ =====

  Future<List<ProductOptionGroup>> getOptionGroups(String productId) async {
    final db = await _dbHelper.database;
    final maps = await db.query('product_option_groups',
      where: 'product_id = ?',
      whereArgs: [productId],
      orderBy: 'sort_order ASC',
    );
    return maps.map((m) => ProductOptionGroup.fromMap(m)).toList();
  }

  Future<List<ProductOptionValue>> getOptionValues(String groupId) async {
    final db = await _dbHelper.database;
    final maps = await db.query('product_option_values',
      where: 'group_id = ?',
      whereArgs: [groupId],
      orderBy: 'sort_order ASC',
    );
    return maps.map((m) => ProductOptionValue.fromMap(m)).toList();
  }

  Future<void> setVariantOptions(String variantId, List<String> optionValueIds) async {
    final db = await _dbHelper.database;
    await db.transaction((txn) async {
      await txn.delete('product_variant_options',
        where: 'variant_id = ?', whereArgs: [variantId]);
      for (final valueId in optionValueIds) {
        await txn.insert('product_variant_options', {
          'variant_id': variantId,
          'option_value_id': valueId,
        });
      }
    });
  }

  Future<void> saveOptionGroup(ProductOptionGroup group) async {
    final db = await _dbHelper.database;
    await db.insert('product_option_groups', group.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> saveOptionValue(ProductOptionValue value) async {
    final db = await _dbHelper.database;
    await db.insert('product_option_values', value.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> deleteOptionGroup(String id) async {
    final db = await _dbHelper.database;
    await db.transaction((txn) async {
      await txn.delete('product_option_values',
        where: 'group_id = ?', whereArgs: [id]);
      await txn.delete('product_option_groups',
        where: 'id = ?', whereArgs: [id]);
    });
  }

  Future<void> deleteOptionValue(String id) async {
    final db = await _dbHelper.database;
    await db.delete('product_option_values',
      where: 'id = ?', whereArgs: [id]);
  }

  // ===== バリアント生成 =====

  /// 親商品のオプション組み合わせからバリアント商品を一括生成する。
  /// 戻り値は生成されたバリアントのIDリスト。
  Future<List<String>> generateVariants(String productId) async {
    final parent = await getProduct(productId);
    if (parent == null) throw Exception('親商品が見つかりません: $productId');

    final groups = await getOptionGroups(productId);
    if (groups.isEmpty) return [];

    final groupValues = <String, List<ProductOptionValue>>{};
    for (final group in groups) {
      groupValues[group.id] = await getOptionValues(group.id);
    }

    final combinations = _cartesianProduct(groupValues.values.toList());
    if (combinations.isEmpty) return [];

    final db = await _dbHelper.database;
    final variantIds = <String>[];
    await db.transaction((txn) async {
      for (final combo in combinations) {
        final variantId = const Uuid().v4();
        variantIds.add(variantId);

        int totalModifier = 0;
        final optionValueIds = <String>[];
        for (final v in combo) {
          optionValueIds.add(v.id);
          totalModifier += v.priceModifier;
        }

        final variantPrice = (parent.defaultUnitPrice + totalModifier).clamp(0, 999999999);
        final optionLabels = combo.map((v) => v.value).join(', ');
        final variantName = '${parent.name} ($optionLabels)';

        final variant = Product(
          id: variantId,
          name: variantName,
          defaultUnitPrice: variantPrice,
          defaultUnitPriceIsTaxInclusive: parent.defaultUnitPriceIsTaxInclusive,
          wholesalePrice: parent.wholesalePrice,
          wholesalePriceIsTaxInclusive: parent.wholesalePriceIsTaxInclusive,
          categoryId: parent.categoryId,
          supplierId: parent.supplierId,
          supplierName: parent.supplierName,
          isLocked: parent.isLocked,
          parentId: productId,
          validFrom: DateTime.now(),
        );

        await txn.insert('products', variant.toMap());

        for (final valueId in optionValueIds) {
          await txn.insert('product_variant_options', {
            'variant_id': variantId,
            'option_value_id': valueId,
          });
        }
      }
    });

    return variantIds;
  }

  /// 親商品に紐づく全バリアントを削除する。
  Future<void> deleteVariants(String productId) async {
    final db = await _dbHelper.database;
    final rows = await db.query('products',
      columns: ['id'],
      where: 'parent_id = ?', whereArgs: [productId]);
    final variantIds = rows.map((r) => r['id'] as String).toList();
    if (variantIds.isEmpty) return;

    await db.transaction((txn) async {
      for (final vid in variantIds) {
        await txn.delete('product_variant_options',
          where: 'variant_id = ?', whereArgs: [vid]);
      }
      final placeholders = variantIds.map((_) => '?').join(',');
      await txn.execute(
        'DELETE FROM products WHERE id IN ($placeholders)',
        variantIds,
      );
    });
  }

  /// バリアントに割り当てられたオプション値を取得する（表示用）。
  Future<List<ProductOptionValue>> getVariantOptionValues(String variantId) async {
    final db = await _dbHelper.database;
    final maps = await db.rawQuery('''
      SELECT pov.* FROM product_option_values pov
      INNER JOIN product_variant_options pvo ON pvo.option_value_id = pov.id
      WHERE pvo.variant_id = ?
      ORDER BY pov.sort_order ASC
    ''', [variantId]);
    return maps.map((m) => ProductOptionValue.fromMap(m)).toList();
  }

  /// オプション値のリストの直積（デカルト積）を計算する。
  /// 例: [[A,B], [1,2]] → [[A,1],[A,2],[B,1],[B,2]]
  List<List<ProductOptionValue>> _cartesianProduct(List<List<ProductOptionValue>> lists) {
    if (lists.isEmpty) return [];
    if (lists.length == 1) return lists[0].map((v) => [v]).toList();

    return lists.fold<List<List<ProductOptionValue>>>([[]], (result, values) {
      return [
        for (final combo in result)
          for (final v in values)
            [...combo, v],
      ];
    });
  }
}

/// 商品使用中例外（他の伝票から参照されている）
class ProductInUseException implements Exception {
  final String productId;
  final List<String> references;

  ProductInUseException(this.productId, this.references);

  @override
  String toString() =>
      '商品 $productId は参照中（${references.join(", ")}）のため削除できません';
}
