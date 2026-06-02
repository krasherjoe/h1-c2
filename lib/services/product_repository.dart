import 'package:flutter/foundation.dart' show debugPrint;
import 'package:sqflite/sqflite.dart';
import '../models/product_model.dart';
import 'database_helper.dart';
import 'activity_log_repository.dart';
import 'hash_utils.dart';
import 'hash_chain_verify_result.dart';
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
        final previousHash = existing.isNotEmpty
            ? existing.first['content_hash']
            : null;

        final contentHash = HashUtils.calculateProductHash(
          id: adjusted.id,
          name: adjusted.name,
          defaultUnitPrice: adjusted.defaultUnitPrice,
          wholesalePrice: adjusted.wholesalePrice,
          barcode: adjusted.barcode,
          category: adjusted.category,
          categoryId: adjusted.categoryId,
          stockQuantity: adjusted.stockQuantity,
          odooId: adjusted.odooId,
          isLocked: adjusted.isLocked,
          isHidden: adjusted.isHidden,
          validFrom: adjusted.validFrom,
          previousHash: adjusted.previousHash,
        );

        productMap['content_hash'] = contentHash;
        productMap['previous_hash'] = previousHash ?? '';
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
      await db.delete('products', where: 'id = ?', whereArgs: [id]);

      await _logRepo.logAction(
        action: "DELETE_PRODUCT",
        targetType: "PRODUCT",
        targetId: id,
        details: "商品を削除しました",
      );
    } catch (e) {
      debugPrint('[ProductRepo] deleteProduct error: $e');
      rethrow;
    }
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

  /// 最新の N 件の商品を遡ってハッシュチェーン整合性を検証する
  Future<HashChainVerifyResult> verifyTailN({int n = 5}) async {
    try {
      final db = await _dbHelper.database;
      final rows = await db.query(
        'products',
        where: 'is_current = 1 AND content_hash IS NOT NULL',
        orderBy: 'updated_at DESC',
        limit: n,
      );
      final broken = <String>[];
      for (final row in rows) {
        final storedHash = row['content_hash'] as String?;
        if (storedHash == null) continue;

        final product = Product.fromMap(row as Map<String, dynamic>);
        final recomputed = HashUtils.calculateProductHash(
          id: product.id,
          name: product.name,
          defaultUnitPrice: product.defaultUnitPrice,
          wholesalePrice: product.wholesalePrice,
          barcode: product.barcode,
          category: product.category,
          categoryId: product.categoryId,
          stockQuantity: product.stockQuantity,
          odooId: product.odooId,
          isLocked: product.isLocked,
          isHidden: product.isHidden,
          validFrom: product.validFrom,
          validTo: product.validTo,
          isCurrentFlag: product.isCurrent,
          version: product.version,
          previousHash: product.previousHash,
        );

        if (recomputed != storedHash) {
          broken.add(product.id);
          continue;
        }

        if (product.version > 1 &&
            product.previousHash != null &&
            product.previousHash!.isNotEmpty) {
          final prevRows = await db.query(
            'products',
            columns: ['content_hash'],
            where: 'id = ? AND version = ?',
            whereArgs: [product.id, product.version - 1],
            limit: 1,
          );
          if (prevRows.isNotEmpty) {
            final prevContentHash = prevRows.first['content_hash'] as String?;
            if (prevContentHash != null && product.previousHash != prevContentHash) {
              broken.add(product.id);
            }
          }
        }
      }
      return HashChainVerifyResult(
        checked: rows.length,
        brokenIds: broken,
        verifiedAt: DateTime.now(),
      );
    } catch (e) {
      debugPrint('[ProductRepo] verifyTailN error: $e');
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

  Future<List<ProductOptionGroup>> getOptionGroups(String productId) async => [];

  Future<List<ProductOptionValue>> getOptionValues(String groupId) async => [];

  Future<void> setVariantOptions(String variantId, List<String> optionValueIds) async {}

  Future<void> saveOptionGroup(ProductOptionGroup group) async {}

  Future<void> saveOptionValue(ProductOptionValue value) async {}

  Future<void> deleteOptionGroup(String id) async {}

  Future<void> deleteOptionValue(String id) async {}
}
