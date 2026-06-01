import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/document_model.dart';
import '../services/document_repository.dart';
import '../../../services/customer_repository.dart';
import '../../../models/customer_model.dart';
import '../../../models/product_model.dart';
import '../../../services/product_repository.dart';

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

  late DocumentType _selectedType;
  late String _customerId;
  late String _customerName;
  late DateTime _selectedDate;
  late List<_EditingItem> _items;
  bool _isSaving = false;

  bool get _isNew => widget.document == null;

  @override
  void initState() {
    super.initState();
    final doc = widget.document;
    _selectedType = doc?.documentType ?? DocumentType.invoice;
    _customerId = doc?.customerId ?? '';
    _customerName = doc?.customerName ?? '';
    _selectedDate = doc?.date ?? DateTime.now();
    _items = (doc?.items ?? []).map((item) => _EditingItem(
      id: item.id,
      productId: item.productId,
      productName: item.productName,
      quantity: item.quantity,
      unitPrice: item.unitPrice,
      taxRate: item.taxRate,
    )).toList();
  }

  Future<void> _save({bool confirmed = false}) async {
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
        status: confirmed ? 'confirmed' : 'draft',
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
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('保存エラー: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _selectCustomer() async {
    final result = await showSearch<String>(
      context: context,
      delegate: _CustomerSearchDelegate(repo: _customerRepo),
    );
    if (result != null && mounted) {
      final customer = await _customerRepo.getById(result);
      if (customer != null && mounted) {
        setState(() {
          _customerId = customer.id;
          _customerName = customer.displayName.isNotEmpty ? customer.displayName : customer.formalName;
        });
      }
    }
  }

  Future<void> _addItem() async {
    final result = await showDialog<_EditingItem>(
      context: context,
      builder: (ctx) => _ItemEditDialog(
        existing: null,
        productRepo: _productRepo,
      ),
    );
    if (result != null && mounted) {
      setState(() => _items.add(result));
    }
  }

  Future<void> _editItem(int index) async {
    final result = await showDialog<_EditingItem>(
      context: context,
      builder: (ctx) => _ItemEditDialog(
        existing: _items[index],
        productRepo: _productRepo,
      ),
    );
    if (result != null && mounted) {
      setState(() => _items[index] = result);
    }
  }

  void _removeItem(int index) {
    setState(() => _items.removeAt(index));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (_isNew) _buildTypeSelector(theme),
              const SizedBox(height: 16),
              _buildCustomerField(theme),
              const SizedBox(height: 12),
              _buildDateField(theme),
              const Divider(height: 24),
              _buildItemsHeader(theme),
              ..._items.asMap().entries.map((entry) =>
                _buildItemRow(entry.key, entry.value, theme)),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text('明細追加'),
                  onPressed: _addItem,
                ),
              ),
            ],
          ),
        ),
        _buildBottomBar(),
      ],
    );
  }

  Widget _buildTypeSelector(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('伝票種別', style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        DropdownButtonFormField<DocumentType>(
          initialValue: _selectedType,
          items: DocumentType.values.map((t) => DropdownMenuItem(
            value: t,
            child: Text(t.label),
          )).toList(),
          onChanged: (v) {
            if (v != null) setState(() => _selectedType = v);
          },
        ),
      ],
    );
  }

  Widget _buildCustomerField(ThemeData theme) {
    return InkWell(
      onTap: _selectCustomer,
      child: InputDecorator(
        decoration: const InputDecoration(
          labelText: '顧客',
          suffixIcon: Icon(Icons.search),
        ),
        child: Text(_customerName.isNotEmpty ? _customerName : 'タップして選択'),
      ),
    );
  }

  Widget _buildDateField(ThemeData theme) {
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: _selectedDate,
          firstDate: DateTime(2000),
          lastDate: DateTime(2100),
        );
        if (picked != null && mounted) {
          setState(() => _selectedDate = picked);
        }
      },
      child: InputDecorator(
        decoration: const InputDecoration(
          labelText: '日付',
          suffixIcon: Icon(Icons.calendar_today),
        ),
        child: Text(
          '${_selectedDate.year}/${_selectedDate.month.toString().padLeft(2, '0')}/${_selectedDate.day.toString().padLeft(2, '0')}',
        ),
      ),
    );
  }

  Widget _buildItemsHeader(ThemeData theme) {
    return Text('明細 (${_items.length})', style: theme.textTheme.titleSmall);
  }

  Widget _buildItemRow(int index, _EditingItem item, ThemeData theme) {
    return Card(
      child: ListTile(
        title: Text(item.productName),
        subtitle: Text('${_formatQty(item.quantity)} × ${_formatMoney(item.unitPrice)} = ${_formatMoney((item.quantity * item.unitPrice).round())}'),
        trailing: IconButton(
          icon: const Icon(Icons.delete, color: Colors.red),
          onPressed: () => _removeItem(index),
        ),
        onTap: () => _editItem(index),
      ),
    );
  }

  Widget _buildBottomBar() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _isSaving ? null : () => _save(confirmed: false),
                child: const Text('下書き保存'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                onPressed: _isSaving ? null : () => _save(confirmed: true),
                child: const Text('確定保存'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatMoney(int amount) =>
    '¥${amount.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}';

  String _formatQty(double qty) =>
    qty == qty.roundToDouble() ? qty.toInt().toString() : qty.toStringAsFixed(1);
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

class _ItemEditDialog extends StatefulWidget {
  final _EditingItem? existing;
  final ProductRepository productRepo;

  _ItemEditDialog({required this.existing, required this.productRepo});

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
            const SizedBox(height: 12),
            TextField(
              controller: _qtyController,
              decoration: const InputDecoration(labelText: '数量'),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            TextField(
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
