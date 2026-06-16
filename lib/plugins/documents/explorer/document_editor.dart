import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/document_model.dart';
import '../models/document_edit_log.dart';
import '../services/document_repository.dart';
import '../../../services/customer_repository.dart';
import '../../../models/customer_model.dart';
import '../../../services/project_repository.dart';
import '../../../models/project_model.dart';
import '../../../services/sync_service.dart';
import '../../../widgets/h1_text_field.dart';
import '../../../services/error_reporter.dart';
import '../../customers/screens/customer_edit_screen.dart';
import '../../products/widgets/variant_picker_sheet.dart';
import '../../project/screens/project_list_screen.dart';
import '../../../widgets/document_edit_log_section.dart';
import '../../../widgets/document_summary_section.dart';
import '../../../widgets/document_item_card.dart';
import 'document_preview_page.dart';

class DocumentEditor extends StatefulWidget {
  final DocumentModel? document;

  const DocumentEditor({super.key, required this.document});

  @override
  State<DocumentEditor> createState() => _DocumentEditorState();
}

class _DocumentEditorState extends State<DocumentEditor> {
  final _repo = DocumentRepository();
  final _customerRepo = CustomerRepository();
  final _projectRepo = ProjectRepository();
  final _uuid = const Uuid();
  static const _maxUndo = 30;

  late DocumentType _selectedType;
  late String _customerId;
  late String _customerName;
  late DateTime _selectedDate;
  late List<_EditingItem> _items;
  String? _projectId;
  String? _projectName;
  bool _isSaving = false;
  bool _includeTax = false;
  int? _totalDiscountAmount;
  double? _totalDiscountRate;
  String? _priceAdjustmentType;
  int? _priceAdjustmentUnit;

  final _subjectCtl = TextEditingController();
  final _titleCtl = TextEditingController();

  final _undoStack = <_EditorSnapshot>[];
  final _redoStack = <_EditorSnapshot>[];
  List<DocumentEditLog> _editLogs = [];

  bool get _isNew => widget.document == null;
  bool get _isLocked => widget.document?.isLocked ?? false;
  bool get _canUndo => _undoStack.isNotEmpty && !_isLocked;
  bool get _canRedo => _redoStack.isNotEmpty && !_isLocked;

  @override
  void initState() {
    super.initState();
    final doc = widget.document;
    _selectedType = doc?.documentType ?? DocumentType.invoice;
    _customerId = doc?.customerId ?? '';
    _customerName = doc?.customerName ?? '';
    _selectedDate = doc?.date ?? DateTime.now();
    _projectId = doc?.projectId;
    _subjectCtl.text = doc?.subject ?? '';
    final subjLines = (doc?.subject ?? '').split('\n');
    _titleCtl.text = subjLines.first;
    if (subjLines.length > 1) _subjectCtl.text = subjLines.sublist(1).join('\n');
    _includeTax = doc?.includeTax ?? false;
    _totalDiscountAmount = doc?.totalDiscountAmount;
    _totalDiscountRate = doc?.totalDiscountRate;
    _priceAdjustmentType = doc?.priceAdjustmentType;
    _priceAdjustmentUnit = doc?.priceAdjustmentUnit;
    if (doc != null) {
      _repo.getEditLogs(doc.id).then((logs) {
        if (mounted) setState(() => _editLogs = logs);
      });
    }
    _items = (doc?.items ?? []).map((item) => _EditingItem(
      id: item.id,
      productId: item.productId,
      productName: item.productName,
      maker: item.maker,
      productCode: item.productCode,
      quantity: item.quantity,
      unitPrice: item.unitPrice,
      taxRate: item.taxRate,
      discountAmount: item.discountAmount,
      discountRate: item.discountRate,
      notes: item.notes,
    )).toList();
    if (_projectId != null) _loadProjectName();
  }

  Future<void> _loadProjectName() async {
    if (_projectId == null) return;
    final project = await _projectRepo.getById(_projectId!);
    if (project != null && mounted) {
      setState(() => _projectName = project.name);
    }
  }

  @override
  void dispose() {
    _titleCtl.dispose();
    _subjectCtl.dispose();
    super.dispose();
  }

  void _takeSnapshot() {
    _undoStack.add(_EditorSnapshot(
      selectedType: _selectedType,
      customerId: _customerId,
      customerName: _customerName,
      selectedDate: _selectedDate,
      projectId: _projectId,
      projectName: _projectName,
      title: _titleCtl.text,
      subject: _subjectCtl.text,
      includeTax: _includeTax,
      totalDiscountAmount: _totalDiscountAmount,
      totalDiscountRate: _totalDiscountRate,
      priceAdjustmentType: _priceAdjustmentType,
      priceAdjustmentUnit: _priceAdjustmentUnit,
      items: _items.map((e) => _EditingItem(
        id: e.id, productId: e.productId, productName: e.productName,
        maker: e.maker, productCode: e.productCode,
        quantity: e.quantity, unitPrice: e.unitPrice, taxRate: e.taxRate,
        discountAmount: e.discountAmount, discountRate: e.discountRate,
        notes: e.notes,
      )).toList(),
    ));
    if (_undoStack.length > _maxUndo) _undoStack.removeAt(0);
    _redoStack.clear();
  }

  void _undo() {
    if (!_canUndo) return;
    _redoStack.add(_EditorSnapshot(
      selectedType: _selectedType,
      customerId: _customerId,
      customerName: _customerName,
      selectedDate: _selectedDate,
      projectId: _projectId,
      projectName: _projectName,
      title: _titleCtl.text,
      subject: _subjectCtl.text,
      includeTax: _includeTax,
      totalDiscountAmount: _totalDiscountAmount,
      totalDiscountRate: _totalDiscountRate,
      priceAdjustmentType: _priceAdjustmentType,
      priceAdjustmentUnit: _priceAdjustmentUnit,
      items: _items.map((e) => _EditingItem(
        id: e.id, productId: e.productId, productName: e.productName,
        maker: e.maker, productCode: e.productCode,
        quantity: e.quantity, unitPrice: e.unitPrice, taxRate: e.taxRate,
        discountAmount: e.discountAmount, discountRate: e.discountRate,
        notes: e.notes,
      )).toList(),
    ));
    final s = _undoStack.removeLast();
    setState(() {
      _selectedType = s.selectedType;
      _customerId = s.customerId;
      _customerName = s.customerName;
      _selectedDate = s.selectedDate;
      _projectId = s.projectId;
      _projectName = s.projectName;
      _titleCtl.text = s.title;
      _subjectCtl.text = s.subject;
      _includeTax = s.includeTax;
      _totalDiscountAmount = s.totalDiscountAmount;
      _totalDiscountRate = s.totalDiscountRate;
      _priceAdjustmentType = s.priceAdjustmentType;
      _priceAdjustmentUnit = s.priceAdjustmentUnit;
      _items = s.items;
    });
  }

  void _redo() {
    if (!_canRedo) return;
    _takeSnapshot();
    final s = _redoStack.removeLast();
    setState(() {
      _selectedType = s.selectedType;
      _customerId = s.customerId;
      _customerName = s.customerName;
      _selectedDate = s.selectedDate;
      _projectId = s.projectId;
      _projectName = s.projectName;
      _titleCtl.text = s.title;
      _subjectCtl.text = s.subject;
      _includeTax = s.includeTax;
      _totalDiscountAmount = s.totalDiscountAmount;
      _totalDiscountRate = s.totalDiscountRate;
      _priceAdjustmentType = s.priceAdjustmentType;
      _priceAdjustmentUnit = s.priceAdjustmentUnit;
      _items = s.items;
    });
  }

  DocumentModel _buildPreviewDoc() {
    final docItems = _items.map((e) => DocumentItem(
      id: e.id,
      productId: e.productId,
      productName: e.productName,
      maker: e.maker,
      productCode: e.productCode,
      quantity: e.quantity,
      unitPrice: e.unitPrice,
      taxRate: e.taxRate,
      discountAmount: e.discountAmount,
      discountRate: e.discountRate,
      notes: e.notes,
    )).toList();
    final title = _titleCtl.text.trim();
    final memo = _subjectCtl.text.trim();
    final merged = title.isNotEmpty && memo.isNotEmpty
        ? '$title\n$memo'
        : title.isNotEmpty
            ? title
            : memo;
    final tmp = DocumentModel(
      id: widget.document?.id ?? _repo.generateId(),
      documentType: _selectedType,
      customerId: _customerId,
      customerName: _customerName,
      documentNumber: widget.document?.documentNumber ?? '（仮番号）',
      date: _selectedDate,
      total: 0,
      status: 'draft',
      projectId: _projectId,
      subject: merged.isNotEmpty ? merged : null,
      includeTax: _includeTax,
      taxRate: 0.10,
      totalDiscountAmount: _totalDiscountAmount,
      totalDiscountRate: _totalDiscountRate,
      priceAdjustmentType: _priceAdjustmentType,
      priceAdjustmentUnit: _priceAdjustmentUnit,
      items: docItems,
    );
    return tmp.copyWith(total: tmp.totalAmount);
  }

  Future<void> _save() async {
    if (_customerName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('顧客を選択してください')),
      );
      return;
    }
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('明細を追加してください')),
      );
      return;
    }
    final emptyFields = _items.where((i) => i.productName.isEmpty).toList();
    if (emptyFields.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('商品名は必須です')),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final docId = widget.document?.id ?? _repo.generateId();
      final docNumber = widget.document?.documentNumber ??
          await _repo.generateDocumentNumber(_selectedType);

      final doc = _buildPreviewDoc().copyWith(
        id: docId,
        documentNumber: docNumber,
      );

      await _repo.save(doc);
      final typeLabel = doc.documentType.label;
      final itemCount = doc.items.length;
      final totalStr = '¥${doc.total.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}';
      final diffParts = <String>[];
      if (widget.document != null) {
        final oldNames = widget.document!.items.map((i) => i.productName).toSet();
        final newNames = doc.items.map((i) => i.productName).toSet();
        final added = newNames.difference(oldNames);
        final removed = oldNames.difference(newNames);
        if (added.isNotEmpty) diffParts.add('追加:${added.join(",")}');
        if (removed.isNotEmpty) diffParts.add('削除:${removed.join(",")}');
      }
      final diffStr = diffParts.isNotEmpty ? ' / ${diffParts.join(" / ")}' : '';
      await _repo.addEditLog(doc.id, '保存',
        details: '$typeLabel #${doc.documentNumber} ${doc.customerName} $totalStr ${itemCount}明細$diffStr');
      if (!mounted) return;
      SyncService.pushChange(
        entityType: 'document',
        entityId: doc.id,
        action: 'save',
        data: doc.toMap(),
      );
      if (!mounted) return;
      setState(() => _isSaving = false);
      Navigator.pop(context, true);
    } catch (e, st) {
      setState(() => _isSaving = false);
      ErrorReporter.sendError(
        message: '書類保存失敗: $e',
        screenId: '/documents/editor',
        stackTrace: st,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('保存エラー: $e')),
      );
    }
  }

  Future<void> _preview() async {
    String? customerEmail;
    if (_customerId.isNotEmpty) {
      final customer = await CustomerRepository().getById(_customerId);
      customerEmail = customer?.email;
    }
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DocumentPreviewPage(
          document: _buildPreviewDoc(),
          allowFormalIssue: false,
          showShare: true,
          showPrint: true,
          customerEmail: customerEmail,
        ),
      ),
    );
  }

  void _wrapWithSnapshot(VoidCallback fn) {
    _takeSnapshot();
    fn();
    setState(() {});
  }

  Future<void> _selectCustomer() async {
    final customers = await _customerRepo.searchCustomers('');
    if (!mounted) return;
    final result = await showModalBottomSheet<Customer>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => _CustomerPickerSheet(
        customers: customers,
        repo: _customerRepo,
      ),
    );
    if (result != null && mounted) {
      _wrapWithSnapshot(() {
        _customerId = result.id;
        _customerName = result.displayName.isNotEmpty ? result.displayName : result.formalName;
      });
    }
  }

  Future<void> _selectProject() async {
    final result = await Navigator.push<Project>(
      context,
      MaterialPageRoute(builder: (_) => const ProjectListScreen(selectionMode: true)),
    );
    if (result != null && mounted) {
      _wrapWithSnapshot(() {
        _projectId = result.id;
        _projectName = result.name;
      });
    }
  }

  Future<void> _addItem() async {
    final result = await showModalBottomSheet<PickedItem>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => VariantPickerSheet(customerId: _customerId),
    );
    if (result != null && mounted) {
      _wrapWithSnapshot(() => _items.add(_EditingItem(
        id: _uuid.v4(),
        productId: '',
        productName: result.productName,
        quantity: 1,
        unitPrice: result.unitPrice,
      )));
    }
  }

  void _removeItem(int index) {
    _wrapWithSnapshot(() => _items.removeAt(index));
  }

  int get _subtotal => _items.fold(0, (sum, item) => sum + item.subtotal);

  int get _discountAmount {
    int itemDiscount = _items.fold(0, (sum, item) {
      if (item.discountAmount != null && item.discountAmount! > 0) return sum + item.discountAmount!;
      if (item.discountRate != null && item.discountRate! > 0) {
        final base = (item.quantity * item.unitPrice).round();
        return sum + (base * item.discountRate!).round();
      }
      return sum;
    });
    if (_totalDiscountAmount != null && _totalDiscountAmount! > 0) return _totalDiscountAmount!;
    if (_totalDiscountRate != null && _totalDiscountRate! > 0) return (_subtotal * _totalDiscountRate!).round();
    return itemDiscount;
  }

  int get _priceAdjustmentDiscount {
    if (_priceAdjustmentType == null || _priceAdjustmentUnit == null) return 0;
    if (_priceAdjustmentType == 'manual') return _priceAdjustmentUnit!;
    final unit = _priceAdjustmentUnit!;
    final base = _subtotal - _discountAmount;
    int adj;
    switch (_priceAdjustmentType) {
      case 'round_down':
        adj = (base ~/ unit) * unit;
      case 'round_up':
        adj = ((base + unit - 1) ~/ unit) * unit;
      case 'round_nearest':
        adj = ((base + unit ~/ 2) ~/ unit) * unit;
      default:
        return 0;
    }
    return base - adj;
  }

  int get _totalDiscount => _discountAmount + _priceAdjustmentDiscount;

  int get _taxableAmount => _subtotal - _totalDiscount;

  int get _tax => _includeTax ? (_taxableAmount * 0.10).floor() : 0;

  int get _grandTotal => _taxableAmount + _tax;

  Future<void> _editMaker(int index) async {
    final item = _items[index];
    final ctl = TextEditingController(text: item.maker);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('メーカー'),
        content: H1TextField(
          controller: ctl,
          decoration: const InputDecoration(labelText: 'メーカー'),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('キャンセル')),
          FilledButton(onPressed: () => Navigator.pop(ctx, ctl.text.trim()), child: const Text('OK')),
        ],
      ),
    );
    ctl.dispose();
    if (result != null && mounted) {
      _wrapWithSnapshot(() => _items[index].maker = result);
    }
  }

  Future<void> _editCode(int index) async {
    final item = _items[index];
    final ctl = TextEditingController(text: item.productCode);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('品番'),
        content: H1TextField(
          controller: ctl,
          decoration: const InputDecoration(labelText: '品番'),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('キャンセル')),
          FilledButton(onPressed: () => Navigator.pop(ctx, ctl.text.trim()), child: const Text('OK')),
        ],
      ),
    );
    ctl.dispose();
    if (result != null && mounted) {
      _wrapWithSnapshot(() => _items[index].productCode = result);
    }
  }

  Future<void> _editProductName(int index) async {
    final item = _items[index];
    final ctl = TextEditingController(text: item.productName);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('商品名'),
        content: H1TextField(
          controller: ctl,
          decoration: const InputDecoration(labelText: '商品名'),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('キャンセル')),
          FilledButton(onPressed: () => Navigator.pop(ctx, ctl.text.trim()), child: const Text('OK')),
        ],
      ),
    );
    ctl.dispose();
    if (result != null && mounted) {
      _wrapWithSnapshot(() => _items[index].productName = result);
    }
  }

  Future<void> _editNotes(int index) async {
    final item = _items[index];
    final ctl = TextEditingController(text: item.notes ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('備考'),
        content: H1TextField(
          controller: ctl,
          decoration: const InputDecoration(labelText: '備考'),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('キャンセル')),
          FilledButton(onPressed: () => Navigator.pop(ctx, ctl.text.trim()), child: const Text('OK')),
        ],
      ),
    );
    ctl.dispose();
    if (result != null && mounted) {
      _wrapWithSnapshot(() => _items[index].notes = result.isNotEmpty ? result : null);
    }
  }

  Future<void> _editPrice(int index) async {
    final item = _items[index];
    final ctl = TextEditingController(text: item.unitPrice.toString());
    final result = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('単価を変更'),
        content: H1TextField(
          controller: ctl,
          decoration: const InputDecoration(labelText: '単価'),
          keyboardType: TextInputType.number,
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('キャンセル')),
          FilledButton(onPressed: () {
            final v = int.tryParse(ctl.text);
            if (v != null && v > 0) Navigator.pop(ctx, v);
          }, child: const Text('OK')),
        ],
      ),
    );
    ctl.dispose();
    if (result != null && mounted) {
      _wrapWithSnapshot(() => _items[index].unitPrice = result);
    }
  }

  Future<void> _editItemDiscount(int index) async {
    final item = _items[index];
    final amtCtl = TextEditingController(text: item.discountAmount?.toString() ?? '');
    final rateCtl = TextEditingController(text: item.discountRate != null ? '${(item.discountRate! * 100).round()}' : '');
    var mode = item.discountAmount != null ? 0 : (item.discountRate != null ? 1 : 0);
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          title: const Text('値引設定'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SegmentedButton<int>(
                segments: const [
                  ButtonSegment(value: 0, label: Text('金額')),
                  ButtonSegment(value: 1, label: Text('率(%)')),
                ],
                selected: {mode},
                onSelectionChanged: (s) => setDlgState(() => mode = s.first),
              ),
              const SizedBox(height: 12),
              H1TextField(
                controller: mode == 0 ? amtCtl : rateCtl,
                decoration: InputDecoration(
                  labelText: mode == 0 ? '値引額 (円)' : '値引率 (%)',
                ),
                keyboardType: TextInputType.number,
                autofocus: true,
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('キャンセル')),
            TextButton(onPressed: () {
              _wrapWithSnapshot(() {
                _items[index].discountAmount = null;
                _items[index].discountRate = null;
              });
              Navigator.pop(ctx);
            }, child: Text('クリア', style: TextStyle(color: Theme.of(context).colorScheme.error))),
            FilledButton(onPressed: () {
              if (mode == 0) {
                final v = int.tryParse(amtCtl.text);
                if (v != null && v > 0) {
                  _wrapWithSnapshot(() {
                    _items[index].discountAmount = v;
                    _items[index].discountRate = null;
                  });
                  Navigator.pop(ctx);
                }
              } else {
                final v = double.tryParse(rateCtl.text);
                if (v != null && v > 0 && v <= 100) {
                  _wrapWithSnapshot(() {
                    _items[index].discountRate = v / 100;
                    _items[index].discountAmount = null;
                  });
                  Navigator.pop(ctx);
                }
              }
            }, child: const Text('設定')),
          ],
        ),
      ),
    );
    amtCtl.dispose();
    rateCtl.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(_isNew ? 'DE:新規書類' : (_isLocked ? 'DE:書類参照' : 'DE:書類編集')),
        actions: [
          if (!_isLocked) ...[
            IconButton(
              icon: Icon(Icons.undo, color: _canUndo ? cs.onPrimary : cs.onPrimary.withValues(alpha: 0.3)),
              tooltip: '元に戻す',
              onPressed: _canUndo ? _undo : null,
            ),
            IconButton(
              icon: Icon(Icons.redo, color: _canRedo ? cs.onPrimary : cs.onPrimary.withValues(alpha: 0.3)),
              tooltip: 'やり直す',
              onPressed: _canRedo ? _redo : null,
            ),
          ],
          IconButton(
            icon: Icon(Icons.picture_as_pdf, color: cs.onPrimary),
            tooltip: 'PDFプレビュー',
            onPressed: _preview,
          ),
          if (_isLocked)
            IconButton(
              icon: Icon(Icons.close, color: cs.onPrimary),
              tooltip: '閉じる',
              onPressed: () => Navigator.pop(context),
            )
          else
            IconButton(
            icon: _isSaving
              ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: cs.onPrimary))
              : Icon(Icons.save, color: cs.onPrimary),
            tooltip: '保存',
            onPressed: _isSaving ? null : _save,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          if (_isNew) _buildTypeSelector(cs),
          const SizedBox(height: 16),
          _buildHeaderCard(cs),
          const SizedBox(height: 12),
          _buildSubjectField(cs),
          const SizedBox(height: 12),
          _buildCustomerCard(cs),
          const SizedBox(height: 12),
          _buildProjectCard(cs),
          const SizedBox(height: 12),
          _buildTaxToggle(cs),
          const SizedBox(height: 12),
          _buildAdjustmentsButton(cs),
          const SizedBox(height: 20),
          _buildItemsSection(cs),
          const SizedBox(height: 20),
          _buildSummarySection(cs),
        ],
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildEditLogSection(cs),
          _buildBottomBar(),
        ],
      ),
    );
  }

  Widget _buildTypeSelector(ColorScheme cs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('伝票種別', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: cs.onSurfaceVariant)),
        const SizedBox(height: 8),
        DropdownButtonFormField<DocumentType>(
          value: _selectedType,
          items: DocumentType.values.map((t) => DropdownMenuItem(
            value: t,
            child: Text(t.label),
          )).toList(),
          onChanged: (v) {
            if (v != null) _wrapWithSnapshot(() => _selectedType = v);
          },
        ),
      ],
    );
  }

  Widget _buildHeaderCard(ColorScheme cs) {
    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: cs.shadow.withValues(alpha: 0.08), blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () async {
          final picked = await showDatePicker(
            context: context,
            initialDate: _selectedDate,
            firstDate: DateTime(2000),
            lastDate: DateTime(2100),
          );
          if (picked != null && mounted) {
            _wrapWithSnapshot(() => _selectedDate = picked);
          }
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(Icons.calendar_today, size: 20, color: cs.primary),
              const SizedBox(width: 12),
              Text('伝票日付:', style: TextStyle(fontSize: 14, color: cs.onSurfaceVariant)),
              const SizedBox(width: 8),
              Text(
                '${_selectedDate.year}/${_selectedDate.month.toString().padLeft(2, '0')}/${_selectedDate.day.toString().padLeft(2, '0')}',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: cs.onSurface),
              ),
              const Spacer(),
              Icon(Icons.chevron_right, size: 20, color: cs.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSubjectField(ColorScheme cs) {
    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            color: cs.surfaceContainerLow,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.3)),
          ),
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
          child: TextField(
            controller: _titleCtl,
            maxLines: 1,
            decoration: const InputDecoration(
              border: InputBorder.none, isDense: true,
              labelText: '件名',
              hintText: 'タイトル',
            ),
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: cs.onSurface),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: cs.surfaceContainerLow,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.3)),
          ),
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
          child: TextField(
            controller: _subjectCtl,
            maxLines: null,
            minLines: 2,
            decoration: const InputDecoration(
              border: InputBorder.none, isDense: true,
              labelText: 'メモ',
              hintText: '自由記述',
            ),
            style: TextStyle(fontSize: 14, color: cs.onSurface),
          ),
        ),
      ],
    );
  }

  Widget _buildCustomerCard(ColorScheme cs) {
    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant),
        boxShadow: [BoxShadow(color: cs.shadow.withValues(alpha: 0.08), blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: ListTile(
        leading: Icon(Icons.business, color: cs.primary),
        title: Text(
          _customerName.isNotEmpty ? '$_customerName 様' : '取引先を選択してください',
          style: TextStyle(fontWeight: FontWeight.w500, color: _customerName.isNotEmpty ? cs.onSurface : cs.onSurfaceVariant),
        ),
        subtitle: _customerName.isEmpty ? null : Text('タップして変更', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
        trailing: Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
        onTap: _selectCustomer,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildProjectCard(ColorScheme cs) {
    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant),
        boxShadow: [BoxShadow(color: cs.shadow.withValues(alpha: 0.08), blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: ListTile(
        leading: Icon(Icons.workspaces, color: cs.secondary),
        title: Text(
          _projectName ?? '案件に紐付け',
          style: TextStyle(fontWeight: FontWeight.w500, color: _projectName != null ? cs.onSurface : cs.onSurfaceVariant),
        ),
        subtitle: _projectName == null ? null : Text('タップして変更', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_projectId != null)
              IconButton(
                icon: Icon(Icons.close, size: 18, color: cs.onSurfaceVariant),
                onPressed: () => _wrapWithSnapshot(() {
                  _projectId = null;
                  _projectName = null;
                }),
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
          ],
        ),
        onTap: _selectProject,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildAdjustmentsButton(ColorScheme cs) {
    final hasAdjustment = _totalDiscountAmount != null || _totalDiscountRate != null ||
        _priceAdjustmentType != null || _priceAdjustmentUnit != null;
    return OutlinedButton.icon(
      icon: Icon(Icons.tune, size: 18),
      label: Text(hasAdjustment ? '調整: 設定済み' : '値引・端数調整'),
      onPressed: () => _showAdjustmentDialog(),
      style: OutlinedButton.styleFrom(
        foregroundColor: hasAdjustment ? cs.primary : cs.onSurfaceVariant,
        side: BorderSide(color: hasAdjustment ? cs.primary : cs.outlineVariant),
      ),
    );
  }

  Future<void> _showAdjustmentDialog() async {
    final amtCtl = TextEditingController(text: _totalDiscountAmount?.toString() ?? '');
    final rateCtl = TextEditingController(
      text: _totalDiscountRate != null ? '${(_totalDiscountRate! * 100).round()}' : '',
    );
    var discMode = _totalDiscountAmount != null ? 0 : (_totalDiscountRate != null ? 1 : 0);
    var adjType = _priceAdjustmentType ?? '';
    var adjUnit = _priceAdjustmentUnit ?? 0;
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          title: const Text('値引・端数調整'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('合計値引き', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                const SizedBox(height: 8),
                SegmentedButton<int>(
                  segments: const [
                    ButtonSegment(value: 0, label: Text('金額')),
                    ButtonSegment(value: 1, label: Text('率(%)')),
                  ],
                  selected: {discMode},
                  onSelectionChanged: (s) => setDlgState(() => discMode = s.first),
                ),
                const SizedBox(height: 8),
                H1TextField(
                  controller: discMode == 0 ? amtCtl : rateCtl,
                  decoration: InputDecoration(
                    labelText: discMode == 0 ? '値引額 (円)' : '値引率 (%)',
                    hintText: '0',
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 20),
                Text('端数処理', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: adjType.isEmpty ? null : adjType,
                  hint: const Text('適用しない'),
                  items: const [
                    DropdownMenuItem(value: 'round_down', child: Text('切り捨て')),
                    DropdownMenuItem(value: 'round_up', child: Text('切り上げ')),
                    DropdownMenuItem(value: 'round_nearest', child: Text('四捨五入')),
                    DropdownMenuItem(value: 'manual', child: Text('手動調整')),
                  ],
                  onChanged: (v) => setDlgState(() => adjType = v ?? ''),
                  decoration: const InputDecoration(labelText: '方式'),
                ),
                if (adjType.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  DropdownButtonFormField<int>(
                    value: adjUnit > 0 ? adjUnit : null,
                    hint: const Text('単位'),
                    items: [1, 10, 100, 1000].map((u) => DropdownMenuItem(
                      value: u,
                      child: Text('¥$u'),
                    )).toList(),
                    onChanged: (v) => setDlgState(() => adjUnit = v ?? 0),
                    decoration: const InputDecoration(labelText: '単位'),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('キャンセル')),
            TextButton(onPressed: () {
              _wrapWithSnapshot(() {
                _totalDiscountAmount = null;
                _totalDiscountRate = null;
                _priceAdjustmentType = null;
                _priceAdjustmentUnit = null;
              });
              Navigator.pop(ctx);
            }, child: Text('クリア', style: TextStyle(color: Theme.of(context).colorScheme.error))),
            FilledButton(onPressed: () {
              _wrapWithSnapshot(() {
                if (discMode == 0) {
                  final v = int.tryParse(amtCtl.text);
                  _totalDiscountAmount = (v != null && v > 0) ? v : null;
                  _totalDiscountRate = null;
                } else {
                  final v = double.tryParse(rateCtl.text);
                  _totalDiscountRate = (v != null && v > 0 && v <= 100) ? v / 100 : null;
                  _totalDiscountAmount = null;
                }
                _priceAdjustmentType = adjType.isNotEmpty ? adjType : null;
                _priceAdjustmentUnit = adjUnit > 0 ? adjUnit : null;
              });
              Navigator.pop(ctx);
            }, child: const Text('適用')),
          ],
        ),
      ),
    );
    amtCtl.dispose();
    rateCtl.dispose();
  }

  Widget _buildTaxToggle(ColorScheme cs) {
    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: SwitchListTile(
        title: Text('消費税を計算', style: TextStyle(fontWeight: FontWeight.w500, color: cs.onSurface)),
        subtitle: Text(_includeTax ? '税抜金額に10%を加算' : '消費税なし', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
        value: _includeTax,
        onChanged: (v) => _wrapWithSnapshot(() => _includeTax = v),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildItemsSection(ColorScheme cs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('明細項目', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: cs.onSurface)),
            const Spacer(),
            TextButton.icon(
              icon: const Icon(Icons.add, size: 18),
              label: const Text('追加'),
              onPressed: _addItem,
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_items.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 32),
            child: Text('商品が追加されていません', textAlign: TextAlign.center,
              style: TextStyle(color: cs.onSurfaceVariant)),
          )
        else
          ..._items.asMap().entries.map((entry) => _buildItemCard(entry.key, entry.value, cs)),
      ],
    );
  }

  Widget _buildItemCard(int index, _EditingItem item, ColorScheme cs) {
    return DocumentItemCard(
      productName: item.productName,
      maker: item.maker,
      productCode: item.productCode,
      notes: item.notes,
      unitPrice: item.unitPrice,
      quantity: item.quantity,
      discountAmount: item.discountAmount,
      discountRate: item.discountRate,
      subtotal: item.subtotal,
      formatMoney: (v) => '¥${_formatMoney(v)}',
      formatQty: _formatQty,
      onTapProductName: () => _editProductName(index),
      onTapMaker: () => _editMaker(index),
      onTapNotes: item.notes != null && item.notes!.isNotEmpty ? () => _editNotes(index) : null,
      onTapPrice: () => _editPrice(index),
      onTapDiscount: () => _editItemDiscount(index),
      onDelete: () => _removeItem(index),
    );
  }

  Widget _buildSummarySection(ColorScheme cs) {
    return DocumentSummarySection(
      subtotal: _subtotal,
      discountAmount: _totalDiscount,
      taxableAmount: _taxableAmount,
      tax: _tax,
      total: _grandTotal,
      taxRate: 0.10,
      formatMoney: (v) => '¥${_formatMoney(v)}',
      totalLabelIsTaxIncluded: true,
      showTaxExcludedIfDifferent: true,
    );
  }

  Widget _buildEditLogSection(ColorScheme cs) {
    return DocumentEditLogSection(editLogs: _editLogs, colorScheme: cs);
  }

  Widget _buildBottomBar() {
    if (_isLocked) return const SizedBox.shrink();
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            _isSaving
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : IconButton(
                    icon: const Icon(Icons.save),
                    tooltip: '下書き保存',
                    onPressed: _save,
                  ),
          ],
        ),
      ),
    );
  }

  String _formatMoney(int amount) =>
    amount.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');

  String _formatQty(double qty) =>
    qty == qty.roundToDouble() ? qty.toInt().toString() : qty.toStringAsFixed(1);
}

class _EditorSnapshot {
  final DocumentType selectedType;
  final String customerId;
  final String customerName;
  final DateTime selectedDate;
  final String? projectId;
  final String? projectName;
  final String title;
  final String subject;
  final bool includeTax;
  final int? totalDiscountAmount;
  final double? totalDiscountRate;
  final String? priceAdjustmentType;
  final int? priceAdjustmentUnit;
  final List<_EditingItem> items;

  _EditorSnapshot({
    required this.selectedType,
    required this.customerId,
    required this.customerName,
    required this.selectedDate,
    this.projectId,
    this.projectName,
    this.title = '',
    this.subject = '',
    this.includeTax = false,
    this.totalDiscountAmount,
    this.totalDiscountRate,
    this.priceAdjustmentType,
    this.priceAdjustmentUnit,
    required this.items,
  });
}

class _EditingItem {
  final String id;
  String productId;
  String productName;
  String maker;
  String productCode;
  double quantity;
  int unitPrice;
  double taxRate;
  int? discountAmount;
  double? discountRate;
  String? notes;

  _EditingItem({
    required this.id,
    this.productId = '',
    this.productName = '',
    this.maker = '',
    this.productCode = '',
    this.quantity = 1,
    this.unitPrice = 0,
    this.taxRate = 0.1,
    this.discountAmount,
    this.discountRate,
    this.notes,
  });

  int get subtotal {
    final base = (quantity * unitPrice).round();
    if (discountAmount != null && discountAmount! > 0) return base - discountAmount!;
    if (discountRate != null && discountRate! > 0) return (base * (1 - discountRate!)).round();
    return base;
  }
}

class _CustomerPickerSheet extends StatefulWidget {
  final List<Customer> customers;
  final CustomerRepository repo;
  const _CustomerPickerSheet({required this.customers, required this.repo});

  @override
  State<_CustomerPickerSheet> createState() => _CustomerPickerSheetState();
}

class _CustomerPickerSheetState extends State<_CustomerPickerSheet> {
  late List<Customer> _filtered;
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _filtered = widget.customers;
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _search(String q) {
    final query = q.trim().toLowerCase();
    setState(() {
      _filtered = query.isEmpty
          ? widget.customers
          : widget.customers.where((c) =>
              c.displayName.toLowerCase().contains(query) ||
              c.formalName.toLowerCase().contains(query)).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (ctx, scrollCtrl) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                Expanded(child: Text('取引先を選択', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: cs.onSurface))),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: H1TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: '顧客名で検索',
                prefixIcon: const Icon(Icons.search),
              ),
              onChanged: _search,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.person_add, size: 18),
                label: const Text('取引先を追加'),
                onPressed: () async {
                  final result = await Navigator.push<Customer>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const CustomerEditScreen(),
                    ),
                  );
                  if (result != null && mounted) {
                    Navigator.pop(context, result);
                  }
                },
              ),
            ),
          ),
          const SizedBox(height: 4),
          if (_filtered.isEmpty)
            Expanded(child: Center(child: Text('見つかりませんでした', style: TextStyle(color: cs.onSurfaceVariant))))
          else
            Expanded(
              child: ListView.builder(
                controller: scrollCtrl,
                itemCount: _filtered.length,
                itemBuilder: (ctx, i) {
                  final c = _filtered[i];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: cs.primaryContainer,
                      child: Text(c.displayName.isNotEmpty ? c.displayName[0].toUpperCase() : '?',
                          style: TextStyle(color: cs.onPrimaryContainer, fontWeight: FontWeight.bold)),
                    ),
                    title: Text(c.displayName.isNotEmpty ? c.displayName : c.formalName,
                        style: TextStyle(fontWeight: FontWeight.w500, color: cs.onSurface)),
                    subtitle: c.formalName.isNotEmpty ? Text(c.formalName, style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)) : null,
                    trailing: Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
                    onTap: () => Navigator.pop(ctx, c),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}


