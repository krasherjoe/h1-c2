import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import '../models/purchase_model.dart';
import '../logic/purchase_pdf_generator.dart' show generatePurchasePdf;
import '../../../services/error_reporter.dart';
import '../../../services/google_auth_service.dart';
import '../../../services/gmail_sender.dart';

const _kPreviewDpi = 96.0;

class PurchasePreviewPage extends StatefulWidget {
  final PurchaseModel purchase;
  final bool allowFormalIssue;
  final bool isUnlocked;
  final Future<bool> Function()? onFormalIssue;
  final bool showShare;
  final bool showPrint;
  final VoidCallback? onShare;
  final VoidCallback? onPrint;

  const PurchasePreviewPage({
    super.key,
    required this.purchase,
    this.allowFormalIssue = true,
    this.isUnlocked = false,
    this.onFormalIssue,
    this.showShare = true,
    this.showPrint = true,
    this.onShare,
    this.onPrint,
  });

  @override
  State<PurchasePreviewPage> createState() => _PurchasePreviewPageState();
}

class _PurchasePreviewPageState extends State<PurchasePreviewPage> {
  bool _issued = false;
  String? _error;
  late Future<Uint8List> Function(PdfPageFormat) _stablePdfBuilder;

  @override
  void initState() {
    super.initState();
    _stablePdfBuilder = (format) => _buildPdfBytes(format);
  }

  bool get _canFormalIssue =>
      widget.allowFormalIssue &&
      widget.purchase.isDraft &&
      widget.isUnlocked &&
      !_issued &&
      widget.onFormalIssue != null;

  PurchaseModel get _effectivePurchase => _issued
      ? widget.purchase.copyWith(status: 'confirmed')
      : widget.purchase;

  Future<Uint8List> _buildPdfBytes([PdfPageFormat? format]) async {
    try {
      final doc = await generatePurchasePdf(_effectivePurchase);
      return Uint8List.fromList(await doc.save());
    } catch (e, st) {
      ErrorReporter.sendError(
        message: 'PDF生成失敗: $e',
        screenId: '/purchase/preview',
        stackTrace: st,
      );
      if (mounted) setState(() => _error = 'PDFの生成に失敗しました\n$e');
      rethrow;
    }
  }

  Future<bool> _showFormalIssueWarning(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${widget.purchase.purchaseType.label} の正式発行'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.purchase.supplierName),
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
    final isDraft = widget.purchase.isDraft && !_issued;
    final effectiveIsLocked = !widget.purchase.isDraft || _issued;

    return Scaffold(
      appBar: AppBar(
        title: Text('PP:${widget.purchase.purchaseType.label} プレビュー'),
      ),
      body: Column(
        children: [
          Expanded(
            child: _error != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(_error!, textAlign: TextAlign.center,
                          style: TextStyle(color: Theme.of(context).colorScheme.error)),
                    ),
                  )
                : PdfPreview(
                    key: ValueKey(_issued),
                    initialPageFormat: PdfPageFormat.a4,
                    dpi: _kPreviewDpi,
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
                              filename: '${widget.purchase.purchaseType.name}_${widget.purchase.documentNumber}.pdf',
                            );
                            widget.onShare?.call();
                          }
                        : null,
                  ),
                  const SizedBox(width: 4),
                  _ppButton(
                    icon: Icons.email,
                    label: 'メール',
                    enabled: widget.showShare,
                    onPressed: () async {
                      final email = await GoogleAuthService.instance.getEmail();
                      if (!mounted) return;
                      
                      if (email == null) {
                        final ok = await GoogleAuthService.instance.signIn();
                        if (!ok) return;
                      }
                      
                      final bytes = await _buildPdfBytes();
                      final success = await GmailSender.sendPdf(
                        to: '',
                        subject: '${widget.purchase.purchaseType.label} ${widget.purchase.documentNumber}',
                        body: '${widget.purchase.purchaseType.label}を添付してお送りします。',
                        pdfBytes: bytes,
                        pdfFilename: '${widget.purchase.purchaseType.name}_${widget.purchase.documentNumber}.pdf',
                      );
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(success ? '送信しました' : '送信できませんでした')),
                        );
                      }
                    },
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
