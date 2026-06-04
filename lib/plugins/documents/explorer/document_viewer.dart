import 'package:flutter/material.dart';
import '../models/document_model.dart';
import '../logic/document_converter.dart';
import '../services/document_repository.dart';
import '../../../services/error_reporter.dart';
import 'document_preview_page.dart';

class DocumentViewer extends StatelessWidget {
  final DocumentModel document;

  const DocumentViewer({super.key, required this.document});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildHeader(context, theme),
        const Divider(height: 24),
        _buildItemsSection(context, theme),
        const Divider(height: 24),
        _buildTotalSection(theme),
        if (document.isConfirmed) ...[
          const Divider(height: 24),
          _buildConvertButton(context),
        ],
        const SizedBox(height: 12),
        _buildPdfButton(context),
      ],
    );
  }

  Widget _buildHeader(BuildContext context, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Chip(label: Text(document.documentType.label)),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: document.isDraft ? theme.colorScheme.tertiaryContainer : theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                document.isDraft ? '下書き' : '確定',
                style: TextStyle(
                  fontSize: 12,
                  color: document.isDraft ? theme.colorScheme.onTertiaryContainer : theme.colorScheme.onPrimaryContainer,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(document.documentNumber, style: theme.textTheme.titleLarge),
        const SizedBox(height: 8),
        Text('顧客: ${document.customerName}'),
        if (document.subject != null && document.subject!.isNotEmpty)
          Text('件名: ${document.subject}'),
        Text('日付: ${_formatDate(document.date)}'),
        if (document.linkedDocumentId != null)
          Text('元伝票: ${document.linkedDocumentId}'),
      ],
    );
  }

  Widget _buildItemsSection(BuildContext context, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('明細', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        ...document.items.map((item) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.productName),
                    Text(
                      '${_formatQty(item.quantity)} × ${_formatMoney(item.unitPrice)}',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              Text(_formatMoney(item.subtotal)),
            ],
          ),
        )),
      ],
    );
  }

  Widget _buildTotalSection(ThemeData theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text('合計', style: theme.textTheme.titleMedium),
        Text(_formatMoney(document.total), style: theme.textTheme.titleMedium),
      ],
    );
  }

  Widget _buildConvertButton(BuildContext context) {
    final next = nextDocumentType(document.documentType);
    if (next == null) return const SizedBox.shrink();
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        icon: const Icon(Icons.arrow_forward),
        label: Text('${next.label}へ変換'),
        onPressed: () async {
          try {
            final repo = DocumentRepository();
            final newDoc = convertDocument(document.copyWith(
              id: repo.generateId(),
              documentNumber: await repo.generateDocumentNumber(next),
            ));
            await repo.save(newDoc);
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('${next.label}伝票を作成しました')),
            );
          } catch (e) {
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('変換エラー: $e')),
            );
          }
        },
      ),
    );
  }

  Widget _buildPdfButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        icon: const Icon(Icons.preview),
        label: const Text('プレビュー'),
        onPressed: () {
          final repo = DocumentRepository();
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => DocumentPreviewPage(
                document: document,
                isUnlocked: document.isDraft,
                onFormalIssue: () async {
                  try {
                    final updated = document.copyWith(status: 'confirmed');
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
              ),
            ),
          );
        },
      ),
    );
  }

  String _formatDate(DateTime dt) =>
    '${dt.year}/${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')}';

  String _formatMoney(int amount) =>
    '¥${amount.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}';

  String _formatQty(double qty) =>
    qty == qty.roundToDouble() ? qty.toInt().toString() : qty.toStringAsFixed(1);
}
