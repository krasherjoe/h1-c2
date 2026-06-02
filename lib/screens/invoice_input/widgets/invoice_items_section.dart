import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../models/invoice_models.dart';
import '../../../widgets/h1_text_field.dart';

class InvoiceItemsSection extends StatelessWidget {
  final List<InvoiceItem> items;
  final NumberFormat format;
  final bool isViewMode;
  final bool isLocked;

  final ValueChanged<int>? onTapItem;
  final ValueChanged<int>? onDeleteItem;
  final void Function(int oldIndex, int newIndex)? onReorder;
  final VoidCallback? onAddItem;
  final VoidCallback? onAddItemByBarcode;
  final VoidCallback? onPasteItems;
  final ValueChanged<int>? onDecrementQuantity;
  final void Function(int index, int quantity)? onSetQuantity;
  final ValueChanged<int>? onIncrementQuantity;

  const InvoiceItemsSection({
    super.key,
    required this.items,
    required this.format,
    required this.isViewMode,
    required this.isLocked,
    this.onTapItem,
    this.onDeleteItem,
    this.onReorder,
    this.onAddItem,
    this.onAddItemByBarcode,
    this.onPasteItems,
    this.onDecrementQuantity,
    this.onSetQuantity,
    this.onIncrementQuantity,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              "明細項目",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            if (!isViewMode && !isLocked)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextButton.icon(onPressed: onAddItem, icon: const Icon(Icons.add), label: const Text("追加")),
                  IconButton(
                    icon: const Icon(Icons.qr_code_scanner),
                    tooltip: 'バーコードで追加',
                    onPressed: onAddItemByBarcode,
                  ),
                  const SizedBox(width: 4),
                  TextButton.icon(onPressed: onPasteItems, icon: const Icon(Icons.content_paste), label: const Text("貼付")),
                ],
              ),
          ],
        ),
        if (items.isEmpty)
          Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Center(
              child: Text("商品が追加されていません", style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ),
          )
        else if (isViewMode)
          Column(
            children: items
                .map(
                  (item) => Card(
                    margin: const EdgeInsets.only(bottom: 6),
                    elevation: 0.5,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.description,
                            style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Spacer(flex: 1),
                              SizedBox(
                                width: 80,
                                child: Text(
                                  "￥${format.format(item.unitPrice)}",
                                  style: const TextStyle(fontSize: 12.5),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              const SizedBox(width: 8),
                              SizedBox(
                                width: 50,
                                child: Text(
                                  "× ${item.quantity}",
                                  style: const TextStyle(fontSize: 12.5),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              const Spacer(flex: 1),
                              Text(
                                "= ￥${format.format(item.unitPrice * item.quantity)}",
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                )
                .toList(),
          )
        else
          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: items.length,
            onReorder: (oldIndex, newIndex) {
              if (onReorder != null) {
                int targetIndex = newIndex;
                if (targetIndex > oldIndex) targetIndex -= 1;
                onReorder!(oldIndex, targetIndex);
              }
            },
            buildDefaultDragHandles: false,
            itemBuilder: (context, idx) {
              final item = items[idx];
              return ReorderableDelayedDragStartListener(
                key: ValueKey('item_${idx}_${item.description}'),
                index: idx,
                child: Card(
                  margin: const EdgeInsets.only(bottom: 6),
                  elevation: 0.5,
                  color: Theme.of(context).cardColor,
                  child: GestureDetector(
                    onTap: () => onTapItem?.call(idx),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.description,
                            style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "￥${format.format(item.unitPrice)} × ${item.quantity} = ￥${format.format(item.unitPrice * item.quantity)}",
                                    style: const TextStyle(fontSize: 12.5),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            if (!isViewMode && !isLocked)
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.remove, size: 18),
                                    onPressed: () {
                                      if (item.quantity <= 1) return;
                                      onDecrementQuantity?.call(idx);
                                    },
                                    constraints: const BoxConstraints.tightFor(
                                      width: 28,
                                      height: 28,
                                    ),
                                    padding: EdgeInsets.zero,
                                  ),
                                  GestureDetector(
                                    onTap: () async {
                                      final ctrl = TextEditingController(
                                        text: '${item.quantity}',
                                      );
                                      final result = await showDialog<int>(
                                        context: context,
                                        builder: (ctx) => AlertDialog(
                                          title: const Text('数量を入力'),
                                          content: H1TextField(
                                            controller: ctrl,
                                            keyboardType: TextInputType.number,
                                            autofocus: true,
                                            decoration: const InputDecoration(
                                              labelText: '数量',
                                            ),
                                            onSubmitted: (v) {
                                              final n = int.tryParse(v);
                                              if (n != null && n >= 1)
                                                Navigator.pop(ctx, n);
                                            },
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(ctx),
                                              child: const Text('キャンセル'),
                                            ),
                                            TextButton(
                                              onPressed: () {
                                                final n = int.tryParse(
                                                  ctrl.text,
                                                );
                                                if (n != null && n >= 1)
                                                  Navigator.pop(ctx, n);
                                              },
                                              child: const Text('OK'),
                                            ),
                                          ],
                                        ),
                                      );
                                      if (result != null) {
                                        onSetQuantity?.call(idx, result);
                                      }
                                    },
                                    child: SizedBox(
                                      width: 36,
                                      child: Text(
                                        '${item.quantity}',
                                        style: const TextStyle(fontSize: 12.5),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.add, size: 18),
                                    onPressed: () {
                                      onIncrementQuantity?.call(idx);
                                    },
                                    constraints: const BoxConstraints.tightFor(
                                      width: 28,
                                      height: 28,
                                    ),
                                    padding: EdgeInsets.zero,
                                  ),
                                  IconButton(
                                    icon: Icon(
                                      Icons.delete_outline,
                                      color: Theme.of(context).colorScheme.error,
                                      size: 20,
                                    ),
                                    onPressed: () => onDeleteItem?.call(idx),
                                    tooltip: "削除",
                                    constraints: const BoxConstraints.tightFor(
                                      width: 32,
                                      height: 32,
                                    ),
                                    padding: EdgeInsets.zero,
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ],
                    ),
                    ),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}
