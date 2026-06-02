import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import '../models/document_model.dart';
import '../services/document_repository.dart';
import '../../../services/error_reporter.dart';
import '../logic/document_pdf_generator.dart' show generateDocumentPdf;

class DocumentPreviewPage extends StatelessWidget {
  final DocumentModel document;

  const DocumentPreviewPage({super.key, required this.document});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final currencyFmt = NumberFormat('#,###');

    return Scaffold(
      appBar: AppBar(
        title: Text('${document.documentType.label} プレビュー'),
        actions: [
          if (document.isDraft)
            TextButton.icon(
              icon: const Icon(Icons.lock),
              label: const Text('正式発行'),
              onPressed: () => _formalIssue(context),
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('No. ${document.documentNumber}',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: cs.onSurface)),
            const SizedBox(height: 8),
            Text('日付: ${DateFormat('yyyy/MM/dd').format(document.date)}',
                style: TextStyle(fontSize: 14, color: cs.onSurfaceVariant)),
            const SizedBox(height: 4),
            Text('顧客: ${document.customerName}',
                style: TextStyle(fontSize: 14, color: cs.onSurfaceVariant)),
            const SizedBox(height: 16),
            Divider(color: cs.outlineVariant),
            const SizedBox(height: 8),
            Expanded(
              child: ListView(
                children: document.items.map((item) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Expanded(child: Text(item.productName)),
                      Text('${item.quantity == item.quantity.roundToDouble() ? item.quantity.toInt().toString() : item.quantity.toStringAsFixed(1)} × ${currencyFmt.format(item.unitPrice)}'),
                      const SizedBox(width: 8),
                      Text(currencyFmt.format(item.subtotal)),
                    ],
                  ),
                )).toList(),
              ),
            ),
            Divider(color: cs.outlineVariant),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text('合計: ¥${currencyFmt.format(document.total)}',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: cs.onSurface)),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.picture_as_pdf),
                label: const Text('PDFを表示・印刷'),
                onPressed: () => _showPdf(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _formalIssue(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('正式発行の確認'),
        content: const Text('この伝票を正式発行します。発行後は編集できなくなります。\n\n内容を最終確認のうえ実行してください。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('キャンセル')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('正式発行')),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    try {
      final repo = DocumentRepository();
      final updated = document.copyWith(status: 'confirmed');
      await repo.save(updated);
      if (!context.mounted) return;
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('正式発行しました')),
      );
    } catch (e, st) {
      ErrorReporter.sendError(
        message: '正式発行失敗: $e',
        screenId: '/documents/preview',
        stackTrace: st,
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('正式発行エラー: $e')),
      );
    }
  }

  Future<void> _showPdf(BuildContext context) async {
    try {
      final pdf = await generateDocumentPdf(document);
      await Printing.layoutPdf(onLayout: (_) => pdf.save());
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('PDFエラー: $e')),
      );
    }
  }
}
