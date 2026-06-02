import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../../models/product_model.dart';
import '../../../models/product_category_model.dart';
import '../../../services/product_repository.dart';
import '../../../services/product_category_repository.dart';
import '../../../widgets/h1_form_field.dart';
import 'category_picker_dialog.dart';
import '../../../services/sync_service.dart';

class ProductEditorScreen extends StatefulWidget {
  final Product? product;
  const ProductEditorScreen({super.key, this.product});

  @override
  State<ProductEditorScreen> createState() => _ProductEditorScreenState();
}

class _ProductEditorScreenState extends State<ProductEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtl = TextEditingController();
  final _priceCtl = TextEditingController();
  final _wholesaleCtl = TextEditingController();
  final _barcodeCtl = TextEditingController();
  final _modelCtl = TextEditingController();
  final _manufacturerCtl = TextEditingController();
  final _supplierCtl = TextEditingController();
  final _stockCtl = TextEditingController();
  String? _selectedCategoryId;
  String? _selectedCategoryPath;
  bool _isLocked = false;
  bool _isSaving = false;

  bool get _isEdit => widget.product != null;

  @override
  void initState() {
    super.initState();
    if (_isEdit) {
      final p = widget.product!;
      _nameCtl.text = p.name;
      _priceCtl.text = p.defaultUnitPrice.toString();
      _wholesaleCtl.text = p.wholesalePrice.toString();
      _barcodeCtl.text = p.barcode ?? '';
      _modelCtl.text = p.modelNumber ?? '';
      _manufacturerCtl.text = p.manufacturer ?? '';
      _selectedCategoryId = p.categoryId;
      _selectedCategoryPath = p.category;
      _supplierCtl.text = p.supplierName ?? '';
      _stockCtl.text = p.stockQuantity?.toString() ?? '';
      _isLocked = p.isLocked;
    }
  }

  @override
  void dispose() {
    _nameCtl.dispose();
    _priceCtl.dispose();
    _wholesaleCtl.dispose();
    _barcodeCtl.dispose();
    _modelCtl.dispose();
    _manufacturerCtl.dispose();
    _supplierCtl.dispose();
    _stockCtl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      final product = Product(
        id: widget.product?.id ?? Uuid().v4(),
        name: _nameCtl.text.trim(),
        defaultUnitPrice: int.tryParse(_priceCtl.text) ?? 0,
        wholesalePrice: int.tryParse(_wholesaleCtl.text) ?? 0,
        barcode: _barcodeCtl.text.trim().isEmpty ? null : _barcodeCtl.text.trim(),
        modelNumber: _modelCtl.text.trim().isEmpty ? null : _modelCtl.text.trim(),
        manufacturer: _manufacturerCtl.text.trim().isEmpty ? null : _manufacturerCtl.text.trim(),
        category: _selectedCategoryPath,
        categoryId: _selectedCategoryId,
        supplierName: _supplierCtl.text.trim().isEmpty ? null : _supplierCtl.text.trim(),
        stockQuantity: int.tryParse(_stockCtl.text),
        isLocked: _isLocked,
        isHidden: widget.product?.isHidden ?? false,
      );
      await ProductRepository().saveProduct(product);
      SyncService.pushChange(
        entityType: 'product',
        entityId: product.id,
        action: 'save',
        data: product.toMap(),
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('保存エラー: $e'), backgroundColor: Theme.of(context).colorScheme.error),
      );
    }
  }

  Future<void> _pickCategory() async {
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => CategoryPickerDialog(
        selectedId: _selectedCategoryId,
      ),
    );
    if (result == null) return;
    if (result.isEmpty) {
      setState(() {
        _selectedCategoryId = null;
        _selectedCategoryPath = null;
      });
      return;
    }
    final repo = ProductCategoryRepository();
    final path = await repo.getPath(result);
    final pathStr = path.map((c) => c.name).join(' > ');
    setState(() {
      _selectedCategoryId = result;
      _selectedCategoryPath = pathStr;
    });
  }

  Widget _buildCategoryField(ThemeData theme) {
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            decoration: BoxDecoration(
              border: Border.all(color: theme.colorScheme.outline),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              children: [
                Icon(Icons.folder, size: 18, color: theme.colorScheme.tertiary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _selectedCategoryPath ?? 'カテゴリ未選択',
                    style: TextStyle(
                      fontSize: 14,
                      color: _selectedCategoryPath != null
                          ? theme.colorScheme.onSurface
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        TextButton(
          onPressed: _pickCategory,
          child: const Text('選択'),
        ),
        if (_selectedCategoryId != null) ...[
          const SizedBox(width: 4),
          TextButton(
            onPressed: () {
              setState(() {
                _selectedCategoryId = null;
                _selectedCategoryPath = null;
              });
            },
            child: const Text('クリア'),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: Text(_isEdit ? '商品を編集' : '商品を新規登録'),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _save,
            style: TextButton.styleFrom(foregroundColor: theme.colorScheme.onPrimary),
            child: _isSaving
                ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: theme.colorScheme.onPrimary))
                : const Text('保存', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('基本情報', style: theme.textTheme.titleSmall),
                    const SizedBox(height: 12),
                    H1FormField(
                      controller: _nameCtl,
                      decoration: const InputDecoration(
                        labelText: '商品名 *',
                        prefixIcon: Icon(Icons.inventory_2),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty) ? '商品名は必須です' : null,
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: H1FormField(
                            controller: _priceCtl,
                            decoration: const InputDecoration(
                              labelText: '単価',
                              prefixIcon: Icon(Icons.monetization_on),
                              prefixText: '¥ ',
                            ),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: H1FormField(
                            controller: _wholesaleCtl,
                            decoration: const InputDecoration(
                              labelText: '仕入価格',
                              prefixIcon: Icon(Icons.shopping_cart),
                              prefixText: '¥ ',
                            ),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('詳細', style: theme.textTheme.titleSmall),
                    const SizedBox(height: 12),
                    H1FormField(
                      controller: _barcodeCtl,
                      decoration: const InputDecoration(
                        labelText: 'バーコード',
                        prefixIcon: Icon(Icons.qr_code),
                      ),
                    ),
                    const SizedBox(height: 14),
                    H1FormField(
                      controller: _modelCtl,
                      decoration: const InputDecoration(
                        labelText: '型番',
                        prefixIcon: Icon(Icons.tag),
                      ),
                    ),
                    const SizedBox(height: 14),
                    H1FormField(
                      controller: _manufacturerCtl,
                      decoration: const InputDecoration(
                        labelText: 'メーカー',
                        prefixIcon: Icon(Icons.factory),
                      ),
                    ),
                    const SizedBox(height: 14),
                    _buildCategoryField(theme),
                    const SizedBox(height: 14),
                    H1FormField(
                      controller: _supplierCtl,
                      decoration: const InputDecoration(
                        labelText: '仕入先',
                        prefixIcon: Icon(Icons.person),
                      ),
                    ),
                    const SizedBox(height: 14),
                    H1FormField(
                      controller: _stockCtl,
                      decoration: const InputDecoration(
                        labelText: '在庫数',
                        prefixIcon: Icon(Icons.inventory),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
