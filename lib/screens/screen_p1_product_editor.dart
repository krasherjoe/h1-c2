import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/product_model.dart';
import '../services/product_repository.dart';
import '../widgets/h1_form_field.dart';

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
  final _categoryCtl = TextEditingController();
  final _supplierCtl = TextEditingController();
  final _stockCtl = TextEditingController();
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
      _categoryCtl.text = p.category ?? '';
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
    _categoryCtl.dispose();
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
        category: _categoryCtl.text.trim().isEmpty ? null : _categoryCtl.text.trim(),
        supplierName: _supplierCtl.text.trim().isEmpty ? null : _supplierCtl.text.trim(),
        stockQuantity: int.tryParse(_stockCtl.text),
        isLocked: _isLocked,
        isHidden: widget.product?.isHidden ?? false,
      );
      await ProductRepository().saveProduct(product);
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
            child: _isSaving
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
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
                    H1FormField(
                      controller: _categoryCtl,
                      decoration: const InputDecoration(
                        labelText: 'カテゴリ',
                        prefixIcon: Icon(Icons.folder),
                      ),
                    ),
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
