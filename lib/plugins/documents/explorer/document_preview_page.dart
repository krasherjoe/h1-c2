import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/document_model.dart';

class DocumentPreviewPage extends StatelessWidget {
  final DocumentModel document;
  final bool allowFormalIssue;
  final VoidCallback? onFormalIssue;
  final bool showShare;
  final bool showPrint;
  final VoidCallback? onShare;
  final VoidCallback? onPrint;

  const DocumentPreviewPage({
    super.key,
    required this.document,
    this.allowFormalIssue = false,
    this.onFormalIssue,
    this.showShare = false,
    this.showPrint = false,
    this.onShare,
    this.onPrint,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final currencyFmt = NumberFormat('#,###');

    return Scaffold(
      appBar: AppBar(
        title: Text('${document.documentType.label} プレビュー'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'No. ${document.documentNumber}',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: cs.onSurface),
            ),
            const SizedBox(height: 8),
            Text(
              '日付: ${DateFormat('yyyy/MM/dd').format(document.date)}',
              style: TextStyle(fontSize: 14, color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 4),
            Text(
              '顧客: ${document.customerName}',
              style: TextStyle(fontSize: 14, color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            Divider(color: cs.outlineVariant),
            const SizedBox(height: 8),
            Expanded(
              child: ListView(
                children: [
                  for (final item in document.items)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Expanded(child: Text(item.productName)),
                          Text('${item.quantity == item.quantity.roundToDouble() ? item.quantity.toInt().toString() : item.quantity.toStringAsFixed(1)} x ${currencyFmt.format(item.unitPrice)}'),
                          const SizedBox(width: 8),
                          Text(currencyFmt.format(item.subtotal)),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            Divider(color: cs.outlineVariant),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  '合計: ¥${currencyFmt.format(document.total)}',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: cs.onSurface),
                ),
              ],
            ),
            if (allowFormalIssue && onFormalIssue != null) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: onFormalIssue,
                  icon: const Icon(Icons.lock),
                  label: const Text('正式発行'),
                ),
              ),
            ],
            if (showShare || showPrint) ...[
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  if (showShare && onShare != null)
                    IconButton(
                      icon: const Icon(Icons.share),
                      tooltip: 'PDF共有',
                      onPressed: onShare,
                    ),
                  if (showPrint && onPrint != null)
                    IconButton(
                      icon: const Icon(Icons.print),
                      tooltip: '印刷',
                      onPressed: onPrint,
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
