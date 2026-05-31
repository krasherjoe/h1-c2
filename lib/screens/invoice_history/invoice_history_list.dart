import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/invoice_models.dart';
import 'invoice_history_item.dart';

class InvoiceHistoryList extends StatelessWidget {
  final List<Invoice> invoices;
  final bool isUnlocked;
  final NumberFormat amountFormatter;
  final DateFormat dateFormatter;
  final bool showInvoiceNumber;
  final Set<String> cancelledInvoiceIds;
  final Map<String, String> redInvoiceSourceMap;
  final void Function(Invoice) onTap;
  final void Function(Invoice) onLongPress;
  final void Function(Invoice) onEdit;
  final bool isPickerMode;
  final Set<String> selectedIds;

  const InvoiceHistoryList({
    super.key,
    required this.invoices,
    required this.isUnlocked,
    required this.amountFormatter,
    required this.dateFormatter,
    this.showInvoiceNumber = true,
    this.cancelledInvoiceIds = const {},
    this.redInvoiceSourceMap = const {},
    required this.onTap,
    required this.onLongPress,
    required this.onEdit,
    this.isPickerMode = false,
    this.selectedIds = const {},
  });

  @override
  Widget build(BuildContext context) {
    if (invoices.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.folder_open, size: 64, color: Theme.of(context).colorScheme.outline),
            SizedBox(height: 16),
            Text("保存された伝票がありません"),
          ],
        ),
      );
    }

    return ListView.builder(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 120), // 横揃えとFAB余白
      itemCount: invoices.length,
      itemBuilder: (context, index) {
        final invoice = invoices[index];
        return InvoiceHistoryItem(
          invoice: invoice,
          isUnlocked: isUnlocked,
          amountFormatter: amountFormatter,
          dateFormatter: dateFormatter,
          showInvoiceNumber: showInvoiceNumber,
          isRedInvoice: invoice.isRedInvoice,
          hasLinkedRedInvoice: cancelledInvoiceIds.contains(invoice.id),
          linkedRedInvoiceId: redInvoiceSourceMap[invoice.id],
          onTap: () => onTap(invoice),
          onLongPress: () => onLongPress(invoice),
          onEdit: () => onEdit(invoice),
          isPickerMode: isPickerMode,
          isSelected: selectedIds.contains('invoice:${invoice.id}'),
        );
      },
    );
  }
}
