import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/document_model.dart';
import '../logic/document_converter.dart';
import '../services/document_repository.dart';

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
                color: document.isDraft ? Colors.orange.shade100 : Colors.green.shade100,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                document.isDraft ? '下書き' : '確定',
                style: TextStyle(
                  fontSize: 12,
                  color: document.isDraft ? Colors.orange.shade800 : Colors.green.shade800,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(document.documentNumber, style: theme.textTheme.titleLarge),
        const SizedBox(height: 8),
        Text('顧客: ${document.customerName}'),
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
        icon: const Icon(Icons.picture_as_pdf),
        label: const Text('PDF出力'),
        onPressed: () => _generatePdf(context),
      ),
    );
  }

  Future<void> _generatePdf(BuildContext context) async {
    try {
      final pdf = pw.Document();
      pdf.addPage(
        pw.Page(
          build: (ctx) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(document.documentType.label, style: const pw.TextStyle(fontSize: 20)),
              pw.SizedBox(height: 8),
              pw.Text('No. ${document.documentNumber}'),
              pw.Text('日付: ${_formatDate(document.date)}'),
              pw.Text('顧客: ${document.customerName}'),
              pw.SizedBox(height: 16),
              pw.TableHelper.fromTextArray(
                headers: ['商品名', '数量', '単価', '小計'],
                data: document.items.map((item) => [
                  item.productName,
                  _formatQty(item.quantity),
                  _formatMoney(item.unitPrice),
                  _formatMoney(item.subtotal),
                ]).toList(),
              ),
              pw.SizedBox(height: 16),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Text('合計: ${_formatMoney(document.total)}'),
                ],
              ),
            ],
          ),
        ),
      );
      await Printing.sharePdf(
        bytes: await pdf.save(),
        filename: '${document.documentType.name}_${document.documentNumber}.pdf',
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('PDF出力エラー: $e')),
      );
    }
  }

  String _formatDate(DateTime dt) =>
    '${dt.year}/${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')}';

  String _formatMoney(int amount) =>
    '¥${amount.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}';

  String _formatQty(double qty) =>
    qty == qty.roundToDouble() ? qty.toInt().toString() : qty.toStringAsFixed(1);
}
