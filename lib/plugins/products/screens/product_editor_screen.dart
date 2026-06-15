import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../../models/product_model.dart';
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
  final _repo = ProductRepository();
  String? _selectedCategoryId;
  String? _selectedCategoryPath;
  bool _isLocked = false;
  bool _isSaving = false;

  // オプション関連
  List<ProductOptionGroup> _optionGroups = [];
  final _optionValues = <String, List<ProductOptionValue>>{};
  bool _isLoadingOptions = false;

  bool get _isEdit => widget.product != null;
  bool get _isVariant => widget.product?.isVariant ?? false;

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
      if (!_isVariant) _loadOptions();
    }
  }

  Future<void> _loadOptions() async {
    setState(() => _isLoadingOptions = true);
    final groups = await _repo.getOptionGroups(widget.product!.id);
    final values = <String, List<ProductOptionValue>>{};
    for (final g in groups) {
      values[g.id] = await _repo.getOptionValues(g.id);
    }
    if (!mounted) return;
    setState(() {
      _optionGroups = groups;
      _optionValues.clear();
      _optionValues.addAll(values);
      _isLoadingOptions = false;
    });
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
      Navigator.pop(context, product);
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
    final isDark = theme.brightness == Brightness.dark;
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            decoration: BoxDecoration(
              color: isDark ? theme.colorScheme.surfaceContainerHighest : theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                  color: theme.colorScheme.shadow.withValues(alpha: isDark ? 0.3 : 0.12),
                ),
                BoxShadow(
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                  color: theme.colorScheme.shadow.withValues(alpha: isDark ? 0.2 : 0.08),
                ),
              ],
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
            if (_isEdit && !_isVariant) ...[
              const SizedBox(height: 12),
              _buildOptionSection(theme),
            ],
          ],
        ),
      ),
    );
  }

  // ===== オプション設定 =====

  Widget _buildOptionSection(ThemeData theme) {
    final cs = theme.colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Text('オプション設定', style: theme.textTheme.titleSmall),
              const Spacer(),
              if (_isLoadingOptions)
                const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
            ]),
            const SizedBox(height: 8),
            Text('サイズ・色などのバリエーションを定義します。', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
            const SizedBox(height: 12),
            if (_optionGroups.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Center(child: Text('オプショングループがありません', style: TextStyle(color: cs.onSurfaceVariant))),
              )
            else
              for (final group in _optionGroups) _buildOptionGroupTile(theme, group),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _addOptionGroup,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('オプショングループを追加'),
              style: OutlinedButton.styleFrom(
                foregroundColor: cs.primary,
                side: BorderSide(color: cs.primary.withValues(alpha: 0.3)),
              ),
            ),
            if (_optionGroups.isNotEmpty) ...[
              const SizedBox(height: 16),
              _buildGenerateButton(theme),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildOptionGroupTile(ThemeData theme, ProductOptionGroup group) {
    final cs = theme.colorScheme;
    final values = _optionValues[group.id] ?? [];
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.dashboard_customize, size: 18, color: cs.primary),
            const SizedBox(width: 8),
            Text(group.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            if (group.isAbsolute)
              Container(
                margin: const EdgeInsets.only(left: 6),
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: cs.tertiaryContainer,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text('絶対値', style: TextStyle(fontSize: 9, color: cs.onTertiaryContainer)),
              ),
            const Spacer(),
            SizedBox(
              width: 24, height: 24,
              child: IconButton(
                padding: EdgeInsets.zero,
                icon: Icon(Icons.close, size: 16, color: cs.error),
                onPressed: () => _deleteOptionGroup(group.id),
              ),
            ),
          ]),
          const SizedBox(height: 8),
          for (final v in values) ...[
            Row(children: [
              const SizedBox(width: 26),
              Text(v.value, style: const TextStyle(fontSize: 13)),
              const SizedBox(width: 6),
              Text(v.priceLabel(group), style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
              const Spacer(),
              SizedBox(
                width: 20, height: 20,
                child: IconButton(
                  padding: EdgeInsets.zero,
                  icon: Icon(Icons.close, size: 14, color: cs.onSurfaceVariant),
                  onPressed: () => _deleteOptionValue(v.id),
                ),
              ),
            ]),
            const SizedBox(height: 4),
          ],
          TextButton.icon(
            onPressed: () => _addOptionValue(group),
            icon: const Icon(Icons.add, size: 16),
            label: const Text('値を追加', style: TextStyle(fontSize: 12)),
            style: TextButton.styleFrom(foregroundColor: cs.primary, padding: const EdgeInsets.symmetric(horizontal: 8)),
          ),
        ],
      ),
    );
  }

  Widget _buildGenerateButton(ThemeData theme) {
    return FutureBuilder<List<Product>>(
      future: _repo.getVariants(widget.product!.id),
      builder: (ctx, snap) {
        final count = snap.data?.length ?? 0;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => _generateVariants(),
                icon: const Icon(Icons.auto_awesome, size: 18),
                label: Text(count > 0 ? 'バリアントを再生成 ($count件)' : 'バリアントを生成'),
              ),
            ),
            if (count > 0)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('現在 $count 件のバリアントがあります。再生成すると既存は削除されます。',
                    style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant)),
              ),
          ],
        );
      },
    );
  }

  // ===== オプション操作 =====

  Future<void> _addOptionGroup() async {
    final nameCtl = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('オプショングループを追加'),
        content: TextField(
          controller: nameCtl,
          decoration: const InputDecoration(
            labelText: 'グループ名',
            hintText: '例: サイズ, 色',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('キャンセル')),
          FilledButton(onPressed: () => Navigator.pop(ctx, nameCtl.text.trim()), child: const Text('追加')),
        ],
      ),
    );
    if (result == null || result.isEmpty) return;

    final group = ProductOptionGroup(
      id: const Uuid().v4(),
      productId: widget.product!.id,
      name: result,
      sortOrder: _optionGroups.length,
    );
    await _repo.saveOptionGroup(group);
    await _loadOptions();
  }

  Future<void> _addOptionValue(ProductOptionGroup group) async {
    final valueCtl = TextEditingController();
    final priceCtl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('「${group.name}」に値を追加'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: valueCtl,
                decoration: const InputDecoration(labelText: '値', hintText: '例: S, M, L'),
                autofocus: true,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: priceCtl,
                decoration: InputDecoration(
                  labelText: group.isAbsolute ? '価格 (絶対値)' : '価格差分 (±円)',
                  hintText: '0',
                ),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('キャンセル')),
          FilledButton(onPressed: () => Navigator.pop(ctx, {'value': valueCtl.text.trim(), 'price': priceCtl.text.trim()}),
              child: const Text('追加')),
        ],
      ),
    );
    if (result == null) return;
    final label = result['value'] as String;
    if (label.isEmpty) return;

    final modifier = int.tryParse(result['price'] as String? ?? '') ?? 0;
    final existing = _optionValues[group.id] ?? [];
    final value = ProductOptionValue(
      id: const Uuid().v4(),
      groupId: group.id,
      value: label,
      priceModifier: modifier,
      sortOrder: existing.length,
    );
    await _repo.saveOptionValue(value);
    await _loadOptions();
  }

  Future<void> _deleteOptionGroup(String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('グループを削除'),
        content: const Text('このグループと全ての値を削除します。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('キャンセル')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('削除')),
        ],
      ),
    );
    if (ok != true) return;
    await _repo.deleteOptionGroup(id);
    await _loadOptions();
  }

  Future<void> _deleteOptionValue(String id) async {
    await _repo.deleteOptionValue(id);
    await _loadOptions();
  }

  Future<void> _generateVariants() async {
    final existing = await _repo.getVariants(widget.product!.id);
    if (existing.isNotEmpty) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('バリアントを再生成'),
          content: Text('既存の ${existing.length} 件のバリアントを削除して再生成します。よろしいですか？'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('キャンセル')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('削除して再生成')),
          ],
        ),
      );
      if (ok != true) return;
      await _repo.deleteVariants(widget.product!.id);
    }

    final ids = await _repo.generateVariants(widget.product!.id);
    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('バリアント生成完了'),
        content: Text('${ids.length} 件のバリアントを生成しました。'),
        actions: [
          FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
        ],
      ),
    );
  }
}
