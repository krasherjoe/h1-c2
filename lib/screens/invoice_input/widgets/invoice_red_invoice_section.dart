import 'package:flutter/material.dart';
import '../../../models/invoice_models.dart';

class InvoiceRedInvoiceSection extends StatelessWidget {
  final bool isLocked;
  final String? currentId;
  final bool hasRedInvoice;
  final bool isRedInvoice;
  final String? sourceDocumentId;
  final DocumentType documentType;
  final String redInvoiceButtonLabel;
  final VoidCallback? onCreateRedInvoice;
  final VoidCallback? onViewSourceInvoice;

  const InvoiceRedInvoiceSection({
    super.key,
    required this.isLocked,
    this.currentId,
    required this.hasRedInvoice,
    required this.isRedInvoice,
    this.sourceDocumentId,
    required this.documentType,
    this.redInvoiceButtonLabel = '',
    this.onCreateRedInvoice,
    this.onViewSourceInvoice,
  });

  @override
  Widget build(BuildContext context) {
    if (isLocked && currentId != null && !hasRedInvoice && !isRedInvoice) {
      return _buildRedInvoiceButton(context);
    }
    if (isLocked && currentId != null && hasRedInvoice && !isRedInvoice) {
      return _buildRedInvoiceIssuedLabel(context);
    }
    if (isRedInvoice && sourceDocumentId != null) {
      return _buildSourceInvoiceButton(context);
    }
    return const SizedBox.shrink();
  }

  Widget _buildRedInvoiceButton(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 0.5,
      color: theme.cardColor,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.colorScheme.error.withValues(alpha: 0.5), width: 1.5),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '電子帳簿保存法対応',
              style: TextStyle(
                fontSize: 11,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onCreateRedInvoice,
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.error,
                  foregroundColor: theme.colorScheme.onError,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                icon: const Icon(Icons.undo, size: 22),
                label: Text(
                  redInvoiceButtonLabel.isNotEmpty
                      ? redInvoiceButtonLabel
                      : 'この伝票を取り消す赤伝を起票',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'ロック済みの伝票を取消す場合、電子帳簿保存法に基づき元伝票を保持したまま、全明細をマイナスにした赤伝を自動生成・ロックします。',
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRedInvoiceIssuedLabel(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 0.5,
        color: theme.cardColor,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: cs.error.withValues(alpha: 0.3), width: 1.5),
          ),
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Icon(Icons.check_circle, color: cs.error),
                const SizedBox(width: 8),
                Text('赤伝発行済み', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: cs.error)),
              ]),
              const SizedBox(height: 4),
              Text('この伝票に対する取消しは既に発行されています。', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSourceInvoiceButton(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 0.5,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: cs.primary.withValues(alpha: 0.3), width: 1.5),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.undo, color: cs.primary),
              const SizedBox(width: 8),
              Text('赤伝（取消し伝票）', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: cs.primary)),
            ]),
            const SizedBox(height: 4),
            Text('この伝票は元の伝票を取り消す赤伝です。', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.open_in_new),
                label: const Text('元の伝票を開く'),
                onPressed: onViewSourceInvoice,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
