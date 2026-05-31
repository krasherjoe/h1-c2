import 'package:flutter/material.dart';
import '../../../models/invoice_models.dart';

Future<DocumentType?> showDocumentTypeChangeDialog(
  BuildContext context, {
  required DocumentType currentType,
  required bool isLocked,
  required bool isDraft,
}) async {
  if (isLocked || !isDraft) return null;

  final allTypes = [
    DocumentType.estimation,
    DocumentType.order,
    DocumentType.delivery,
    DocumentType.invoice,
    DocumentType.receipt,
  ];
  final options = allTypes.where((t) => t != currentType).toList();

  String typeLabel(DocumentType t) {
    switch (t) {
      case DocumentType.estimation:
        return '見積書';
      case DocumentType.order:
        return '受注伝票';
      case DocumentType.delivery:
        return '納品書';
      case DocumentType.invoice:
        return '請求書';
      case DocumentType.receipt:
        return '領収書';
    }
  }

  final selected = await showModalBottomSheet<DocumentType>(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              '現在: ${typeLabel(currentType)}  →  変更先を選択',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const Divider(),
          ...options.map(
            (type) => ListTile(
              leading: Icon(Icons.swap_horiz, color: Theme.of(context).colorScheme.primary),
              title: Text(typeLabel(type)),
              onTap: () => Navigator.pop(context, type),
            ),
          ),
        ],
      ),
    ),
  );

  return selected;
}
