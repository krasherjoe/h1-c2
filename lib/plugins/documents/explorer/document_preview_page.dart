import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import '../models/document_model.dart';
import '../logic/document_pdf_generator.dart' show generateDocumentPdf;
import '../../../services/error_reporter.dart';

const _kPageFormat = PdfPageFormat(100, 120, marginAll: 8);

class DocumentPreviewPage extends StatefulWidget {
  final DocumentModel document;
  final bool allowFormalIssue;
  final bool isUnlocked;
  final Future<bool> Function()? onFormalIssue;
  final bool showShare;
  final bool showPrint;
  final VoidCallback? onShare;
  final VoidCallback? onPrint;

  const DocumentPreviewPage({
    super.key,
    required this.document,
    this.allowFormalIssue = true,
    this.isUnlocked = false,
    this.onFormalIssue,
    this.showShare = true,
    this.showPrint = true,
    this.onShare,
    this.onPrint,
  });

  @override
  State<DocumentPreviewPage> createState() => _DocumentPreviewPageState();
}

class _DocumentPreviewPageState extends State<DocumentPreviewPage> {
  bool _issued = false;
  late Future<Uint8List> Function(PdfPageFormat) _stablePdfBuilder;

  @override
  void initState() {
    super.initState();
    _stablePdfBuilder = (format) => _buildPdfBytes(format);
  }

  bool get _canFormalIssue =>
      widget.allowFormalIssue &&
      widget.document.isDraft &&
      widget.isUnlocked &&
      !_issued &&
      widget.onFormalIssue != null;

  DocumentModel get _effectiveDocument => _issued
      ? widget.document.copyWith(status: 'confirmed')
      : widget.document;

  Future<Uint8List> _buildPdfBytes([PdfPageFormat? format]) async {
    final doc = await generateDocumentPdf(_effectiveDocument);
    return Uint8List.fromList(await doc.save());
  }

  Future<bool> _showFormalIssueWarning(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${widget.document.documentType.label} の正式発行'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.document.customerName),
            const SizedBox(height: 8),
            const Text(
              'この伝票を正式発行すると、\n二度と編集できなくなります。\n\n確定してよろしいですか？',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('正式発行する'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Widget _ppButton({
    required IconData icon,
    required String label,
    required bool enabled,
    VoidCallback? onPressed,
    String? badge,
  }) {
    final cs = Theme.of(context).colorScheme;
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            ElevatedButton(
              onPressed: enabled ? onPressed : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: enabled ? cs.primary : null,
                foregroundColor: cs.onPrimary,
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 20),
                  const SizedBox(height: 2),
                  Text(label, style: const TextStyle(fontSize: 11), overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            if (badge != null)
              Positioned(
                right: 4, top: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: Colors.green.shade600,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: cs.surface, width: 1.5),
                  ),
                  child: Text(badge, style: const TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDraft = widget.document.isDraft && !_issued;
    final effectiveIsLocked = !widget.document.isDraft || _issued;

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.document.documentType.label} プレビュー'),
      ),
      body: Column(
        children: [
          Expanded(
            child: PdfPreview(
              key: ValueKey(_issued),
              initialPageFormat: _kPageFormat,
              build: _stablePdfBuilder,
              allowPrinting: false,
              allowSharing: false,
              canChangePageFormat: false,
              canChangeOrientation: false,
              canDebug: false,
              actions: const [],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
              child: Row(
                children: [
                  _ppButton(
                    icon: Icons.check_circle_outline,
                    label: effectiveIsLocked ? '正式発行🔒' : '正式発行',
                    badge: _issued ? '済' : null,
                    enabled: _canFormalIssue,
                    onPressed: _canFormalIssue
                        ? () async {
                            final confirmed = await _showFormalIssueWarning(context);
                            if (!confirmed) return;
                            final ok = await widget.onFormalIssue!();
                            if (ok && mounted) {
                              setState(() {
                                _issued = true;
                                _stablePdfBuilder = (format) => _buildPdfBytes(format);
                              });
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('正式発行が完了しました')),
                                );
                              }
                            }
                          }
                        : null,
                  ),
                  const SizedBox(width: 4),
                  _ppButton(
                    icon: Icons.share,
                    label: '共有',
                    enabled: widget.showShare,
                    onPressed: widget.showShare
                        ? () async {
                            final bytes = await _buildPdfBytes();
                            await Printing.sharePdf(
                              bytes: bytes,
                              filename: '${widget.document.documentType.name}_${widget.document.documentNumber}.pdf',
                            );
                            widget.onShare?.call();
                          }
                        : null,
                  ),
                  const SizedBox(width: 4),
                  _ppButton(
                    icon: Icons.print,
                    label: '印刷',
                    enabled: widget.showPrint,
                    onPressed: widget.showPrint
                        ? () async {
                            await Printing.layoutPdf(
                              onLayout: (format) async => _buildPdfBytes(format),
                            );
                            widget.onPrint?.call();
                          }
                        : null,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
