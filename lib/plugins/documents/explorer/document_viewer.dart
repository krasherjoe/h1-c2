import 'package:flutter/material.dart';
import '../models/document_model.dart';
import '../logic/document_converter.dart';
import '../services/document_repository.dart';
import '../../../services/customer_repository.dart';
import '../../../services/error_reporter.dart';
import 'document_preview_page.dart';

class DocumentViewer extends StatelessWidget {
  final DocumentModel document;

  const DocumentViewer({super.key, required this.document});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
      children: [
        _buildHeader(context, cs),
        const SizedBox(height: 16),
        _buildCustomerSection(context, cs),
        const SizedBox(height: 16),
        _buildSubjectSection(cs),
        const SizedBox(height: 16),
        _buildDivider(cs),
        _buildItemsHeader(cs),
        const SizedBox(height: 8),
        ...document.items.map((item) => _buildItemCard(item, cs)),
        const SizedBox(height: 12),
        _buildTotalSection(cs),
        const SizedBox(height: 16),
        if (document.isConfirmed) _buildConvertButton(context),
        const SizedBox(height: 12),
        _buildPdfButton(context),
      ],
    );
  }

  Widget _buildHeader(BuildContext context, ColorScheme cs) {
    final docTypeColor = () {
      switch (document.documentType) {
        case DocumentType.estimation: return cs.secondary;
        case DocumentType.order: return cs.tertiary;
        case DocumentType.delivery: return cs.primaryContainer;
        case DocumentType.invoice: return cs.error;
        case DocumentType.receipt: return const Color(0xFF388E3C);
      }
    }();
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: docTypeColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(document.documentType.label,
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: docTypeColor)),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: document.isDraft ? cs.tertiaryContainer : cs.primaryContainer,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            document.isDraft ? '下書き' : '確定',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500,
              color: document.isDraft ? cs.onTertiaryContainer : cs.onPrimaryContainer),
          ),
        ),
        const Spacer(),
        Text(document.documentNumber,
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: cs.onSurfaceVariant)),
      ],
    );
  }

  Widget _buildCustomerSection(BuildContext context, ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.business, size: 16, color: cs.onSurfaceVariant),
            const SizedBox(width: 6),
            Expanded(child: Text(document.customerName, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: cs.onSurface))),
          ]),
          const SizedBox(height: 6),
          Row(children: [
            Icon(Icons.calendar_today, size: 14, color: cs.onSurfaceVariant),
            const SizedBox(width: 6),
            Text('${document.date.year}/${document.date.month.toString().padLeft(2, '0')}/${document.date.day.toString().padLeft(2, '0')}',
              style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
            const Spacer(),
            Text(document.documentNumber,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: cs.onSurfaceVariant)),
          ]),
          const SizedBox(height: 4),
          Row(children: [
            Icon(Icons.tag, size: 14, color: cs.onSurfaceVariant),
            const SizedBox(width: 6),
            Text('ID: ${document.id.substring(0, 8)}...',
              style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
            if (document.linkedDocumentId != null) ...[
              const Spacer(),
              Icon(Icons.link, size: 14, color: cs.onSurfaceVariant),
              const SizedBox(width: 4),
              Text('元伝票', style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
            ],
          ]),
        ],
      ),
    );
  }

  Widget _buildSubjectSection(ColorScheme cs) {
    if (document.subject == null || document.subject!.isEmpty) return const SizedBox.shrink();
    return Row(children: [
      Icon(Icons.subject, size: 16, color: cs.onSurfaceVariant),
      const SizedBox(width: 6),
      Expanded(child: Text(document.subject!, style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant))),
    ]);
  }

  Widget _buildDivider(ColorScheme cs) {
    return Divider(height: 1, color: cs.outlineVariant.withValues(alpha: 0.3));
  }

  Widget _buildItemsHeader(ColorScheme cs) {
    return Row(children: [
      Text('明細', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: cs.onSurface)),
      const Spacer(),
      Text('${document.items.length}点', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
    ]);
  }

  Widget _buildItemCard(DocumentItem item, ColorScheme cs) {
    final hasDiscount = item.discountAmount != null || item.discountRate != null;
    final baseSubtotal = (item.quantity * item.unitPrice).round();
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      elevation: 0.5,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(item.productName, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500, color: cs.onSurface)),
            if (item.variantLabel != null && item.variantLabel!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(item.variantLabel!, style: TextStyle(fontSize: 11.5, color: cs.onSurfaceVariant)),
              ),
            const SizedBox(height: 6),
            Row(children: [
              Text(_formatMoney(item.unitPrice),
                style: TextStyle(fontSize: 12, color: cs.primary, fontWeight: FontWeight.w600)),
              const SizedBox(width: 4),
              if (!hasDiscount)
                Text('× ${_formatQty(item.quantity)} = ${_formatMoney(item.subtotal)}',
                  style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant))
              else ...[
                Text('× ${_formatQty(item.quantity)} = ${_formatMoney(baseSubtotal)}',
                  style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant, decoration: TextDecoration.lineThrough)),
                const SizedBox(width: 4),
                Text(_formatMoney(item.subtotal),
                  style: TextStyle(fontSize: 12, color: cs.error, fontWeight: FontWeight.w600)),
              ],
            ]),
          ],
        ),
      ),
    );
  }

  Widget _buildTotalSection(ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.primaryContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          if (document.discountAmount > 0) ...[
            _tr('小計', document.subtotal, cs, labelColor: cs.onSurfaceVariant),
            _tr('値引き', -document.discountAmount, cs, labelColor: cs.error),
          ],
          _tr('税抜合計', document.taxableAmount, cs, labelColor: cs.onSurfaceVariant),
          _tr('消費税 (${(document.taxRate * 100).round()}%)', document.tax, cs, labelColor: cs.onSurfaceVariant),
          const Divider(height: 16),
          _tr('合計', document.total, cs, totalStyle: true),
        ],
      ),
    );
  }

  Widget _tr(String label, int amount, ColorScheme cs, {bool totalStyle = false, Color? labelColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(
            fontSize: totalStyle ? 15 : 13,
            fontWeight: totalStyle ? FontWeight.bold : FontWeight.normal,
            color: labelColor ?? cs.onSurface,
          )),
          Text(_formatMoney(amount), style: TextStyle(
            fontSize: totalStyle ? 16 : 13,
            fontWeight: totalStyle ? FontWeight.bold : FontWeight.normal,
            color: totalStyle ? cs.primary : cs.onSurface,
          )),
        ],
      ),
    );
  }

  Widget _buildConvertButton(BuildContext context) {
    final next = nextDocumentType(document.documentType);
    final label = copyButtonLabel(document.documentType);
    if (next == null || label.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        icon: const Icon(Icons.arrow_forward),
        label: Text(label),
        onPressed: () async {
          try {
            final repo = DocumentRepository();
            final newDoc = copyAsNextDocument(document);
            final docNumber = await repo.generateDocumentNumber(next);
            await repo.save(newDoc.copyWith(documentNumber: docNumber));
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('${next.label}伝票を作成しました（元の${document.documentType.label}はそのままです）')),
            );
          } catch (e) {
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('作成エラー: $e')),
            );
          }
        },
      ),
    );
  }

  Widget _buildPdfButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        icon: const Icon(Icons.preview),
        label: const Text('プレビュー'),
        onPressed: () async {
          final repo = DocumentRepository();
          String? customerEmail;
          if (document.customerId.isNotEmpty) {
            final customer = await CustomerRepository().getById(document.customerId);
            customerEmail = customer?.email;
          }
          if (!context.mounted) return;
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => DocumentPreviewPage(
                document: document,
                isUnlocked: document.isDraft,
                onFormalIssue: () async {
                  try {
                    final updated = document.copyWith(
                      status: 'confirmed',
                      isLocked: true,
                    );
                    await repo.save(updated);
                    return true;
                  } catch (e, st) {
                    ErrorReporter.sendError(
                      message: '正式発行失敗: $e',
                      screenId: '/documents/viewer',
                      stackTrace: st,
                    );
                    return false;
                  }
                },
                showShare: true,
                showPrint: true,
                customerEmail: customerEmail,
              ),
            ),
          );
        },
      ),
    );
  }

  String _formatMoney(int amount) =>
    '¥${amount.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}';

  String _formatQty(double qty) =>
    qty == qty.roundToDouble() ? qty.toInt().toString() : qty.toStringAsFixed(1);
}
