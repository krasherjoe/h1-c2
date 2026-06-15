import 'package:flutter/material.dart';
import '../models/document_model.dart';
import '../models/document_edit_log.dart';
import '../logic/document_converter.dart';
import '../services/document_repository.dart';
import '../../../services/customer_repository.dart';
import '../../../services/error_reporter.dart';
import '../../../models/document_type_colors.dart';
import '../../../plugins/printer/screens/printer_settings_screen.dart';
import 'document_preview_page.dart';

class DocumentViewer extends StatefulWidget {
  final DocumentModel document;

  const DocumentViewer({super.key, required this.document});

  @override
  State<DocumentViewer> createState() => _DocumentViewerState();
}

class _DocumentViewerState extends State<DocumentViewer> {
  late DocumentModel _document;
  List<DocumentEditLog> _editLogs = [];

  @override
  void initState() {
    super.initState();
    _document = widget.document;
    _load();
  }

  Future<void> _load() async {
    final repo = DocumentRepository();
    final updated = await repo.fetchById(widget.document.id);
    if (updated != null && mounted) setState(() => _document = updated);
    final logs = await repo.getEditLogs(widget.document.id);
    if (mounted) setState(() => _editLogs = logs);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(children: [
      Expanded(
        child: ListView(
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
            ...widget.document.items.map((item) => _buildItemCard(item, cs)),
            const SizedBox(height: 12),
            _buildTotalSection(cs),
            const SizedBox(height: 16),
            if (widget.document.isConfirmed) _buildConvertButton(context),
            const SizedBox(height: 12),
            _buildPdfButton(context),
            const SizedBox(height: 8),
            _buildReceiptButton(context),
          ],
        ),
      ),
      _buildEditLogSection(cs),
    ]);
  }

  Widget _buildHeader(BuildContext context, ColorScheme cs) {
    final docTypeColor = () {
      switch (_document.documentType) {
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
            color: docTypeColor.withValues(alpha: 0.25),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(_document.documentType.label,
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: docTypeColor)),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: _document.isDraft
                ? docTypeColor.withValues(alpha: 0.15)
                : docTypeColor,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            _document.isDraft ? '下書き' : '確定',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500,
              color: _document.isDraft
                  ? docTypeColor
                  : (docTypeColor.computeLuminance() > 0.5 ? Colors.black87 : Colors.white)),
          ),
        ),
        const Spacer(),
        Text(_document.documentNumber,
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
            Expanded(child: Text(_document.customerName, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: cs.onSurface))),
          ]),
          const SizedBox(height: 6),
          Row(children: [
            Icon(Icons.calendar_today, size: 14, color: cs.onSurfaceVariant),
            const SizedBox(width: 6),
            Text('${_document.date.year}/${_document.date.month.toString().padLeft(2, '0')}/${_document.date.day.toString().padLeft(2, '0')}',
              style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
            const Spacer(),
            Text(_document.documentNumber,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: cs.onSurfaceVariant)),
          ]),
          const SizedBox(height: 4),
          Row(children: [
            Icon(Icons.tag, size: 14, color: cs.onSurfaceVariant),
            const SizedBox(width: 6),
            Text('ID: ${_document.id.substring(0, 8)}...',
              style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
            if (_document.linkedDocumentId != null) ...[
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
    if (_document.subject == null || _document.subject!.isEmpty) return const SizedBox.shrink();
    return Row(children: [
      Icon(Icons.subject, size: 16, color: cs.onSurfaceVariant),
      const SizedBox(width: 6),
      Expanded(child: Text(_document.subject!, style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant))),
    ]);
  }

  Widget _buildDivider(ColorScheme cs) {
    return Divider(height: 1, color: cs.outlineVariant.withValues(alpha: 0.3));
  }

  Widget _buildItemsHeader(ColorScheme cs) {
    return Row(children: [
      Text('明細', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: cs.onSurface)),
      const Spacer(),
      Text('${_document.items.length}点', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
    ]);
  }

  Widget _buildItemCard(DocumentItem item, ColorScheme cs) {
    final hasDiscount = item.discountAmount != null || item.discountRate != null;
    final baseSubtotal = (item.quantity * item.unitPrice).round();
    final makerCode = [if (item.maker.isNotEmpty) item.maker, if (item.productCode.isNotEmpty) item.productCode].join(' / ');
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      elevation: 0.5,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(item.productName, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500, color: cs.onSurface)),
            if (makerCode.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(makerCode, style: TextStyle(fontSize: 11.5, color: cs.onSurfaceVariant)),
              ),
            if (item.notes != null && item.notes!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 1),
                child: Text(item.notes!, style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
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
          if (_document.discountAmount > 0) ...[
            _tr('小計', _document.subtotal, cs, labelColor: cs.onSurfaceVariant),
            _tr('値引き', -_document.discountAmount, cs, labelColor: cs.error),
          ],
          _tr('税抜合計', _document.taxableAmount, cs, labelColor: cs.onSurfaceVariant),
          _tr('消費税 (${(_document.taxRate * 100).round()}%)', _document.tax, cs, labelColor: cs.onSurfaceVariant),
          const Divider(height: 16),
          _tr('合計', _document.total, cs, totalStyle: true),
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
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        icon: const Icon(Icons.arrow_forward),
        label: const Text('コピーして他の伝票を作成'),
        onPressed: () async {
          final cs = Theme.of(context).colorScheme;
          final isDark = cs.brightness == Brightness.dark;
          final types = DocumentType.values.where((t) => t != _document.documentType).toList();
          final target = await showModalBottomSheet<DocumentType>(
            context: context,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            builder: (ctx) {
              final rows = (types.length + 1) ~/ 2;
              final screenH = MediaQuery.of(ctx).size.height;
              final cardH = ((screenH - 180) / rows).clamp(64.0, 100.0);
              return SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('コピーして作成', style: Theme.of(ctx).textTheme.titleMedium),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: rows * cardH + (rows - 1) * 8,
                        child: GridView.count(
                          crossAxisCount: 2,
                          mainAxisSpacing: 8,
                          crossAxisSpacing: 8,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          childAspectRatio: 180 / cardH,
                          children: types.map((t) {
                            final color = documentTypeColor(t, cs, isDark);
                            return InkWell(
                              onTap: () => Navigator.pop(ctx, t),
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: color.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(_iconForType(t), size: 32, color: color),
                                    const SizedBox(height: 6),
                                    Text(t.label,
                                        style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: color)),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('キャンセル'),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
          if (target == null || !context.mounted) return;
          try {
            final repo = DocumentRepository();
            final newDoc = copyAsDocument(_document, target);
            final docNumber = await repo.generateDocumentNumber(target);
            await repo.save(newDoc.copyWith(documentNumber: docNumber));
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('${target.label}伝票を作成しました（元の${_document.documentType.label}はそのままです）')),
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
          if (_document.customerId.isNotEmpty) {
            final customer = await CustomerRepository().getById(_document.customerId);
            customerEmail = customer?.email;
          }
          if (!context.mounted) return;
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => DocumentPreviewPage(
                document: _document,
                isUnlocked: _document.isDraft,
                onFormalIssue: () async {
                  try {
                    final updated = _document.copyWith(
                      status: 'confirmed',
                      isLocked: true,
                    );
                    await repo.save(updated);
                    final typeLabel = _document.documentType.label;
                    final totalStr = '¥${_document.total.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}';
                    await repo.addEditLog(_document.id, '正式発行',
                      details: '$typeLabel #${_document.documentNumber} ${totalStr}');
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
          await _load();
          if (_document.isLocked && mounted) {
            Navigator.pop(context, true);
          }
        },
      ),
    );
  }

  Widget _buildReceiptButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        icon: const Icon(Icons.receipt, size: 18),
        label: const Text('レシート'),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => PrinterSettingsScreen(document: _document)),
          );
        },
      ),
    );
  }

  Widget _buildEditLogSection(ColorScheme cs) {
    if (_editLogs.isEmpty) return const SizedBox.shrink();
    return Container(
      color: cs.surface,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('📝 編集履歴(2週間保持しています)',
            style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant)),
          const SizedBox(height: 4),
          ...(_editLogs.take(5)).map((log) => Container(
            margin: const EdgeInsets.only(bottom: 2),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: cs.surfaceContainerLow,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text('${log.createdAt.month}/${log.createdAt.day} ${log.createdAt.hour.toString().padLeft(2, '0')}:${log.createdAt.minute.toString().padLeft(2, '0')}',
                  style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant)),
                const SizedBox(width: 8),
                Text(log.action,
                  style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant)),
              ]),
              if (log.details.isNotEmpty)
                Text(log.details,
                  style: TextStyle(fontSize: 9, color: cs.onSurfaceVariant.withValues(alpha: 0.7)),
                  maxLines: 2, overflow: TextOverflow.ellipsis),
            ]),
          )),
        ],
      ),
    );
  }

  String _formatMoney(int amount) =>
    '¥${amount.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}';

  String _formatQty(double qty) =>
    qty == qty.roundToDouble() ? qty.toInt().toString() : qty.toStringAsFixed(1);

  IconData _iconForType(DocumentType t) => switch (t) {
    DocumentType.estimation => Icons.request_quote,
    DocumentType.order => Icons.shopping_cart_checkout,
    DocumentType.delivery => Icons.local_shipping,
    DocumentType.invoice => Icons.receipt_long,
    DocumentType.receipt => Icons.receipt,
  };
}
