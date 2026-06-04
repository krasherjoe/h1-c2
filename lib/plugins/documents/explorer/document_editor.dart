import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/document_model.dart';
import '../services/document_repository.dart';
import '../../../services/customer_repository.dart';
import '../../../models/customer_model.dart';
import '../../../models/product_model.dart';
import '../../../services/product_repository.dart';
import '../../../services/project_repository.dart';
import '../../../models/project_model.dart';
import '../../../services/sync_service.dart';
import '../../../services/database_helper.dart';
import '../../../widgets/h1_text_field.dart';
import '../../../services/error_reporter.dart';
import '../../customers/screens/customer_edit_screen.dart';
import '../../products/screens/product_editor_screen.dart';
import '../../project/screens/project_list_screen.dart';

class DocumentEditor extends StatefulWidget {
  final DocumentModel? document;

  const DocumentEditor({super.key, required this.document});

  @override
  State<DocumentEditor> createState() => _DocumentEditorState();
}

class _DocumentEditorState extends State<DocumentEditor> {
  final _repo = DocumentRepository();
  final _customerRepo = CustomerRepository();
  final _productRepo = ProductRepository();
  final _projectRepo = ProjectRepository();
  static const _maxUndo = 30;

  late DocumentType _selectedType;
  late String _customerId;
  late String _customerName;
  late DateTime _selectedDate;
  late List<_EditingItem> _items;
  String? _projectId;
  String? _projectName;
  bool _isSaving = false;

  final _subjectCtl = TextEditingController();

  final _undoStack = <_EditorSnapshot>[];
  final _redoStack = <_EditorSnapshot>[];

  bool get _isNew => widget.document == null;
  bool get _canUndo => _undoStack.isNotEmpty;
  bool get _canRedo => _redoStack.isNotEmpty;

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
    _items = (doc?.items ?? []).map((item) => _EditingItem(
      id: item.id,
      productId: item.productId,
      productName: item.productName,
      quantity: item.quantity,
      unitPrice: item.unitPrice,
      taxRate: item.taxRate,
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
      subject: _subjectCtl.text,
      items: _items.map((e) => _EditingItem(
        id: e.id, productId: e.productId, productName: e.productName,
        quantity: e.quantity, unitPrice: e.unitPrice, taxRate: e.taxRate,
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
      subject: _subjectCtl.text,
      items: _items.map((e) => _EditingItem(
        id: e.id, productId: e.productId, productName: e.productName,
        quantity: e.quantity, unitPrice: e.unitPrice, taxRate: e.taxRate,
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
      _subjectCtl.text = s.subject;
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
      _subjectCtl.text = s.subject;
      _items = s.items;
    });
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

    setState(() => _isSaving = true);
    try {
      final docId = widget.document?.id ?? _repo.generateId();
      final docNumber = widget.document?.documentNumber ??
          await _repo.generateDocumentNumber(_selectedType);

      final total = _items.fold(0, (sum, item) => sum + (item.quantity * item.unitPrice).round());

      final subj = _subjectCtl.text.trim();
      final doc = DocumentModel(
        id: docId,
        documentType: _selectedType,
        customerId: _customerId,
        customerName: _customerName,
        documentNumber: docNumber,
        date: _selectedDate,
        total: total,
        status: 'draft',
        projectId: _projectId,
        subject: subj.isEmpty ? null : subj,
        items: _items.map((e) => DocumentItem(
          id: e.id,
          productId: e.productId,
          productName: e.productName,
          quantity: e.quantity,
          unitPrice: e.unitPrice,
          taxRate: e.taxRate,
        )).toList(),
      );

      await _repo.save(doc);
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
    final result = await showModalBottomSheet<_EditingItem>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _ProductPickerSheet(
        customerId: _customerId,
        productRepo: _productRepo,
      ),
    );
    if (result != null && mounted) {
      _wrapWithSnapshot(() => _items.add(result));
    }
  }

  void _removeItem(int index) {
    _wrapWithSnapshot(() => _items.removeAt(index));
  }

  int get _total => _items.fold(0, (sum, item) => sum + (item.quantity * item.unitPrice).round());

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

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(_isNew ? 'DE:新規書類' : 'DE:書類編集'),
        actions: [
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
          const SizedBox(height: 20),
          _buildItemsSection(cs),
          const SizedBox(height: 20),
          _buildSummarySection(cs),
        ],
      ),
      bottomNavigationBar: _buildBottomBar(),
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
    return H1TextField(
      controller: _subjectCtl,
      decoration: const InputDecoration(
        labelText: '件名',
      ),
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
    final subtotal = (item.quantity * item.unitPrice).round();
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      elevation: 0.5,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(item.productName, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500, color: cs.onSurface)),
            const SizedBox(height: 6),
            Row(
              children: [
                GestureDetector(
                  onTap: () => _editPrice(index),
                  child: Text('￥${_formatMoney(item.unitPrice)}',
                    style: TextStyle(fontSize: 12, color: cs.primary, fontWeight: FontWeight.w600, decoration: TextDecoration.underline)),
                ),
                const SizedBox(width: 4),
                Text('× ${_formatQty(item.quantity)} = ￥${_formatMoney(subtotal)}',
                  style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                const Spacer(),
                IconButton(
                  icon: Icon(Icons.remove_circle_outline, size: 20, color: cs.onSurfaceVariant),
                  onPressed: () {
                    if (item.quantity > 1) {
                      _wrapWithSnapshot(() => item.quantity -= 1);
                    }
                  },
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(_formatQty(item.quantity),
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: cs.onSurface)),
                ),
                IconButton(
                  icon: Icon(Icons.add_circle_outline, size: 20, color: cs.onSurfaceVariant),
                  onPressed: () => _wrapWithSnapshot(() => item.quantity += 1),
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
                IconButton(
                  icon: Icon(Icons.delete_outline, size: 20, color: cs.error),
                  onPressed: () => _removeItem(index),
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummarySection(ColorScheme cs) {
    final subtotal = _total;
    final tax = (subtotal * 0.1).round();
    final total = subtotal + tax;
    return Container(
      decoration: BoxDecoration(
        color: cs.primaryContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _summaryRow('小計', subtotal, cs, labelColor: cs.onSurfaceVariant),
          const Divider(height: 20),
          _summaryRow('消費税 (10%)', tax, cs, labelColor: cs.onSurfaceVariant),
          const Divider(height: 20),
          _summaryRow('合計 (税込)', total, cs, totalStyle: true),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, int amount, ColorScheme cs, {Color? labelColor, bool totalStyle = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(
          fontSize: totalStyle ? 15 : 13,
          fontWeight: totalStyle ? FontWeight.bold : FontWeight.normal,
          color: labelColor ?? cs.onSurface,
        )),
        Text('￥${_formatMoney(amount)}', style: TextStyle(
          fontSize: totalStyle ? 18 : 14,
          fontWeight: totalStyle ? FontWeight.bold : FontWeight.normal,
          color: totalStyle ? cs.primary : cs.onSurface,
        )),
      ],
    );
  }

  Widget _buildBottomBar() {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            icon: _isSaving ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Theme.of(context).colorScheme.onPrimary)) : const Icon(Icons.save),
            label: Text(_isSaving ? '保存中...' : '下書き保存'),
            onPressed: _isSaving ? null : _save,
          ),
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
  final String subject;
  final List<_EditingItem> items;

  _EditorSnapshot({
    required this.selectedType,
    required this.customerId,
    required this.customerName,
    required this.selectedDate,
    this.projectId,
    this.projectName,
    this.subject = '',
    required this.items,
  });
}

class _EditingItem {
  final String id;
  String productId;
  String productName;
  double quantity;
  int unitPrice;
  double taxRate;

  _EditingItem({
    required this.id,
    this.productId = '',
    this.productName = '',
    this.quantity = 1,
    this.unitPrice = 0,
    this.taxRate = 0.1,
  });
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
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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


class _ProductPickerSheet extends StatefulWidget {
  final String? customerId;
  final ProductRepository productRepo;

  const _ProductPickerSheet({
    required this.customerId,
    required this.productRepo,
  });

  @override
  State<_ProductPickerSheet> createState() => _ProductPickerSheetState();
}

class _ProductPickerSheetState extends State<_ProductPickerSheet> {
  List<Product> _products = [];
  List<Product> _filtered = [];
  final _searchCtrl = TextEditingController();
  bool _loading = true;
  Map<String, int> _customerPrices = {};
  final _uuid = const Uuid();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final results = await Future.wait([
      widget.productRepo.searchProducts(''),
      _loadCustomerPrices(),
    ]);
    final products = (results[0] as List).cast<Product>();
    final customerPrices = results[1] as Map<String, int>;

    final prices = <String, int>{};
    for (final p in products) {
      final cp = customerPrices[p.id];
      prices[p.id] = cp ?? p.defaultUnitPrice;
    }
    for (final p in products) {
      if (p.parentId != null && !customerPrices.containsKey(p.id)) {
        final pp = customerPrices[p.parentId];
        if (pp != null) prices[p.id] = pp;
      }
    }

    if (mounted) {
      setState(() {
        _products = products;
        _filtered = products;
        _customerPrices = prices;
        _loading = false;
      });
    }
  }

  Future<Map<String, int>> _loadCustomerPrices() async {
    final cid = widget.customerId;
    if (cid == null || cid.isEmpty) return {};
    try {
      final db = await DatabaseHelper().database;
      final rows = await db.query(
        'customer_product_prices',
        where: 'customer_id = ?',
        whereArgs: [cid],
      );
      return {for (final r in rows) (r['product_id'] as String): (r['price'] as int?) ?? 0};
    } catch (_) {
      return {};
    }
  }

  void _search(String q) {
    final query = q.trim().toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filtered = _products;
      } else {
        _filtered = _products.where((p) =>
          p.name.toLowerCase().contains(query) ||
          (p.barcode?.toLowerCase().contains(query) ?? false) ||
          (p.category?.toLowerCase().contains(query) ?? false)
        ).toList();
      }
    });
  }

  Future<void> _createProduct(String name) async {
    final product = await Navigator.push<Product>(
      context,
      MaterialPageRoute(builder: (_) => const ProductEditorScreen()),
    );
    if (product != null && mounted) {
      Navigator.pop(context, _EditingItem(
        id: _uuid.v4(),
        productId: product.id,
        productName: product.name,
        quantity: 1,
        unitPrice: product.defaultUnitPrice,
      ));
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  bool _isCustomerPrice(Product product) {
    if (_customerPrices.containsKey(product.id)) return true;
    if (product.parentId != null && _customerPrices.containsKey(product.parentId)) return true;
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final query = _searchCtrl.text.trim();
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 8),
            width: 32, height: 4,
            decoration: BoxDecoration(
              color: cs.onSurfaceVariant.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                Text('商品を追加', style: Theme.of(context).textTheme.titleMedium),
                const Spacer(),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('キャンセル'),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: H1TextField(
              controller: _searchCtrl,
              decoration: const InputDecoration(
                hintText: '商品名で検索',
                prefixIcon: Icon(Icons.search),
                isDense: true,
              ),
              onChanged: _search,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.add_circle, size: 18),
                label: Text(query.isEmpty ? '新規商品登録' : '「$query」を新規登録'),
                onPressed: () => _createProduct(_searchCtrl.text.trim()),
              ),
            ),
          ),
          const SizedBox(height: 4),
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.55,
            ),
            child: _loading
              ? const Center(child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(),
                ))
              : _buildList(cs),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildList(ColorScheme cs) {
    final query = _searchCtrl.text.trim();
    final items = <Widget>[];

    if (_filtered.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            children: [
              Icon(Icons.search_off, size: 48, color: cs.onSurfaceVariant),
              const SizedBox(height: 8),
              Text('商品が見つかりません', style: TextStyle(color: cs.onSurfaceVariant)),
            ],
          ),
        ),
      );
    }

    for (final product in _filtered) {
      final price = _customerPrices[product.id] ?? product.defaultUnitPrice;
      final isCp = _isCustomerPrice(product);
      items.add(ListTile(
        leading: CircleAvatar(
          backgroundColor: cs.primaryContainer,
          child: Text(
            product.name.isNotEmpty ? product.name[0].toUpperCase() : '?',
            style: TextStyle(fontWeight: FontWeight.bold, color: cs.onPrimaryContainer),
          ),
        ),
        title: Text(product.name),
        subtitle: Row(
          children: [
            Text('¥$price', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
            if (isCp) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: cs.tertiaryContainer,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text('顧客別', style: TextStyle(fontSize: 10, color: cs.onTertiaryContainer)),
              ),
            ],
          ],
        ),
        trailing: Icon(Icons.add_circle_outline, size: 20, color: cs.primary),
        onTap: () {
          Navigator.pop(context, _EditingItem(
            id: _uuid.v4(),
            productId: product.id,
            productName: product.name,
            quantity: 1,
            unitPrice: price,
          ));
        },
      ));
    }

    return ListView(shrinkWrap: true, children: items);
  }
}
