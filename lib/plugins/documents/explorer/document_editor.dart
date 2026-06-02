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
import '../../../widgets/h1_text_field.dart';
import '../../../services/error_reporter.dart';
import '../../pricelist/models/price_entry.dart';
import '../../pricelist/screens/price_explorer_screen.dart';

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

  void _takeSnapshot() {
    _undoStack.add(_EditorSnapshot(
      selectedType: _selectedType,
      customerId: _customerId,
      customerName: _customerName,
      selectedDate: _selectedDate,
      projectId: _projectId,
      projectName: _projectName,
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
      Navigator.pop(context, true);
    } catch (e, st) {
      ErrorReporter.sendError(
        message: '書類保存失敗: $e',
        screenId: '/documents/editor',
        stackTrace: st,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('保存エラー: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _wrapWithSnapshot(VoidCallback fn) {
    _takeSnapshot();
    fn();
  }

  Future<void> _selectCustomer() async {
    final result = await showSearch<String>(
      context: context,
      delegate: _CustomerSearchDelegate(repo: _customerRepo),
    );
    if (result != null && mounted) {
      final customer = await _customerRepo.getById(result);
      if (customer != null && mounted) {
        _wrapWithSnapshot(() {
          _customerId = customer.id;
          _customerName = customer.displayName.isNotEmpty ? customer.displayName : customer.formalName;
        });
      }
    }
  }

  Future<void> _selectProject() async {
    final projects = await _projectRepo.getAll();
    if (!mounted) return;

    final filtered = _customerId.isNotEmpty
        ? projects.where((p) => p.customerId == _customerId).toList()
        : projects;

    final result = await showDialog<Project>(
      context: context,
      builder: (ctx) => _ProjectPickerDialog(
        projects: filtered,
        projectRepo: _projectRepo,
        customerId: _customerId,
        customerName: _customerName,
      ),
    );
    if (result != null && mounted) {
      _wrapWithSnapshot(() {
        _projectId = result.id;
        _projectName = result.name;
      });
    }
  }

  Future<void> _addItem() async {
    final result = await showDialog<_EditingItem>(
      context: context,
      builder: (ctx) => _ItemEditDialog(
        existing: null,
        productRepo: _productRepo,
        customerName: _customerName,
      ),
    );
    if (result != null && mounted) {
      _wrapWithSnapshot(() => _items.add(result));
    }
  }

  Future<void> _editItem(int index) async {
    final result = await showDialog<_EditingItem>(
      context: context,
      builder: (ctx) => _ItemEditDialog(
        existing: _items[index],
        productRepo: _productRepo,
        customerName: _customerName,
      ),
    );
    if (result != null && mounted) {
      _wrapWithSnapshot(() => _items[index] = result);
    }
  }

  void _removeItem(int index) {
    _wrapWithSnapshot(() => _items.removeAt(index));
  }

  int get _total => _items.fold(0, (sum, item) => sum + (item.quantity * item.unitPrice).round());

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(_isNew ? 'DE:新規書類' : 'DE:書類編集'),
        actions: [
          IconButton(
            icon: Icon(Icons.undo, color: _canUndo ? null : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3)),
            tooltip: '元に戻す',
            onPressed: _canUndo ? _undo : null,
          ),
          IconButton(
            icon: Icon(Icons.redo, color: _canRedo ? null : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3)),
            tooltip: 'やり直す',
            onPressed: _canRedo ? _redo : null,
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
            GestureDetector(
              onTap: () => _editItem(index),
              child: Text(item.productName, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500, color: cs.onSurface)),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: Text('￥${_formatMoney(item.unitPrice)} × ${_formatQty(item.quantity)} = ￥${_formatMoney(subtotal)}',
                    style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                ),
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
                GestureDetector(
                  onTap: () => _showQuantityDialog(index),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(_formatQty(item.quantity),
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: cs.onSurface)),
                  ),
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

  Future<void> _showQuantityDialog(int index) async {
    final item = _items[index];
    final controller = TextEditingController(text: item.quantity.toString());
    final result = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('数量を入力'),
        content: H1TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: '数量'),
          keyboardType: TextInputType.number,
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('キャンセル')),
          FilledButton(onPressed: () {
            final v = double.tryParse(controller.text);
            if (v != null && v > 0) Navigator.pop(ctx, v);
          }, child: const Text('OK')),
        ],
      ),
    );
    if (result != null && mounted) {
      _wrapWithSnapshot(() => _items[index].quantity = result);
    }
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
            icon: _isSaving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.save),
            label: Text(_isSaving ? '保存中...' : '下書き保存'),
            onPressed: _isSaving ? null : _save,
          ),
        ),
      ),
    );
  }

  String _formatMoney(int amount) =>
    '¥${amount.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}';

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
  final List<_EditingItem> items;

  _EditorSnapshot({
    required this.selectedType,
    required this.customerId,
    required this.customerName,
    required this.selectedDate,
    this.projectId,
    this.projectName,
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

class _CustomerSearchDelegate extends SearchDelegate<String> {
  final CustomerRepository repo;

  _CustomerSearchDelegate({required this.repo});

  @override
  List<Widget>? buildActions(BuildContext context) => [
    IconButton(icon: const Icon(Icons.clear), onPressed: () => query = ''),
  ];

  @override
  Widget? buildLeading(BuildContext context) => IconButton(
    icon: const Icon(Icons.arrow_back),
    onPressed: () => close(context, ''),
  );

  @override
  Widget buildResults(BuildContext context) => _buildSearchResults(context);

  @override
  Widget buildSuggestions(BuildContext context) => _buildSearchResults(context);

  Widget _buildSearchResults(BuildContext context) {
    if (query.isEmpty) return const Center(child: Text('顧客名を入力してください'));
    return FutureBuilder<List>(
      future: repo.searchCustomers(query),
      builder: (ctx, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('エラー: ${snapshot.error}'));
        }
        final customers = snapshot.data ?? [];
        if (customers.isEmpty) return const Center(child: Text('見つかりませんでした'));
        return ListView.builder(
          itemCount: customers.length,
          itemBuilder: (ctx, i) {
            final c = customers[i] as Customer;
            return ListTile(
              title: Text(c.displayName.isNotEmpty ? c.displayName : c.formalName),
              subtitle: Text(c.id),
              onTap: () => close(context, c.id),
            );
          },
        );
      },
    );
  }
}

class _ProjectPickerDialog extends StatefulWidget {
  final List<Project> projects;
  final ProjectRepository projectRepo;
  final String customerId;
  final String customerName;

  const _ProjectPickerDialog({
    required this.projects,
    required this.projectRepo,
    required this.customerId,
    required this.customerName,
  });

  @override
  State<_ProjectPickerDialog> createState() => _ProjectPickerDialogState();
}

class _ProjectPickerDialogState extends State<_ProjectPickerDialog> {
  late List<Project> _projects;

  @override
  void initState() {
    super.initState();
    _projects = widget.projects;
  }

  Future<void> _createNewProject() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('新規案件'),
        content: H1TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: '案件名'),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('キャンセル')),
          FilledButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                Navigator.pop(ctx, controller.text.trim());
              }
            },
            child: const Text('作成'),
          ),
        ],
      ),
    );
    if (name == null || !mounted) return;
    try {
      final id = await widget.projectRepo.createProject(
        name: name,
        customerId: widget.customerId,
        customerName: widget.customerName,
      );
      final project = await widget.projectRepo.getById(id);
      if (project != null && mounted) {
        setState(() => _projects = [project, ..._projects]);
        Navigator.pop(context, project);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('作成エラー: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('案件を選択'),
      content: SizedBox(
        width: double.maxFinite,
        child: _projects.isEmpty
          ? const Center(child: Text('案件がありません'))
          : ListView.builder(
              shrinkWrap: true,
              itemCount: _projects.length,
              itemBuilder: (ctx, i) {
                final p = _projects[i];
                return ListTile(
                  leading: const Icon(Icons.workspaces),
                  title: Text(p.name),
                  subtitle: Text('${p.customerName ?? ""}  ${p.pipelineStage}'),
                  onTap: () => Navigator.pop(context, p),
                );
              },
            ),
      ),
      actions: [
        TextButton(
          onPressed: _createNewProject,
          child: const Text('新規案件作成'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('キャンセル'),
        ),
      ],
    );
  }
}

class _ItemEditDialog extends StatefulWidget {
  final _EditingItem? existing;
  final ProductRepository productRepo;
  final String? customerName;

  _ItemEditDialog({required this.existing, required this.productRepo, this.customerName});

  @override
  State<_ItemEditDialog> createState() => _ItemEditDialogState();
}

class _ItemEditDialogState extends State<_ItemEditDialog> {
  late String _productId;
  late String _productName;
  late TextEditingController _qtyController;
  late TextEditingController _priceController;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _productId = e?.productId ?? '';
    _productName = e?.productName ?? '';
    _qtyController = TextEditingController(text: e?.quantity.toString() ?? '1');
    _priceController = TextEditingController(text: e?.unitPrice.toString() ?? '0');
  }

  @override
  void dispose() {
    _qtyController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  void _selectProduct() async {
    final result = await showSearch<String>(
      context: context,
      delegate: _ProductSearchDelegate(repo: widget.productRepo),
    );
    if (result != null && mounted) {
      final product = await widget.productRepo.getProduct(result);
      if (product != null && mounted) {
        setState(() {
          _productId = product.id;
          _productName = product.name;
          _priceController.text = product.defaultUnitPrice.toString();
        });
      }
    }
  }

  void _selectFromPriceList() async {
    final result = await Navigator.push<PriceEntry>(
      context,
      MaterialPageRoute(
        builder: (_) => PriceExplorerScreen(
          initialCustomerName: widget.customerName,
          selectionMode: true,
        ),
      ),
    );
    if (result != null && mounted) {
      setState(() {
        _productId = result.productId ?? '';
        _productName = result.name;
        _priceController.text = (result.unitPrice ?? 0).toString();
      });
    }
  }

  void _submit() {
    final qty = double.tryParse(_qtyController.text) ?? 1;
    final price = int.tryParse(_priceController.text) ?? 0;
    if (_productName.isEmpty) return;
    Navigator.pop(context, _EditingItem(
      id: widget.existing?.id ?? const Uuid().v4(),
      productId: _productId,
      productName: _productName,
      quantity: qty,
      unitPrice: price,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? '明細追加' : '明細編集'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            InkWell(
              onTap: _selectProduct,
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: '商品',
                  suffixIcon: Icon(Icons.search),
                ),
                child: Text(_productName.isNotEmpty ? _productName : 'タップして選択'),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.price_change, size: 18),
                label: const Text('価格表から選択'),
                onPressed: _selectFromPriceList,
              ),
            ),
            const SizedBox(height: 12),
            H1TextField(
              controller: _qtyController,
              decoration: const InputDecoration(labelText: '数量'),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            H1TextField(
              controller: _priceController,
              decoration: const InputDecoration(labelText: '単価'),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('キャンセル'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('OK'),
        ),
      ],
    );
  }
}

class _ProductSearchDelegate extends SearchDelegate<String> {
  final ProductRepository repo;

  _ProductSearchDelegate({required this.repo});

  @override
  List<Widget>? buildActions(BuildContext context) => [
    IconButton(icon: const Icon(Icons.clear), onPressed: () => query = ''),
  ];

  @override
  Widget? buildLeading(BuildContext context) => IconButton(
    icon: const Icon(Icons.arrow_back),
    onPressed: () => close(context, ''),
  );

  @override
  Widget buildResults(BuildContext context) => _buildSearchResults(context);

  @override
  Widget buildSuggestions(BuildContext context) => _buildSearchResults(context);

  Widget _buildSearchResults(BuildContext context) {
    if (query.isEmpty) return const Center(child: Text('商品名を入力してください'));
    return FutureBuilder<List>(
      future: repo.searchProducts(query),
      builder: (ctx, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('エラー: ${snapshot.error}'));
        }
        final products = snapshot.data ?? [];
        if (products.isEmpty) return const Center(child: Text('見つかりませんでした'));
        return ListView.builder(
          itemCount: products.length,
          itemBuilder: (ctx, i) {
            final p = products[i] as Product;
            return ListTile(
              title: Text(p.name),
              subtitle: Text('¥${p.defaultUnitPrice}'),
              onTap: () => close(context, p.id),
            );
          },
        );
      },
    );
  }
}
