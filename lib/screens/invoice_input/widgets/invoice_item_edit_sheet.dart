import 'package:flutter/material.dart';
import '../../../models/product_model.dart';
import '../../../models/invoice_models.dart';
import '../../../services/product_repository.dart';
import '../../../screens/product_master/product_master_screen.dart';
import 'variant_picker_sheet.dart';

Future<Map<String, dynamic>?> showItemEditSheet(
  BuildContext context, {
  required InvoiceItem item,
  required String? customerId,
  required ProductRepository productRepo,
}) async {
  final product = await Navigator.push<Product>(
    context,
    MaterialPageRoute(builder: (_) => const ProductMasterScreen(selectionMode: true)),
  );
  if (product == null) return null;

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
