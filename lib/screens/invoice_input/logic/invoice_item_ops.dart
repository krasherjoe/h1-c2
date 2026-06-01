import 'package:flutter/material.dart';
import '../../../models/invoice_models.dart';
import '../../../models/product_model.dart';
import '../../../services/product_repository.dart';
import '../../../plugins/explorer/h1_explorer.dart';
import '../../../plugins/products/explorer/product_explorer_config.dart';
import '../../../plugins/products/models/product_explorer_item.dart';
import '../../../screens/barcode_scanner/barcode_scanner_screen.dart';
import '../../../widgets/paste_buffer_dialog.dart';

class ItemAddResult {
  final InvoiceItem item;
  final String productName;
  final String? priceNote;
  final int unitPrice;
  final PriceSource source;

  ItemAddResult({
    required this.item,
    required this.productName,
    this.priceNote,
    required this.unitPrice,
    required this.source,
  });
}

Future<ItemAddResult?> addItemToInvoice(
  BuildContext context, {
  required ProductRepository productRepo,
  required String? customerId,
  required Future<Product> Function(Product) resolveVariant,
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
  if (picked == null || !context.mounted) return null;
  final product = picked.product;
  final resolvedProduct = await resolveVariant(product);
  if (!context.mounted) return null;

  final resolved = await productRepo.resolveUnitPrice(
    productId: resolvedProduct.id,
    customerId: customerId,
  );
  if (!context.mounted) return null;

  final item = InvoiceItem(
    productId: resolvedProduct.id,
    description: resolvedProduct.name,
    quantity: 1,
    unitPrice: resolved.unitPrice,
  );

  return ItemAddResult(
    item: item,
    productName: resolvedProduct.name,
    priceNote: resolved.note,
    unitPrice: resolved.unitPrice,
    source: resolved.source,
  );
}

Future<ItemAddResult?> addItemByBarcode(
  BuildContext context, {
  required ProductRepository productRepo,
  required String? customerId,
  required Future<Product> Function(Product) resolveVariant,
}) async {
  final barcode = await Navigator.push<String>(
    context,
    MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()),
  );
  if (barcode == null || barcode.isEmpty || !context.mounted) return null;
  try {
    final products = await productRepo.searchProducts(barcode);
    final normalizedCode = barcode.replaceAll(RegExp(r'[\s-]'), '');
    final product = products.firstWhere(
      (p) => p.barcode != null && p.barcode!.replaceAll(RegExp(r'[\s-]'), '') == normalizedCode,
      orElse: () => throw Exception('該当する商品が見つかりません'),
    );
    if (!context.mounted) return null;
    final resolvedProduct = await resolveVariant(product);
    if (!context.mounted) return null;
    final resolved = await productRepo.resolveUnitPrice(
      productId: resolvedProduct.id,
      customerId: customerId,
    );
    if (!context.mounted) return null;

    final item = InvoiceItem(
      productId: resolvedProduct.id,
      description: resolvedProduct.name,
      quantity: 1,
      unitPrice: resolved.unitPrice,
    );

    return ItemAddResult(
      item: item,
      productName: resolvedProduct.name,
      priceNote: resolved.note,
      unitPrice: resolved.unitPrice,
      source: resolved.source,
    );
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('バーコードエラー: $e'), backgroundColor: Colors.red.shade700),
      );
    }
    return null;
  }
}

Future<List<InvoiceItem>?> pasteItemsFromBuffer(BuildContext context) async {
  final parsed = await showPasteBufferScreen(context);
  if (parsed.isEmpty || !context.mounted) return null;
  final items = parsed.map((item) => InvoiceItem(
    description: item.name,
    quantity: 1,
    unitPrice: item.price,
  )).toList();
  return items;
}
