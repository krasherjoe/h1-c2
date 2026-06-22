import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/services.dart';
import '../../../utils/theme_utils.dart' show textColorOn, cardDecoration;
import 'package:uuid/uuid.dart';
import 'dart:async';
import '../models/document_model.dart';
import '../models/document_edit_log.dart';
import '../logic/document_converter.dart';
import '../services/document_repository.dart';
import '../../../services/customer_repository.dart';
import '../../../services/project_repository.dart';
import '../../../services/database_helper.dart';
import '../../../services/error_reporter.dart';
import '../../../services/ar_report_generator.dart';
import '../../../services/sales_queue_repository.dart';
import '../../../models/document_type_colors.dart';
import '../../../widgets/document_edit_log_section.dart';
import '../../../widgets/document_summary_section.dart';
import '../../../widgets/document_item_card.dart';
import '../../printer/screens/printer_settings_screen.dart';
import '../../customers/screens/customer_edit_screen.dart';
import '../../project/models/project_explorer_item.dart';
import '../../project/screens/project_detail_screen.dart';
import '../../explorer/h1_explorer.dart';
import '../../project/explorer/project_explorer_config.dart';
import '../../products/widgets/variant_picker_sheet.dart';
import '../explorer/document_preview_page.dart';
import 'package:printing/printing.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import '../logic/document_pdf_generator.dart' show generateDocumentPdf;
import '../../../services/history_repository.dart';

class DocumentPage extends StatefulWidget {
  final DocumentModel? document;
  final bool isEditing;
  final DocumentType? initialType;

  const DocumentPage({super.key, this.document, this.isEditing = false, this.initialType});

  @override
  State<DocumentPage> createState() => _DocumentPageState();
}

class _DocumentPageState extends State<DocumentPage> {
  final _repo = DocumentRepository();
  final _uuid = const Uuid();
  final _titleCtl = TextEditingController();
  final _memoCtl = TextEditingController();
  final _arReportGenerator = ArReportGenerator();
  final _customerRepo = CustomerRepository();
  List<DocumentEditLog> _editLogs = [];
  bool _loading = true;
  bool _copied = false;

  late DocumentType _type;
  late String _customerId;
  late String _customerName;
  late DateTime _date;
  bool _includeTax = false;
  int? _totalDiscountAmount;
  double? _totalDiscountRate;
  String? _projectId;
  String? _projectName;
  late List<_EditableItem> _items;
  List<_EditableItem> _originalItems = [];
  bool _attachArReport = false;
  String? _priceAdjustmentType;
  int? _priceAdjustmentUnit;

  static const _maxUndo = 30;
  List<_Snapshot> _undoStack = [];
  List<_Snapshot> _redoStack = [];
  bool _isSaving = false;
  _Snapshot? _initialSnapshot;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _titleCtl.dispose();
    _memoCtl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final doc = widget.document;
    _type = doc?.documentType ?? widget.initialType ?? DocumentType.invoice;
    _customerId = doc?.customerId ?? '';
    _customerName = doc?.customerName ?? '';
    _date = doc?.date ?? DateTime.now();
    _projectId = doc?.projectId;
    _includeTax = doc?.includeTax ?? false;
    _totalDiscountAmount = doc?.totalDiscountAmount;
    _totalDiscountRate = doc?.totalDiscountRate;
    _priceAdjustmentType = doc?.priceAdjustmentType;
    _priceAdjustmentUnit = doc?.priceAdjustmentUnit;
    final subjLines = (doc?.subject ?? '').split('\n');
    _attachArReport = doc?.attachArReport ?? false;
    _titleCtl.text = subjLines.first;
    _memoCtl.text = subjLines.length > 1 ? subjLines.sublist(1).join('\n') : '';
    _items = (doc?.items ?? []).map((e) => _EditableItem(
      id: e.id, productId: e.productId, productName: e.productName,
      maker: e.maker, productCode: e.productCode,
      quantity: e.quantity, unitPrice: e.unitPrice, taxRate: e.taxRate,
      discountAmount: e.discountAmount, discountRate: e.discountRate, notes: e.notes,
    )).toList();
    _originalItems = _items.map((e) => _EditableItem(
      id: e.id, productId: e.productId, productName: e.productName,
      maker: e.maker, productCode: e.productCode,
      quantity: e.quantity, unitPrice: e.unitPrice, taxRate: e.taxRate,
      discountAmount: e.discountAmount, discountRate: e.discountRate, notes: e.notes,
    )).toList();
    if (_projectId != null) {
      final p = await ProjectRepository().getById(_projectId!);
      if (p != null) _projectName = p.name;
    }
    if (doc != null) {
      _editLogs = await _repo.getEditLogs(doc.id);
    }
    if (mounted) setState(() {
      _initialSnapshot = _snapshotFromCurrent();
      _loading = false;
    });
  }

  bool _hasChanges() {
    if (_initialSnapshot == null) return true;
    final s = _initialSnapshot!;
    if (_type != s.type) return true;
    if (_customerId != s.customerId) return true;
    if (_customerName != s.customerName) return true;
    if (_date != s.date) return true;
    if (_projectId != s.projectId) return true;
    if (_titleCtl.text != s.title) return true;
    if (_memoCtl.text != s.memo) return true;
    if (_includeTax != s.includeTax) return true;
    if (_totalDiscountAmount != s.totalDiscountAmount) return true;
    if (_totalDiscountRate != s.totalDiscountRate) return true;
    if (_priceAdjustmentType != s.priceAdjustmentType) return true;
    if (_priceAdjustmentUnit != s.priceAdjustmentUnit) return true;
    if (_items.length != s.items.length) return true;
    for (var i = 0; i < _items.length; i++) {
      final a = _items[i], b = s.items[i];
      if (a.productId != b.productId || a.productName != b.productName ||
          a.maker != b.maker || a.productCode != b.productCode ||
          a.quantity != b.quantity || a.unitPrice != b.unitPrice ||
          a.taxRate != b.taxRate ||
          a.discountAmount != b.discountAmount ||
          a.discountRate != b.discountRate ||
          a.notes != b.notes) return true;
    }
    return false;
  }

  int get _subtotal => _items.fold(0, (s, i) => s + i.subtotal);
  int get _discountAmount {
    if (_totalDiscountAmount != null && _totalDiscountAmount! > 0) return _totalDiscountAmount!;
    if (_totalDiscountRate != null && _totalDiscountRate! > 0) return (_subtotal * _totalDiscountRate!).round();
    return 0;
  }
  int get _priceAdjustmentDiscount {
    if (_priceAdjustmentType == null || _priceAdjustmentUnit == null) return 0;
    if (_priceAdjustmentType == 'manual') return _priceAdjustmentUnit!;
    final unit = _priceAdjustmentUnit!;
    final base = _subtotal - _discountAmount;
    int adjustedTotal;
    switch (_priceAdjustmentType) {
      case 'round_down':
        adjustedTotal = (base ~/ unit) * unit;
      case 'round_up':
        adjustedTotal = ((base + unit - 1) ~/ unit) * unit;
      case 'round_nearest':
        adjustedTotal = ((base + unit ~/ 2) ~/ unit) * unit;
      default:
        return 0;
    }
    return base - adjustedTotal;
  }
  String? get _priceAdjustmentLabel {
    if (_priceAdjustmentType == null) return null;
    switch (_priceAdjustmentType) {
      case 'round_down': return '端数調整（切捨）';
      case 'round_up': return '端数調整（切上）';
      case 'round_nearest': return '端数調整（四捨五入）';
      case 'manual': return '端数調整（手動）';
      default: return '端数調整';
    }
  }
  int get _totalDiscount => _discountAmount + _priceAdjustmentDiscount;
  int get _taxable => _subtotal - _totalDiscount;
  int get _tax => _includeTax ? (_taxable * 0.10).floor() : 0;
  int get _grandTotal => _taxable + _tax;

  void _snapshot() {
    _undoStack.add(_Snapshot(
      type: _type, customerId: _customerId, customerName: _customerName, date: _date,
      projectId: _projectId, projectName: _projectName,
      title: _titleCtl.text, memo: _memoCtl.text,
      includeTax: _includeTax, totalDiscountAmount: _totalDiscountAmount, totalDiscountRate: _totalDiscountRate,
      priceAdjustmentType: _priceAdjustmentType, priceAdjustmentUnit: _priceAdjustmentUnit,
      items: _items.map((e) => _EditableItem(
        id: e.id, productId: e.productId, productName: e.productName, maker: e.maker, productCode: e.productCode,
        quantity: e.quantity, unitPrice: e.unitPrice, taxRate: e.taxRate,
        discountAmount: e.discountAmount, discountRate: e.discountRate, notes: e.notes,
      )).toList(),
    ));
    if (_undoStack.length > _maxUndo) _undoStack.removeAt(0);
    _redoStack.clear();
  }

  DocumentModel _buildDoc() {
    final title = _titleCtl.text.trim();
    final memo = _memoCtl.text.trim();
    final merged = [if (title.isNotEmpty) title, if (memo.isNotEmpty) memo].join('\n');
    return DocumentModel(
      id: widget.document?.id ?? _repo.generateId(),
      documentType: _type, customerId: _customerId, customerName: _customerName,
      documentNumber: widget.document?.documentNumber ?? '',
      date: _date, total: 0, status: 'draft', projectId: _projectId,
      subject: merged.isNotEmpty ? merged : null, includeTax: _includeTax,
      taxRate: 0.10, totalDiscountAmount: _totalDiscountAmount, totalDiscountRate: _totalDiscountRate,
      priceAdjustmentType: _priceAdjustmentType, priceAdjustmentUnit: _priceAdjustmentUnit,
      items: _items.map((e) => DocumentItem(
        id: e.id, productId: e.productId, productName: e.productName,
        maker: e.maker, productCode: e.productCode,
        quantity: e.quantity, unitPrice: e.unitPrice, taxRate: e.taxRate,
        discountAmount: e.discountAmount, discountRate: e.discountRate, notes: e.notes,
      )).toList(),
      attachArReport: _attachArReport,
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_copied) return _buildCopiedView(cs);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context, true),
        ),
        title: Text(widget.isEditing
          ? (widget.document != null ? 'DE:書類編集' : 'DE:新規書類')
          : 'DV:伝票閲覧'),
        actions: widget.isEditing ? [
          if (_type == DocumentType.invoice)
            Row(
              children: [
                const Text('売掛', style: TextStyle(fontSize: 12)),
                const SizedBox(width: 8),
                Switch(
                  value: _attachArReport,
                  onChanged: (value) => setState(() => _attachArReport = value),
                  activeColor: cs.primary,
                ),
              ],
            ),
          if (_undoStack.isNotEmpty)
            IconButton(icon: const Icon(Icons.undo), onPressed: () {
              if (_undoStack.isEmpty) return;
              _redoStack.add(_snapshotFromCurrent());
              final s = _undoStack.removeLast();
              _apply(s);
            }, tooltip: '元に戻す'),
          if (_redoStack.isNotEmpty)
            IconButton(icon: const Icon(Icons.redo), onPressed: () {
              _snapshot();
              final s = _redoStack.removeLast();
              _apply(s);
            }, tooltip: 'やり直す'),
          IconButton(
            icon: _isSaving
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.save),
            onPressed: _isSaving ? null : _save,
            tooltip: '保存',
          ),
        ] : [
          if (_type == DocumentType.invoice)
            Row(
              children: [
                const Text('売掛', style: TextStyle(fontSize: 12)),
                const SizedBox(width: 8),
                Switch(
                  value: _attachArReport,
                  onChanged: (value) => setState(() => _attachArReport = value),
                  activeColor: cs.primary,
                ),
              ],
            ),
          if (!_isLocked)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(
                  builder: (_) => DocumentPage(document: widget.document, isEditing: true),
                )).then((_) => _load());
              },
              tooltip: '編集',
            ),
          IconButton(
            icon: const Icon(Icons.print),
            onPressed: _printDocument,
            tooltip: '印刷',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          _buildTypeBadge(cs),
          const SizedBox(height: 12),
          _buildDateRow(cs),
          const SizedBox(height: 12),
          if (widget.isEditing) _buildSubjectField(cs) else _buildSubjectDisplay(cs),
          const SizedBox(height: 12),
          _buildCustomerRow(cs),
          if (_projectId != null) ...[
            const SizedBox(height: 12),
            _buildProjectRow(cs),
          ],
          if (widget.isEditing) ...[
            const SizedBox(height: 12),
            if (_projectId == null) _buildProjectRow(cs),
            const SizedBox(height: 12),
            _buildTaxToggle(cs),
          ],
          const SizedBox(height: 8),
          _buildItems(cs),
          const SizedBox(height: 12),
          DocumentSummarySection(
            subtotal: _subtotal, discountAmount: _discountAmount,
            taxableAmount: _taxable, tax: _tax, total: _grandTotal,
            taxRate: 0.10, formatMoney: _formatMoney,
            showDiscountOnly: !widget.isEditing,
            totalLabelIsTaxIncluded: widget.isEditing,
            showTaxExcludedIfDifferent: widget.isEditing,
            priceAdjustmentAmount: _priceAdjustmentDiscount > 0 ? _priceAdjustmentDiscount : null,
            priceAdjustmentLabel: _priceAdjustmentLabel,
            onPriceAdjustmentTap: widget.isEditing ? _showPriceAdjustmentDialog : null,
            paymentStatus: widget.document?.paymentStatus,
            receivedAmount: widget.document?.receivedAmount,
          ),
          if (!widget.isEditing) ...[
            const SizedBox(height: 16),
            SizedBox(width: double.infinity, child: OutlinedButton.icon(
              icon: const Icon(Icons.arrow_forward), label: const Text('コピーして他の伝票を作成'),
              onPressed: () => _copyDocument(context, cs),
            )),
            const SizedBox(height: 12),
            SizedBox(width: double.infinity, child: FilledButton.icon(
              icon: const Icon(Icons.preview), label: const Text('プレビュー'), onPressed: _preview,
            )),
            const SizedBox(height: 8),
            SizedBox(width: double.infinity, child: OutlinedButton.icon(
              icon: const Icon(Icons.receipt, size: 18), label: const Text('レシート'),
              onPressed: () => Navigator.push(context, MaterialPageRoute(
                builder: (_) => PrinterSettingsScreen(document: _buildDoc()),
              )),
            )),
            if (_isLocked && !_isRedInvoice) ...[
              const SizedBox(height: 8),
              SizedBox(width: double.infinity, child: OutlinedButton.icon(
                icon: Icon(Icons.cancel_outlined, color: cs.error),
                label: Text('赤伝を発行', style: TextStyle(color: cs.error)),
                onPressed: () => _issueCreditNote(context, cs),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: cs.error.withValues(alpha: 0.5)),
                ),
              )),
            ],
          ],
          if (_memoCtl.text.isNotEmpty || widget.isEditing) ...[
            const SizedBox(height: 16),
            Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('📝 メモ', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: cs.onSurfaceVariant)),
                const SizedBox(height: 4),
                widget.isEditing
                  ? TextField(controller: _memoCtl, maxLines: null, minLines: 2,
                      decoration: const InputDecoration(border: InputBorder.none, isDense: true, hintText: '任意のメモ（自由記述）'),
                      style: TextStyle(fontSize: 12, color: cs.onSurface))
                  : Text(_memoCtl.text, style: const TextStyle(fontSize: 12)),
              ],
            ))),
          ],
          const SizedBox(height: 12),
          DocumentEditLogSection(editLogs: _editLogs, colorScheme: cs),
        ],
      ),
    );
  }

  bool get _isLocked => widget.document?.isLocked ?? false;
  bool get _isRedInvoice => widget.document?.isRedInvoice ?? false;

  Widget _buildTypeBadge(ColorScheme cs) {
    final color = documentTypeColor(_type, cs, cs.brightness == Brightness.dark);
    final isDraft = widget.document?.isDraft ?? true;
    final surface = cs.surface;
    return Row(children: [
      Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color, width: 1.2)),
        child: Text(_type.label, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: color))),
      const SizedBox(width: 8),
      if (isDraft)
        Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: color, width: 1)),
          child: Text('下書き', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: color)))
      else
        Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4)),
          child: Text('確定', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500,
            color: textColorOn(color)))),
      const Spacer(),
      if (widget.document?.documentNumber != null && widget.document!.documentNumber.isNotEmpty)
        GestureDetector(
          onTap: () {
            Clipboard.setData(ClipboardData(text: widget.document!.documentNumber));
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('伝票コードをコピーしました: ${widget.document!.documentNumber}'), duration: const Duration(seconds: 2)),
            );
          },
          child: Text(widget.document!.documentNumber,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: cs.onSurfaceVariant)),
        ),
    ]);
  }

  Widget _buildDateRow(ColorScheme cs) {
    return Container(
      decoration: cardDecoration(cs, color: cs.surfaceContainerLow, radius: 12).copyWith(
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.3))),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: widget.isEditing ? () async {
          final p = await showDatePicker(context: context, initialDate: _date,
            firstDate: DateTime(2000), lastDate: DateTime(2100));
          if (p != null && mounted) setState(() => _date = p);
        } : null,
        child: Padding(padding: const EdgeInsets.all(14),
          child: Row(children: [
            Icon(Icons.calendar_today, size: 20, color: cs.primary),
            const SizedBox(width: 12),
            Text('伝票日付:', style: TextStyle(fontSize: 14, color: cs.onSurfaceVariant)),
            const SizedBox(width: 8),
            Text('${_date.year}/${_date.month.toString().padLeft(2, '0')}/${_date.day.toString().padLeft(2, '0')}',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: cs.onSurface)),
            if (widget.isEditing) ...[const Spacer(), Icon(Icons.chevron_right, size: 20, color: cs.onSurfaceVariant)],
          ]),
        ),
      ),
    );
  }

  Widget _buildSubjectDisplay(ColorScheme cs) {
    if (_titleCtl.text.isEmpty) return const SizedBox.shrink();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(children: [
          Icon(Icons.subject, size: 16, color: cs.onSurfaceVariant),
          const SizedBox(width: 6),
          Expanded(child: Text(_titleCtl.text, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: cs.onSurface))),
        ]),
      ),
    );
  }

  Widget _buildSubjectField(ColorScheme cs) {
    return Container(
      decoration: cardDecoration(cs, color: cs.surfaceContainerLow, radius: 12).copyWith(
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.3))),
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      child: TextField(controller: _titleCtl, maxLines: 1,
        decoration: InputDecoration(border: InputBorder.none, isDense: true, hintText: '件名',
          hintStyle: TextStyle(color: cs.onSurfaceVariant.withValues(alpha: 0.5), fontWeight: FontWeight.normal)),
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: cs.onSurface)),
    );
  }

  Widget _buildCustomerRow(ColorScheme cs) {
    if (!widget.isEditing) {
      return Container(padding: const EdgeInsets.all(12),
        decoration: cardDecoration(cs, color: cs.surfaceContainerLow, radius: 8).copyWith(
          border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.3))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.business, size: 16, color: cs.onSurfaceVariant), const SizedBox(width: 6),
            Expanded(child: Text('$_customerName 様', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: cs.onSurface))),
          ]),
        ]));
    }
    return Container(
      decoration: cardDecoration(cs, color: cs.surfaceContainerLow, radius: 12).copyWith(
        border: Border.all(color: cs.outlineVariant)),
      child: ListTile(
        leading: Icon(Icons.business, color: cs.primary),
        title: Text(_customerName.isNotEmpty ? _customerName : '取引先を選択',
          style: TextStyle(fontWeight: FontWeight.w500, color: _customerName.isNotEmpty ? cs.onSurface : cs.onSurfaceVariant)),
        subtitle: _customerName.isNotEmpty ? Text('タップして変更', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)) : null,
        trailing: Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
        onTap: () => _selectCustomer(),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildProjectRow(ColorScheme cs) {
    final hasProject = _projectId != null;
    return Container(
      decoration: cardDecoration(cs, color: cs.surfaceContainerLow, radius: 12).copyWith(
        border: Border.all(color: hasProject ? cs.primary.withValues(alpha: 0.3) : cs.outlineVariant)),
      child: ListTile(
        leading: Icon(hasProject ? Icons.workspaces : Icons.folder, color: cs.primary),
        title: Text(_projectName ?? '案件なし', style: TextStyle(fontWeight: FontWeight.w500, color: cs.onSurface)),
        trailing: Icon(hasProject ? Icons.open_in_new : Icons.chevron_right, size: 18, color: cs.onSurfaceVariant),
        onTap: hasProject
          ? () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => ProjectDetailScreen(projectId: _projectId)),
              );
            }
          : () async {
              final result = await Navigator.push<ProjectExplorerItem>(context, MaterialPageRoute(
                builder: (_) => H1Explorer<ProjectExplorerItem>(
                  config: ProjectExplorerConfig(),
                  selectionMode: true,
                ),
              ));
              if (result != null && mounted) {
                final p = await ProjectRepository().getById(result.project.id);
                if (p != null) setState(() { _projectId = p.id; _projectName = p.name; });
              }
            },
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildTaxToggle(ColorScheme cs) {
    return Container(
      decoration: cardDecoration(cs, color: cs.surfaceContainerLow, radius: 12).copyWith(
        border: Border.all(color: cs.outlineVariant)),
      child: SwitchListTile(
        title: const Text('消費税を計算する', style: TextStyle(fontSize: 14)),
        value: _includeTax, onChanged: (v) => setState(() => _includeTax = v),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      ),
    );
  }

  Widget _buildItems(ColorScheme cs) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Text('明細', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: cs.onSurface)),
        const Spacer(),
        if (widget.isEditing)
          TextButton.icon(icon: const Icon(Icons.add, size: 18), label: const Text('追加'), onPressed: _addItem),
      ]),
      const SizedBox(height: 8),
      if (_items.isEmpty)
        Container(width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 32),
          child: Text('商品が追加されていません', textAlign: TextAlign.center, style: TextStyle(color: cs.onSurfaceVariant)))
      else
        ..._items.asMap().entries.map((e) {
          final i = e.key;
          final item = e.value;
          return DocumentItemCard(
            productName: item.productName, maker: item.maker, productCode: item.productCode,
            notes: item.notes, unitPrice: item.unitPrice, quantity: item.quantity,
            discountAmount: item.discountAmount, discountRate: item.discountRate,
            subtotal: item.subtotal,
            formatMoney: widget.isEditing ? (v) => '¥${v.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}' : _formatMoney,
            formatQty: (q) => q == q.roundToDouble() ? q.toInt().toString() : q.toStringAsFixed(1),
            onTapProductName: widget.isEditing ? () => _textEdit('商品名', item.productName, (v) => _set(i, () => item.productName = v)) : null,
            onTapMaker: widget.isEditing ? () => _textEdit('メーカー', item.maker, (v) => _set(i, () => item.maker = v)) : null,
            onTapNotes: widget.isEditing && item.notes != null && item.notes!.isNotEmpty
                ? () => _textEdit('備考', item.notes!, (v) => _set(i, () => item.notes = v)) : null,
            onTapPrice: widget.isEditing ? () => _numEdit('単価', item.unitPrice, (v) => _set(i, () => item.unitPrice = v)) : null,
            onTapQuantity: widget.isEditing ? () => _qtyEdit(i, item.quantity) : null,
            onTapDiscount: widget.isEditing ? () => _discountEdit(i) : null,
            onDelete: widget.isEditing ? () => _set(i, () => _items.removeAt(i)) : null,
          );
        }),
    ]);
  }

  Widget _buildCopiedView(ColorScheme cs) {
    return Scaffold(
      appBar: AppBar(title: const Text('伝票')),
      body: GestureDetector(
        onTap: () => Navigator.pop(context, true),
        behavior: HitTestBehavior.opaque,
        child: Container(width: double.infinity, height: double.infinity, color: cs.surface,
          child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.check_circle, size: 64, color: Colors.green),
            const SizedBox(height: 16),
            Text('コピーが完了しました', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: cs.onSurface)),
            const SizedBox(height: 8),
            Text('タップして一覧に戻る', style: TextStyle(fontSize: 14, color: cs.onSurfaceVariant)),
          ])),
        ),
      ),
    );
  }

  void _set(int i, VoidCallback fn) {
    _snapshot();
    setState(fn);
  }

  _Snapshot _snapshotFromCurrent() => _Snapshot(
    type: _type, customerId: _customerId, customerName: _customerName, date: _date,
    projectId: _projectId, projectName: _projectName,
    title: _titleCtl.text, memo: _memoCtl.text,
    includeTax: _includeTax, totalDiscountAmount: _totalDiscountAmount, totalDiscountRate: _totalDiscountRate,
    priceAdjustmentType: null, priceAdjustmentUnit: null,
    items: _items.map((e) => _EditableItem(
      id: e.id, productId: e.productId, productName: e.productName, maker: e.maker, productCode: e.productCode,
      quantity: e.quantity, unitPrice: e.unitPrice, taxRate: e.taxRate,
      discountAmount: e.discountAmount, discountRate: e.discountRate, notes: e.notes,
    )).toList(),
  );

  void _apply(_Snapshot s) {
    setState(() {
      _type = s.type; _customerId = s.customerId; _customerName = s.customerName; _date = s.date;
      _projectId = s.projectId; _projectName = s.projectName;
      _titleCtl.text = s.title; _memoCtl.text = s.memo;
      _includeTax = s.includeTax; _totalDiscountAmount = s.totalDiscountAmount; _totalDiscountRate = s.totalDiscountRate;
      _priceAdjustmentType = s.priceAdjustmentType; _priceAdjustmentUnit = s.priceAdjustmentUnit;
      _items = s.items;
    });
  }

  Future<void> _textEdit(String label, String current, void Function(String) onSave) async {
    final ctl = TextEditingController(text: current);
    final r = await showDialog<String>(context: context, builder: (ctx) => AlertDialog(
      title: Text(label), content: TextField(controller: ctl, autofocus: true),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('キャンセル')),
        FilledButton(onPressed: () => Navigator.pop(ctx, ctl.text.trim()), child: const Text('OK'))],
    ));
    ctl.dispose();
    if (r != null && mounted) onSave(r);
  }

  Future<void> _numEdit(String label, int current, void Function(int) onSave) async {
    final ctl = TextEditingController(text: current.toString());
    final r = await showDialog<int>(context: context, builder: (ctx) => AlertDialog(
      title: Text(label), content: TextField(controller: ctl, keyboardType: TextInputType.number, autofocus: true),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('キャンセル')),
        FilledButton(onPressed: () => Navigator.pop(ctx, int.tryParse(ctl.text.trim()) ?? 0), child: const Text('OK'))],
    ));
    ctl.dispose();
    if (r != null && mounted) onSave(r);
  }

  Future<void> _qtyEdit(int index, double current) async {
    final ctl = TextEditingController(text: current == current.roundToDouble() ? current.toInt().toString() : current.toStringAsFixed(1));
    final r = await showDialog<double>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('数量'), content: TextField(controller: ctl,
        keyboardType: const TextInputType.numberWithOptions(decimal: true), autofocus: true),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('キャンセル')),
        FilledButton(onPressed: () => Navigator.pop(ctx, double.tryParse(ctl.text.trim()) ?? 0), child: const Text('OK'))],
    ));
    ctl.dispose();
    if (r != null && r > 0 && mounted) {
      _snapshot();
      setState(() => _items[index].quantity = r);
    }
  }

  Future<void> _selectCustomer() async {
    final db = await DatabaseHelper().database;
    final rows = await db.query('customers', orderBy: 'display_name');
    final customers = rows.map((r) => (
      id: r['id'] as String? ?? '',
      name: r['display_name'] as String? ?? '',
    )).toList();
    final result = await showModalBottomSheet<(String, String)>(
      context: context, isScrollControlled: true,
      builder: (ctx) => _buildCustomerPicker(ctx, customers),
    );
    if (result != null) {
      _snapshot();
      setState(() { _customerId = result.$1; _customerName = result.$2; });
    }
  }

  Widget _buildCustomerPicker(BuildContext ctx, List<({String id, String name})> customers) {
    var query = '';
    return StatefulBuilder(builder: (ctx, setDialogState) {
      final filtered = query.isEmpty ? customers : customers.where((c) =>
        c.name.toLowerCase().contains(query.toLowerCase())).toList();
      return DraggableScrollableSheet(
        initialChildSize: 0.7, maxChildSize: 0.9, minChildSize: 0.3,
        builder: (ctx, scroll) => Column(children: [
          Padding(padding: const EdgeInsets.all(8),
            child: TextField(
              decoration: const InputDecoration(hintText: '顧客検索', prefixIcon: Icon(Icons.search)),
              onChanged: (v) => setDialogState(() => query = v),
            )),
          Expanded(child: ListView.builder(controller: scroll, itemCount: filtered.length + 1,
            itemBuilder: (ctx, i) {
              if (i == 0) return ListTile(
                leading: const Icon(Icons.add), title: const Text('新規取引先を追加'),
                onTap: () async {
                  final r = await Navigator.push(ctx, MaterialPageRoute(builder: (_) => const CustomerEditScreen()));
                  if (r != null) Navigator.pop(ctx, r);
                },
              );
              final c = filtered[i - 1];
              return ListTile(title: Text(c.name), onTap: () => Navigator.pop(ctx, (c.id, c.name)));
            },
          )),
        ]),
      );
    });
  }

  Future<void> _addItem() async {
    final result = await showModalBottomSheet<PickedItem>(
      context: context, isScrollControlled: true, useSafeArea: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => VariantPickerSheet(customerId: _customerId),
    );
    if (result != null && mounted) {
      _snapshot();
      setState(() => _items.add(_EditableItem(
        id: const Uuid().v4(), productId: result.productId, productName: result.productName,
        unitPrice: result.unitPrice,
      )));
    }
  }

  Future<void> _discountEdit(int index) async {
    final item = _items[index];
    final amtCtl = TextEditingController(text: (item.discountAmount ?? 0).toString());
    final rateCtl = TextEditingController(text: item.discountRate != null ? '${(item.discountRate! * 100).round()}' : '');
    var mode = item.discountAmount != null ? 0 : (item.discountRate != null ? 1 : 0);
    final result = await showDialog<Map<String, dynamic>>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('値引設定'),
      content: StatefulBuilder(builder: (ctx, setDialogState) => Column(mainAxisSize: MainAxisSize.min, children: [
        SegmentedButton<int>(
          segments: const [ButtonSegment(value: 0, label: Text('金額')), ButtonSegment(value: 1, label: Text('率'))],
          selected: {mode}, onSelectionChanged: (v) => setDialogState(() => mode = v.first),
        ),
        const SizedBox(height: 8),
        TextField(controller: mode == 0 ? amtCtl : rateCtl,
          decoration: InputDecoration(labelText: mode == 0 ? '値引額（円）' : '値引率（%）'), keyboardType: TextInputType.number),
      ])),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('キャンセル')),
        TextButton(onPressed: () => Navigator.pop(ctx, {'clear': true}), child: Text('クリア', style: TextStyle(color: Theme.of(context).colorScheme.error))),
        FilledButton(onPressed: () => Navigator.pop(ctx, {'mode': mode, 'amt': int.tryParse(amtCtl.text.trim()), 'rate': double.tryParse(rateCtl.text.trim())}), child: const Text('OK')),
      ],
    ));
    amtCtl.dispose();
    rateCtl.dispose();
    if (result == null) return;
    _snapshot();
    setState(() {
      if (result.containsKey('clear')) { _items[index] = item.copyWith(discountAmount: null, discountRate: null); return; }
      final amt = result['amt'] as int?;
      final rate = result['rate'] as double?;
      if (result['mode'] == 0 && amt != null && amt > 0) {
        _items[index] = item.copyWith(discountAmount: amt, discountRate: null);
      } else if (result['mode'] == 1 && rate != null && rate > 0) {
        _items[index] = item.copyWith(discountRate: rate / 100, discountAmount: null);
      }
    });
  }

  Future<void> _showPriceAdjustmentDialog() async {
    var localType = _priceAdjustmentType;
    var localUnit = _priceAdjustmentUnit ?? 100;
    final manualCtl = TextEditingController(
      text: (_priceAdjustmentType == 'manual' ? (_priceAdjustmentUnit ?? 0).toString() : '0'),
    );

    final result = await showDialog<Map<String, dynamic>>(context: context, builder: (ctx) {
      return StatefulBuilder(builder: (ctx, setDialogState) {
        return AlertDialog(
          title: const Text('端数処理設定'),
          content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('種類', style: TextStyle(fontSize: 13)),
            const SizedBox(height: 4),
            Wrap(spacing: 6, children: [
              ChoiceChip(label: const Text('なし'), selected: localType == null,
                onSelected: (_) => setDialogState(() => localType = null)),
              ChoiceChip(label: const Text('切捨'), selected: localType == 'round_down',
                onSelected: (_) => setDialogState(() => localType = 'round_down')),
              ChoiceChip(label: const Text('切上'), selected: localType == 'round_up',
                onSelected: (_) => setDialogState(() => localType = 'round_up')),
              ChoiceChip(label: const Text('四捨五入'), selected: localType == 'round_nearest',
                onSelected: (_) => setDialogState(() => localType = 'round_nearest')),
              ChoiceChip(label: const Text('手動'), selected: localType == 'manual',
                onSelected: (_) => setDialogState(() => localType = 'manual')),
            ]),
            if (localType != null && localType != 'manual') ...[
              const SizedBox(height: 12),
              const Text('単位', style: TextStyle(fontSize: 13)),
              const SizedBox(height: 4),
              Wrap(spacing: 6, children: [1, 10, 100, 1000].map((u) => ChoiceChip(
                label: Text('${u}円'),
                selected: localUnit == u,
                onSelected: (_) => setDialogState(() => localUnit = u),
              )).toList()),
            ],
            if (localType == 'manual') ...[
              const SizedBox(height: 12),
              TextField(controller: manualCtl,
                decoration: const InputDecoration(labelText: '調整額（円）', hintText: '例: 100'),
                keyboardType: TextInputType.number),
            ],
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('キャンセル')),
            if (localType != null)
              TextButton(
                onPressed: () => Navigator.pop(ctx, {'clear': true}),
                child: Text('クリア', style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ),
            FilledButton(onPressed: () {
              int? unit;
              if (localType == 'manual') {
                unit = int.tryParse(manualCtl.text.trim()) ?? 0;
              } else if (localType != null) {
                unit = localUnit;
              }
              Navigator.pop(ctx, {'type': localType, 'unit': unit});
            }, child: const Text('OK')),
          ],
        );
      });
    });

    manualCtl.dispose();

    if (result == null) return;
    if (result.containsKey('clear')) {
      _snapshot();
      setState(() { _priceAdjustmentType = null; _priceAdjustmentUnit = null; });
      return;
    }
    _snapshot();
    setState(() {
      _priceAdjustmentType = result['type'] as String?;
      _priceAdjustmentUnit = result['unit'] as int?;
    });
  }

  Future<void> _copyDocument(BuildContext context, ColorScheme cs) async {
    final types = DocumentType.values.where((t) => t != _type).toList();
    final isDark = cs.brightness == Brightness.dark;
    final target = await showModalBottomSheet<DocumentType>(context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) {
        final rows = (types.length + 1) ~/ 2;
        final cardH = ((MediaQuery.of(ctx).size.height - 180) / rows).clamp(64.0, 100.0);
        return SafeArea(child: Padding(padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('コピーして作成', style: Theme.of(ctx).textTheme.titleMedium),
            const SizedBox(height: 12),
            SizedBox(height: rows * cardH + (rows - 1) * 8, child: GridView.count(
              crossAxisCount: 2, mainAxisSpacing: 8, crossAxisSpacing: 8,
              shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: 180 / cardH,
              children: types.map((t) {
                final color = documentTypeColor(t, cs, isDark);
                return InkWell(onTap: () => Navigator.pop(ctx, t),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(t == DocumentType.invoice ? Icons.receipt_long : t == DocumentType.estimation ? Icons.request_quote : t == DocumentType.order ? Icons.shopping_cart_checkout : t == DocumentType.delivery ? Icons.local_shipping : Icons.receipt, size: 32, color: color),
                      const SizedBox(height: 6),
                      Text(t.label, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
                    ]),
                  ),
                );
              }).toList(),
            )),
            const SizedBox(height: 12),
            SizedBox(width: double.infinity, child: OutlinedButton(onPressed: () => Navigator.pop(ctx), child: const Text('キャンセル'))),
          ])),
        );
      },
    );
    if (target == null) return;
    try {
      final doc = copyAsDocument(_buildDoc(), target);
      final docNumber = await _repo.generateDocumentNumber(target);
      await _repo.save(doc.copyWith(documentNumber: docNumber, total: doc.totalAmount));
      await _repo.addEditLog(doc.id, '変換',
        details: '${target.label}として作成（原本: ${widget.document?.documentNumber ?? ""}）\n${_items.length}明細');
      if (mounted) setState(() => _copied = true);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('作成エラー: $e')));
    }
  }

  Future<void> _issueCreditNote(BuildContext context, ColorScheme cs) async {
    final doc = widget.document!;
    final docNum = doc.documentNumber.isNotEmpty ? doc.documentNumber : '(未発番)';
    final totalStr = '￥${_formatMoney(doc.total)}';

    // 第1段階: 操作の不可逆性を警告
    final step1 = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(children: [
          Icon(Icons.warning_amber, color: Colors.red.shade700, size: 24),
          const SizedBox(width: 8),
          const Text('赤伝（取消伝票）の発行'),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('この操作は取り消せません。', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          _warnItem(cs, '元伝票の取消として赤伝を発行します'),
          _warnItem(cs, '発行後は編集・削除できません'),
          _warnItem(cs, '取消仕訳が自動生成されます'),
          _warnItem(cs, '取消PDFが顧客に送信されます'),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('キャンセル')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('次へ')),
        ],
      ),
    );
    if (step1 != true || !mounted) return;

    // 第2段階: 伝票情報の確認
    final step2 = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('取消伝票を作成'),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('元伝票: $docNum ($totalStr)'),
          Text('顧客: ${doc.customerName}'),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: cs.errorContainer.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(Icons.error_outline, size: 18, color: cs.error),
              const SizedBox(width: 8),
              Expanded(child: Text(
                'この操作を元に戻すことはできません。\n本当に取消伝票を作成しますか？',
                style: TextStyle(fontSize: 13, color: cs.error),
              )),
            ]),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('キャンセル')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: cs.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('取消伝票を作成'),
          ),
        ],
      ),
    );
    if (step2 != true || !mounted) return;

    // 赤伝作成
    try {
      final creditNote = await _repo.createCreditNote(doc);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('取消伝票を作成しました: #${creditNote.documentNumber}')),
      );
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => DocumentPage(document: creditNote, isEditing: true),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('赤伝作成エラー: $e'), backgroundColor: cs.error),
      );
    }
  }

  Widget _warnItem(ColorScheme cs, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(children: [
        Icon(Icons.check_circle_outline, size: 16, color: cs.onSurfaceVariant),
        const SizedBox(width: 8),
        Text(text, style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
      ]),
    );
  }

  Future<void> _preview() async {
    final doc = widget.document ?? _buildDoc();
    String? email;
    if (doc.customerId.isNotEmpty) {
      final c = await CustomerRepository().getById(doc.customerId);
      email = c?.email;
    }
    if (!mounted) return;
    final docCopy = doc.copyWith();
    await Navigator.push(context, MaterialPageRoute(builder: (_) => DocumentPreviewPage(
      document: doc,
      attachArReport: _attachArReport,
      allowFormalIssue: !widget.isEditing && doc.isDraft && !doc.isLocked,
      isUnlocked: !doc.isLocked,
      onFormalIssue: () async {
        final repo = DocumentRepository();
        await repo.save(docCopy.copyWith(status: 'confirmed', isLocked: true));
        await repo.addEditLog(docCopy.id, '正式発行',
          details: '${docCopy.documentType.label} #${docCopy.documentNumber} ${docCopy.customerName}\n${_items.length}明細');
        
        // 案件に紐づく納品書・請求書・領収証の場合、SalesQueueを自動生成
        if (docCopy.projectId != null && (
            docCopy.documentType == DocumentType.delivery ||
            docCopy.documentType == DocumentType.invoice ||
            docCopy.documentType == DocumentType.receipt)) {
          try {
            final salesQueueRepo = SalesQueueRepository();
            final docTypeName = docCopy.documentType.name;
            await salesQueueRepo.createEntry(
              projectId: docCopy.projectId!,
              documentId: docCopy.id,
              documentType: docTypeName,
              triggeredAt: DateTime.now(),
            );
          } catch (e) {
            debugPrint('[DocumentPage] Failed to create SalesQueue: $e');
          }
        }
        
        return true;
      },
      showShare: true, showPrint: true, customerEmail: email,
    )));
    if (widget.document != null && mounted) {
      final upd = await _repo.fetchById(widget.document!.id);
      if (upd != null && upd.isLocked) Navigator.pop(context, true);
    }
  }

  Future<void> _save() async {
    if (!_hasChanges()) {
      if (mounted) Navigator.pop(context, widget.document);
      return;
    }
    if (_customerName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('顧客を選択してください')));
      return;
    }
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('明細を追加してください')));
      return;
    }
    if (_items.any((i) => i.productName.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('商品名が未入力の明細があります')));
      return;
    }
    setState(() => _isSaving = true);
    try {
      final doc = _buildDoc();
      final saved = doc.copyWith(
        id: widget.document?.id ?? _repo.generateId(),
        documentNumber: widget.document?.documentNumber ?? await _repo.generateDocumentNumber(_type),
        total: doc.totalAmount,
      );
      await _repo.save(saved);
      await _repo.addEditLog(saved.id, '保存',
        details: '${_type.label} #${saved.documentNumber} ${_customerName}\n${_buildDiff()}');
      if (!mounted) return;
      Navigator.pop(context, saved);
    } catch (e, st) {
      ErrorReporter.sendError(message: '保存失敗: $e', screenId: '/documents/editor', stackTrace: st);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('保存エラー: $e')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  String _buildDiff() {
    final orig = _originalItems;
    final curr = _items;
    final added = curr.where((c) => !orig.any((o) => o.id == c.id)).toList();
    final removed = orig.where((o) => !curr.any((c) => c.id == o.id)).toList();
    final changed = curr.where((c) {
      final o = orig.where((o) => o.id == c.id);
      return o.isNotEmpty && (o.first.quantity != c.quantity || o.first.unitPrice != c.unitPrice || o.first.productName != c.productName || o.first.discountAmount != c.discountAmount || o.first.discountRate != c.discountRate);
    }).toList();
    final parts = <String>[];
    if (added.isNotEmpty) {
      parts.addAll(added.map((i) => '+ ${i.productName} (数量${i.quantity}, 単価¥${i.unitPrice})'));
    }
    if (removed.isNotEmpty) {
      parts.addAll(removed.map((i) => '- ${i.productName} (数量${i.quantity}, 単価¥${i.unitPrice})'));
    }
    if (changed.isNotEmpty) {
      parts.addAll(changed.map((c) {
        final o = orig.firstWhere((o) => o.id == c.id);
        final diffs = <String>[];
        if (o.productName != c.productName) diffs.add('名称: ${o.productName}→${c.productName}');
        if (o.quantity != c.quantity) diffs.add('数量: ${o.quantity}→${c.quantity}');
        if (o.unitPrice != c.unitPrice) diffs.add('単価: ¥${o.unitPrice}→¥${c.unitPrice}');
        if (o.discountAmount != c.discountAmount) {
          final oldD = o.discountAmount ?? 0;
          final newD = c.discountAmount ?? 0;
          diffs.add('値引額: ¥$oldD→¥$newD');
        }
        if (o.discountRate != c.discountRate) {
          final oldR = o.discountRate ?? 0;
          final newR = c.discountRate ?? 0;
          diffs.add('値引率: ${(oldR * 100).toInt()}%→${(newR * 100).toInt()}%');
        }
        return '~ ${c.productName} (${diffs.join(", ")})';
      }));
    }
    return parts.isEmpty ? '(変更なし)' : parts.join('\n');
  }

  String _formatMoney(int amount) =>
    '¥${amount.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}';

  Future<void> _printDocument() async {
    if (widget.document == null) return;

    try {
      await Printing.layoutPdf(
        onLayout: (format) async {
          final doc = await generateDocumentPdf(widget.document!);
          return Uint8List.fromList(await doc.save());
        },
      );

      // PDF出力履歴を記録
      try {
        final historyRepo = HistoryRepository();
        final pdfJson = widget.document!.toPdfJson();
        final pdfJsonString = jsonEncode(pdfJson);
        final contentHash = sha256.convert(utf8.encode(pdfJsonString)).toString();

        await historyRepo.recordPdfOutput(
          documentType: widget.document!.documentType.name,
          documentId: widget.document!.id,
          documentNumber: widget.document!.documentNumber,
          customerName: widget.document!.customerName,
          contentHash: contentHash,
        );
      } catch (e) {
        debugPrint('[DocumentPage] PDF出力履歴記録エラー: $e');
      }
    } catch (e, st) {
      ErrorReporter.sendError(
        message: '印刷エラー: $e',
        screenId: '/documents/editor',
        stackTrace: st,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('印刷エラー: $e')),
        );
      }
    }
  }
}

class _Snapshot {
  final DocumentType type;
  final String customerId, customerName;
  final DateTime date;
  final String? projectId, projectName;
  final String title, memo;
  final bool includeTax;
  final int? totalDiscountAmount;
  final double? totalDiscountRate;
  final int? priceAdjustmentUnit;
  final String? priceAdjustmentType;
  final List<_EditableItem> items;
  _Snapshot({required this.type, required this.customerId, required this.customerName, required this.date,
    this.projectId, this.projectName, this.title = '', this.memo = '', this.includeTax = false,
    this.totalDiscountAmount, this.totalDiscountRate, this.priceAdjustmentType, this.priceAdjustmentUnit,
    required this.items});
}

class _EditableItem {
  final String id;
  String productId, productName, maker, productCode;
  double quantity, taxRate;
  int unitPrice;
  int? discountAmount;
  double? discountRate;
  String? notes;

  _EditableItem({required this.id, this.productId = '', this.productName = '', this.maker = '', this.productCode = '',
    this.quantity = 1, this.unitPrice = 0, this.taxRate = 0.1,
    this.discountAmount, this.discountRate, this.notes});

  int get subtotal {
    final base = (quantity * unitPrice).round();
    if (discountAmount != null && discountAmount! > 0) return base - discountAmount!;
    if (discountRate != null && discountRate! > 0) return (base * (1 - discountRate!)).round();
    return base;
  }

  _EditableItem copyWith({int? discountAmount, double? discountRate}) => _EditableItem(
    id: id, productId: productId, productName: productName, maker: maker, productCode: productCode,
    quantity: quantity, unitPrice: unitPrice, taxRate: taxRate,
    discountAmount: discountAmount ?? this.discountAmount,
    discountRate: discountRate ?? this.discountRate, notes: notes,
  );
}
