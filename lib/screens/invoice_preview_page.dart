import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/invoice_models.dart';

class InvoicePdfPreviewPage extends StatelessWidget {
  final Invoice invoice;
  final bool isUnlocked;
  final bool isLocked;
  final bool allowFormalIssue;
  final VoidCallback? onFormalIssue;
  final bool showShare;
  final bool showEmail;
  final bool showPrint;
  final VoidCallback? onShare;
  final VoidCallback? onEmail;
  final VoidCallback? onPrint;

  const InvoicePdfPreviewPage({
    super.key,
    required this.invoice,
    this.isUnlocked = false,
    this.isLocked = false,
    this.allowFormalIssue = false,
    this.onFormalIssue,
    this.showShare = false,
    this.showEmail = false,
    this.showPrint = false,
    this.onShare,
    this.onEmail,
    this.onPrint,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final currencyFmt = NumberFormat('#,###');

    return Scaffold(
      appBar: AppBar(
        title: Text('${invoice.documentTypeName} プレビュー'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'No. ${invoice.id}',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: cs.onSurface),
            ),
            const SizedBox(height: 8),
            Text(
              '日付: ${DateFormat('yyyy/MM/dd').format(invoice.date)}',
              style: TextStyle(fontSize: 14, color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 4),
            Text(
              '顧客: ${invoice.customer.displayName}',
              style: TextStyle(fontSize: 14, color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            Divider(color: cs.outlineVariant),
            const SizedBox(height: 8),
            Expanded(
              child: ListView(
                children: [
                  for (final item in invoice.items)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Expanded(child: Text(item.description)),
                          Text('${item.quantity} x ${currencyFmt.format(item.unitPrice)}'),
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
                  '合計: ¥${currencyFmt.format(invoice.totalAmount)}',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: cs.onSurface,
                  ),
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
            if (showShare || showEmail || showPrint) ...[
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  if (showShare && onShare != null)
                    IconButton(
                      icon: const Icon(Icons.share),
                      tooltip: '共有',
                      onPressed: onShare,
                    ),
                  if (showEmail && onEmail != null)
                    IconButton(
                      icon: const Icon(Icons.email),
                      tooltip: 'メール送信',
                      onPressed: onEmail,
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
