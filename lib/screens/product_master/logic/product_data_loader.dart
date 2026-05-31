import 'package:flutter/material.dart';
import '../../../models/product_model.dart';
import '../../../models/product_category_model.dart';
import '../../../services/product_repository.dart';
import '../../../services/product_category_repository.dart';
import '../../../services/sys_logger.dart';
import '../models/product_list_types.dart';

class LoadedProductData {
  final List<Product> parents;
  final Map<String, List<Product>> variantsByParent;
  final List<ProductCategory> categories;

  LoadedProductData({
    required this.parents,
    required this.variantsByParent,
    required this.categories,
  });
}

Future<LoadedProductData?> loadProducts({
  required ProductRepository repo,
  required ProductCategoryRepository categoryRepo,
  required bool mounted,
}) async {
  try {
    final allProducts = await repo.getAllProducts();
    final parents = allProducts.where((p) => p.parentId == null).toList();
    final variants = allProducts.where((p) => p.parentId != null).toList();
    final byParent = <String, List<Product>>{};
    for (final v in variants) {
      byParent.putIfAbsent(v.parentId!, () => []).add(v);
    }
    final cats = await categoryRepo.getAllCategories();
    if (!mounted) return null;
    return LoadedProductData(
      parents: parents,
      variantsByParent: byParent,
      categories: cats,
    );
  } catch (e) {
    SysLogger.instance.logError('P1', e);
    return null;
  }
}

Future<bool> migrateLegacyCategoryIds({
  required List<Product> products,
  required ProductRepository productRepo,
  required ProductCategoryRepository categoryRepo,
}) async {
  final needsLink = products.where((p) {
    final hasNoId = p.categoryId == null || p.categoryId!.isEmpty;
    final hasText = p.category != null && p.category!.trim().isNotEmpty;
    return hasNoId && hasText;
  }).toList();
  if (needsLink.isEmpty) return false;

  final cache = <String, String>{};
  var changed = 0;
  for (final p in needsLink) {
    final name = normalizeCategory(p.category!.trim());
    if (name.isEmpty) continue;
    var id = cache[name];
    id ??= await categoryRepo.getOrCreateCategoryId(name);
    cache[name] = id;
    if (id.isEmpty) continue;
    try {
      await productRepo.saveProduct(p.copyWith(categoryId: id));
      changed++;
    } catch (e) {
      debugPrint('P1 categoryId 補完失敗 (${p.name}): $e');
    }
  }
  return changed > 0;
}

List<Product> applyFilter({
  required List<Product> products,
  required String searchQuery,
  required bool showHidden,
  required String sortKey,
  required Map<String, List<Product>> variantsByParent,
}) {
  final filtered = products.where((p) {
    final query = searchQuery.toLowerCase();
    return p.name.toLowerCase().contains(query) ||
        (p.barcode?.toLowerCase().contains(query) ?? false) ||
        (p.category?.toLowerCase().contains(query) ?? false);
  }).toList();

  List<Product> result;
  if (!showHidden) {
    result = filtered.where((p) => !p.isHidden).toList();
  } else {
    result = filtered;
  }

  if (showHidden) {
    result.sort((a, b) => b.id.compareTo(a.id));
  } else {
    sortProducts(result, sortKey);
  }

  for (final entry in variantsByParent.entries) {
    sortProducts(entry.value, sortKey);
  }

  return result;
}

void sortProducts(List<Product> list, String sortKey) {
  switch (sortKey) {
    case 'name_desc':
      list.sort((a, b) => b.name.toLowerCase().compareTo(a.name.toLowerCase()));
      break;
    case 'category_asc':
      list.sort((a, b) {
        final catA = (a.category ?? '').toLowerCase();
        final catB = (b.category ?? '').toLowerCase();
        final cmp = catA.compareTo(catB);
        if (cmp != 0) return cmp;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
      break;
    case 'price_asc':
      list.sort((a, b) => a.defaultUnitPrice.compareTo(b.defaultUnitPrice));
      break;
    case 'price_desc':
      list.sort((a, b) => b.defaultUnitPrice.compareTo(a.defaultUnitPrice));
      break;
    default:
      list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      break;
  }
}
