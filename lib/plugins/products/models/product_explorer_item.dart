import 'package:flutter/material.dart';
import '../../../plugins/explorer/h1_explorer_item.dart';
import '../../../models/product_model.dart';

class ProductExplorerItem extends H1ExplorerItem {
  final Product product;

  ProductExplorerItem(this.product);

  @override
  String get id => product.id;

  @override
  String get title => product.name;

  @override
  String? get subtitle => '¥${product.defaultUnitPrice}';

  @override
  String? get badge => product.category;

  @override
  IconData? get icon => Icons.inventory_2;

  @override
  DateTime? get updatedAt => null;
}
