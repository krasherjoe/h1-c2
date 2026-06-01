import 'package:flutter/material.dart';
import '../../../models/product_model.dart';
import '../../../models/invoice_models.dart';
import '../../../services/product_repository.dart';
import '../../../plugins/explorer/h1_explorer.dart';
import '../../../plugins/products/explorer/product_explorer_config.dart';
import '../../../plugins/products/models/product_explorer_item.dart';
import 'variant_picker_sheet.dart';

Future<Map<String, dynamic>?> showItemEditSheet(
  BuildContext context, {
  required InvoiceItem item,
  required String? customerId,
  required ProductRepository productRepo,
}) async {
  final picked = await Navigator.push<ProductExplorerItem>(
    context,
    MaterialPageRoute(
      builder: (_) => H1Explorer(
        config: ProductExplorerConfig(),
        selectionMode: true,
      ),
    ),
  );
  if (picked == null) return null;
  final product = picked.product;

  final resolvedProduct = await _resolveVariant(context, product, productRepo);
  if (resolvedProduct == null) return null;

  final resolvedPrice = await productRepo.resolveUnitPrice(
    productId: resolvedProduct.id,
    customerId: customerId,
  );

  return {
    'item': item.copyWith(
      productId: resolvedProduct.id,
      description: resolvedProduct.name,
      unitPrice: resolvedPrice.unitPrice,
    ),
    'resolvedProductName': resolvedProduct.name,
    'priceNote': resolvedPrice.note,
  };
}

Future<Product?> _resolveVariant(
  BuildContext context,
  Product product,
  ProductRepository productRepo,
) async {
  final groups = await productRepo.getOptionGroups(product.id);
  if (groups.isEmpty) return product;

  final allValues = <ProductOptionGroup, List<ProductOptionValue>>{};
  for (final g in groups) {
    allValues[g] = await productRepo.getOptionValues(g.id);
  }

  final selected = <String, ProductOptionValue?>{};
  for (final g in groups) {
    final vals = allValues[g] ?? [];
    selected[g.id] = vals.isNotEmpty ? vals.first : null;
  }

  final result = await showModalBottomSheet<Product?>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) {
      return VariantPickerSheet(
        parent: product,
        groups: groups,
        allValues: allValues,
        selected: selected,
      );
    },
  );

  return result ?? product;
}
