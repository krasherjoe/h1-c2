import 'package:flutter/material.dart';
import '../models/invoice_models.dart' show InvoiceItem;

class ProductPickerModal extends StatefulWidget {
  final void Function(InvoiceItem item) onItemSelected;
  const ProductPickerModal({super.key, required this.onItemSelected});

  @override
  State<ProductPickerModal> createState() => _ProductPickerModalState();
}

class _ProductPickerModalState extends State<ProductPickerModal> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('商品選択')),
      body: Center(
        child: Text(
          '商品マスター連携はコア版では利用できません',
          style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      ),
    );
  }
}
