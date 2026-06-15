import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import '../models/document_model.dart';
import '../logic/document_pdf_generator.dart' show generateDocumentPdf;
import '../../../services/error_reporter.dart';
import '../../../utils/theme_utils.dart';
import '../../../services/google_auth_service.dart';
import '../../../services/gmail_sender.dart';
import '../../accounting2/services/auto_journal_service.dart';
import '../../communication/communication_plugin.dart';

const _kPreviewDpi = 130.0;

class DocumentPreviewPage extends StatefulWidget {
  final DocumentModel document;
  final bool allowFormalIssue;
  final bool isUnlocked;
  final Future<bool> Function()? onFormalIssue;
  final bool showShare;
  final bool showPrint;
  final VoidCallback? onShare;
  final VoidCallback? onPrint;
  final String? customerEmail;

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
    this.customerEmail,
  });

  @override
  State<DocumentPreviewPage> createState() => _DocumentPreviewPageState();
}

class _DocumentPreviewPageState extends State<DocumentPreviewPage> {
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
      widget.document.isDraft &&
      widget.isUnlocked &&
      !_issued &&
      widget.onFormalIssue != null;

  DocumentModel get _effectiveDocument => _issued
      ? widget.document.copyWith(status: 'confirmed')
      : widget.document;

  Future<Uint8List> _buildPdfBytes([PdfPageFormat? format]) async {
    try {
      final doc = await generateDocumentPdf(_effectiveDocument);
      return Uint8List.fromList(await doc.save());
    } catch (e, st) {
      ErrorReporter.sendError(
        message: 'PDF生成失敗: $e',
        screenId: '/documents/preview',
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
    VoidCallback? onLongPress,
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
              onLongPress: enabled ? onLongPress : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: enabled ? cs.primary : null,
                foregroundColor: cs.onPrimary,
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
                  child: Text(badge, style: TextStyle(fontSize: 9, color: textColorOn(Colors.green.shade600), fontWeight: FontWeight.bold)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final effectiveIsLocked = !widget.document.isDraft || _issued;

    return Scaffold(
      appBar: AppBar(
        title: Text('PP:${widget.document.documentType.label} プレビュー'),
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
                    onLongPress: _canFormalIssue
                        ? () async {
                            final confirmed = await _showFormalIssueWarning(context);
                            if (!confirmed) return;
                            final ok = await widget.onFormalIssue!();
                            if (ok && mounted) {
                              setState(() {
                                _issued = true;
                                _stablePdfBuilder = (format) => _buildPdfBytes(format);
                              });
                              try {
                                final email = await GoogleAuthService.instance.getEmail();
                                if (email != null && email.isNotEmpty) {
                                  final bytes = await _buildPdfBytes();
                                  await GmailSender.sendPdf(
                                    to: email,
                                    subject: '${widget.document.documentType.label} ${widget.document.documentNumber}（控え）',
                                    body: '正式発行された伝票の控えです。',
                                    pdfBytes: bytes,
                                    pdfFilename: '${widget.document.documentType.name}_${widget.document.documentNumber}.pdf',
                                  );
                                }
                              } catch (_) {}
                              try {
                                final journal = AutoJournalService();
                                if (widget.document.documentType.name == 'invoice') {
                                  await journal.createFromInvoice(
                                    documentId: widget.document.id,
                                    total: widget.document.total,
                                    date: widget.document.date,
                                    customerName: widget.document.customerName,
                                  );
                                } else if (widget.document.documentType.name == 'receipt') {
                                  await journal.createFromReceipt(
                                    documentId: widget.document.id,
                                    amount: widget.document.total,
                                    date: widget.document.date,
                                    customerName: widget.document.customerName,
                                  );
                                }
                              } catch (_) {}
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
                    icon: Icons.email,
                    label: 'メール',
                    enabled: widget.showShare,
                    onPressed: () async {
                      final recipient = await showDialog<String>(
                        context: context,
                        builder: (ctx) {
                          final ctrl = TextEditingController();
                          return AlertDialog(
                            title: const Text('送信先メールアドレス'),
                            content: TextField(
                              controller: ctrl,
                              keyboardType: TextInputType.emailAddress,
                              decoration: const InputDecoration(
                                hintText: 'example@example.com',
                                labelText: 'To',
                              ),
                              autofocus: true,
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx),
                                child: const Text('キャンセル'),
                              ),
                              ElevatedButton(
                                onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
                                child: const Text('送信'),
                              ),
                            ],
                          );
                        },
                      );
                      if (recipient == null || recipient.isEmpty || !mounted) return;

                      final email = await GoogleAuthService.instance.getEmail();
                      if (!mounted) return;

                      if (email == null) {
                        final ok = await GoogleAuthService.instance.signIn();
                        if (!ok || !mounted) return;
                      }

                      final bytes = await _buildPdfBytes();
                      final filename = '${widget.document.documentType.name}_${widget.document.documentNumber}.pdf';
                      final subject = '${widget.document.documentType.label} ${widget.document.documentNumber}';
                      final body = '${widget.document.documentType.label}を添付してお送りします。';

                      if (!mounted) return;

                      final success = await GmailSender.sendPdf(
                        to: recipient,
                        subject: subject,
                        body: body,
                        pdfBytes: bytes,
                        pdfFilename: filename,
                      );

                      if (success) {
                        if (mounted) {
                          ScaffoldMessenger.of(this.context).showSnackBar(
                            const SnackBar(content: Text('メールを送信しました')),
                          );
                        }
                        return;
                      }

                      final osOk = await CommunicationPlugin().sendEmailWithPdf(
                        pdfBytes: bytes,
                        filename: filename,
                        subject: subject,
                        body: body,
                        recipients: [recipient],
                      );
                      if (mounted) {
                        ScaffoldMessenger.of(this.context).showSnackBar(
                          SnackBar(content: Text(
                            osOk ? 'OSメールアプリを起動しました' : 'メール送信に失敗しました',
                          )),
                        );
                      }
                    },
                    onLongPress: () async {
                      final scaffold = ScaffoldMessenger.of(context);
                      scaffold.showSnackBar(
                        const SnackBar(content: Text('PDFを準備中...'), duration: Duration(seconds: 1)),
                      );
                      try {
                        final bytes = await _buildPdfBytes();
                        final filename = '${widget.document.documentType.name}_${widget.document.documentNumber}.pdf';
                        final subject = '${widget.document.documentType.label} ${widget.document.documentNumber}';
                        final body = '${widget.document.documentType.label}を添付してお送りします。';
                        final recipients = widget.customerEmail != null && widget.customerEmail!.isNotEmpty
                            ? [widget.customerEmail!] : <String>[];

                        final ok = await GmailSender.sendPdf(
                          to: recipients.isNotEmpty ? recipients.first : '',
                          subject: subject,
                          body: body,
                          pdfBytes: bytes,
                          pdfFilename: filename,
                        );
                        if (ok) {
                          if (mounted) {
                            scaffold.showSnackBar(
                              const SnackBar(content: Text('メールを送信しました')),
                            );
                          }
                          return;
                        }

                        final osOk = await CommunicationPlugin().sendEmailWithPdf(
                          pdfBytes: bytes,
                          filename: filename,
                          subject: subject,
                          body: body,
                          recipients: recipients,
                        );
                        if (mounted) {
                          scaffold.showSnackBar(
                            SnackBar(content: Text(
                              osOk ? 'メールアプリを起動しました' : 'メール送信に失敗しました',
                            )),
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          scaffold.showSnackBar(
                            SnackBar(content: Text('メール送信エラー: $e')),
                          );
                        }
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
