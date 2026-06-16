import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../services/error_reporter.dart';
import '../../../widgets/screen_id_title.dart';
import '../models/supplier.dart';
import '../models/supplier_product.dart';
import '../services/supplier_repository.dart';
import '../services/supplier_product_service.dart';
import '../../../constants/screen_ids.dart';

class SupplierProductsScreen extends StatefulWidget {
  const SupplierProductsScreen({super.key});
  @override
  State<SupplierProductsScreen> createState() => _SupplierProductsScreenState();
}

class _SupplierProductsScreenState extends State<SupplierProductsScreen> {
  int _tabIndex = 0;
  final _repo = SupplierRepository();
  final _service = SupplierProductService();
  List<Supplier> _suppliers = [];
  Supplier? _selectedSupplier;
  List<SupplierProduct> _products = [];
  List<String> _subCategories = [];
  final _searchCtrl = TextEditingController();
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final suppliers = await _repo.getAll();
      if (!mounted) return;
      setState(() => _suppliers = suppliers);
      if (suppliers.isNotEmpty) {
        await _selectSupplier(suppliers.first);
      } else {
        setState(() => _loading = false);
      }
    } catch (e) {
      ErrorReporter.showError(context, message: '仕入先一覧の読み込みに失敗しました', detail: e.toString(), screenId: S.sp);
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _selectSupplier(Supplier supplier) async {
    setState(() {
      _loading = true;
      _selectedSupplier = supplier;
    });
    try {
      final products = _searchCtrl.text.isEmpty
          ? await _service.getBySupplier(supplier.id)
          : await _service.search(supplier.id, _searchCtrl.text);
      final cats = await _service.getSubCategories(supplier.id);
      if (!mounted) return;
      setState(() {
        _products = products;
        _subCategories = cats;
        _loading = false;
      });
    } catch (e) {
      ErrorReporter.showError(context, message: '商品一覧の読み込みに失敗しました', detail: e.toString(), screenId: S.sp);
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _showProductDialog({SupplierProduct? product}) async {
    final isNew = product == null;
    final nameCtrl = TextEditingController(text: product?.name ?? '');
    final variantCtrl = TextEditingController(text: product?.variant ?? '');
    final janCtrl = TextEditingController(text: product?.janCode ?? '');
    final wholesaleCtrl = TextEditingController(text: product?.wholesalePrice.toString() ?? '');
    final retailCtrl = TextEditingController(text: product?.retailPrice.toString() ?? '');
    final mfrCtrl = TextEditingController(text: product?.manufacturer ?? '');
    final catCtrl = TextEditingController(text: product?.subCategory ?? '');

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isNew ? '商品追加' : '商品編集'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: '商品名', isDense: true), autofocus: isNew),
            const SizedBox(height: 8),
            TextField(controller: variantCtrl, decoration: const InputDecoration(labelText: 'バリエーション', isDense: true)),
            const SizedBox(height: 8),
            TextField(controller: janCtrl, decoration: const InputDecoration(labelText: 'JANコード', isDense: true)),
            const SizedBox(height: 8),
            TextField(controller: wholesaleCtrl, decoration: const InputDecoration(labelText: '卸価格', isDense: true), keyboardType: TextInputType.number),
            const SizedBox(height: 8),
            TextField(controller: retailCtrl, decoration: const InputDecoration(labelText: '上代価格', isDense: true), keyboardType: TextInputType.number),
            const SizedBox(height: 8),
            TextField(controller: mfrCtrl, decoration: const InputDecoration(labelText: 'メーカー', isDense: true)),
            const SizedBox(height: 8),
            TextField(controller: catCtrl, decoration: const InputDecoration(labelText: 'カテゴリ', isDense: true)),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('キャンセル')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('保存')),
        ],
      ),
    );
    if (result != true || !mounted) return;
    final name = nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('商品名を入力してください')));
      return;
    }
    final supplier = _selectedSupplier;
    if (supplier == null) return;
    try {
      final updated = SupplierProduct(
        id: product?.id ?? _service.generateId(),
        supplierId: supplier.id,
        name: name,
        variant: variantCtrl.text.isNotEmpty ? variantCtrl.text : null,
        janCode: janCtrl.text.isNotEmpty ? janCtrl.text : null,
        wholesalePrice: int.tryParse(wholesaleCtrl.text.replaceAll(RegExp(r'[,\s]'), '')) ?? 0,
        retailPrice: int.tryParse(retailCtrl.text.replaceAll(RegExp(r'[,\s]'), '')) ?? 0,
        manufacturer: mfrCtrl.text.isNotEmpty ? mfrCtrl.text : null,
        subCategory: catCtrl.text.isNotEmpty ? catCtrl.text : null,
      );
      await _service.save(updated);
      await _selectSupplier(supplier);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(isNew ? '${updated.name} を追加しました' : '${updated.name} を更新しました'),
      ));
    } catch (e) {
      ErrorReporter.showError(context, message: '保存に失敗しました', detail: e.toString(), screenId: S.sp);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const ScreenAppBarTitle(screenId: S.sp, title: '仕入商品'),
      ),
      body: _suppliers.isEmpty
          ? _emptyView(cs)
          : Column(children: [
              _supplierSelector(cs),
              if (_searchCtrl.text.isNotEmpty || _products.isNotEmpty)
                _searchBar(cs),
              _tabBar(cs),
              if (_loading)
                const Expanded(child: Center(child: CircularProgressIndicator()))
              else if (_tabIndex == 0)
                Expanded(child: _productListView(cs))
              else if (_tabIndex == 1)
                Expanded(child: _priceTrendView(cs))
              else
                Expanded(child: _analyticsView(cs)),
            ]),
      floatingActionButton: _tabIndex == 0 && _selectedSupplier != null
          ? FloatingActionButton.small(
              onPressed: () => _showProductDialog(),
              tooltip: '商品追加',
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  Widget _emptyView(ColorScheme cs) => Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
    Icon(Icons.inventory_2_outlined, size: 48, color: cs.onSurfaceVariant.withValues(alpha: 0.3)),
    const SizedBox(height: 12),
    Text('仕入先が登録されていません', style: TextStyle(color: cs.onSurfaceVariant)),
    const SizedBox(height: 4),
    Text('仕入先マスターから登録してください', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
  ]));

  Widget _supplierSelector(ColorScheme cs) => Padding(
    padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
    child: Row(children: [
      Expanded(
        child: DropdownButtonHideUnderline(
          child: DropdownButton<Supplier>(
            value: _selectedSupplier,
            isExpanded: true,
            items: _suppliers.map((s) => DropdownMenuItem(
              value: s,
              child: Text(s.displayName, overflow: TextOverflow.ellipsis),
            )).toList(),
            onChanged: (v) { if (v != null) _selectSupplier(v); },
          ),
        ),
      ),
      const SizedBox(width: 8),
      Text('${_products.length}件', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
    ]),
  );

  Widget _searchBar(ColorScheme cs) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
    child: TextField(
      controller: _searchCtrl,
      decoration: InputDecoration(
        hintText: '商品名・JANコードで検索',
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        suffixIcon: _searchCtrl.text.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear, size: 18),
                onPressed: () {
                  _searchCtrl.clear();
                  if (_selectedSupplier != null) _selectSupplier(_selectedSupplier!);
                },
              )
            : null,
      ),
      onSubmitted: (v) {
        if (_selectedSupplier != null) _selectSupplier(_selectedSupplier!);
      },
    ),
  );

  Widget _tabBar(ColorScheme cs) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
    child: Row(children: [
      _tabBtn('商品一覧', 0, cs),
      const SizedBox(width: 8),
      _tabBtn('価格推移', 1, cs),
      const SizedBox(width: 8),
      _tabBtn('分析', 2, cs),
    ]),
  );

  Widget _tabBtn(String label, int idx, ColorScheme cs) => Expanded(
    child: InkWell(
      onTap: () => setState(() => _tabIndex = idx),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(
            color: _tabIndex == idx ? cs.primary : Colors.transparent,
            width: 2,
          )),
        ),
        child: Text(label, textAlign: TextAlign.center,
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13,
            color: _tabIndex == idx ? cs.primary : cs.onSurfaceVariant)),
      ),
    ),
  );

  Widget _productListView(ColorScheme cs) {
    if (_products.isEmpty) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.inventory_2_outlined, size: 48, color: cs.onSurfaceVariant.withValues(alpha: 0.3)),
        const SizedBox(height: 12),
        Text('商品がありません', style: TextStyle(color: cs.onSurfaceVariant)),
        const SizedBox(height: 4),
        Text('FABから追加してください', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
      ]));
    }

    final fmt = NumberFormat('#,###');
    final useGrouping = _subCategories.isNotEmpty && _searchCtrl.text.isEmpty;
    final grouped = <String, List<SupplierProduct>>{};

    if (useGrouping) {
      for (final cat in _subCategories) {
        grouped[cat] = [];
      }
      grouped[''] = [];
      for (final p in _products) {
        final key = p.subCategory ?? '';
        if (!grouped.containsKey(key)) grouped[key] = [];
        grouped[key]!.add(p);
      }
    }

    return ListView.builder(
      itemCount: useGrouping ? _subCategories.length + (_products.length) : _products.length,
      itemBuilder: (_, i) {
        if (useGrouping) {
          if (i < _subCategories.length) {
            final cat = _subCategories[i];
            final items = grouped[cat] ?? [];
            return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 2),
                child: Text(cat, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: cs.primary)),
              ),
              ...items.map((p) => _productTile(p, fmt, cs)),
            ]);
          }
          return const SizedBox.shrink();
        }

        return _productTile(_products[i], fmt, cs);
      },
    );
  }

  Widget _productTile(SupplierProduct p, NumberFormat fmt, ColorScheme cs) => Card(
    margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
    child: InkWell(
      onTap: () => _showProductDialog(product: p),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: ListTile(
          dense: true,
          title: Text(p.fullName, style: const TextStyle(fontSize: 13)),
          subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (p.janCode != null) Text('JAN: ${p.janCode}', style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant)),
            Row(children: [
              Text('卸: ¥${fmt.format(p.wholesalePrice)}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: cs.primary)),
              if (p.retailPrice > 0) ...[
                const SizedBox(width: 12),
                Text('上代: ¥${fmt.format(p.retailPrice)}', style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
              ],
            ]),
          ]),
        ),
      ),
    ),
  );

  Widget _priceTrendView(ColorScheme cs) {
    if (_products.isEmpty) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.trending_up, size: 48, color: cs.onSurfaceVariant.withValues(alpha: 0.3)),
        const SizedBox(height: 12),
        Text('価格推移データがありません', style: TextStyle(color: cs.onSurfaceVariant)),
      ]));
    }

    final fmt = NumberFormat('#,###');
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: _products.length,
      itemBuilder: (_, i) {
        final p = _products[i];
        return Card(
          margin: const EdgeInsets.only(bottom: 4),
          child: ListTile(
            dense: true,
            title: Text(p.fullName, style: const TextStyle(fontSize: 13)),
            subtitle: Text('JAN: ${p.janCode ?? '-'}'),
            trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('卸: ¥${fmt.format(p.wholesalePrice)}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: cs.primary)),
              if (p.retailPrice > 0)
                Text('上代: ¥${fmt.format(p.retailPrice)}', style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant)),
            ]),
          ),
        );
      },
    );
  }

  Widget _analyticsView(ColorScheme cs) {
    if (_products.isEmpty) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.analytics_outlined, size: 48, color: cs.onSurfaceVariant.withValues(alpha: 0.3)),
        const SizedBox(height: 12),
        Text('分析データがありません', style: TextStyle(color: cs.onSurfaceVariant)),
      ]));
    }

    final fmt = NumberFormat('#,###');
    final total = _products.length;
    final avgWholesale = total > 0 ? _products.fold(0, (sum, p) => sum + p.wholesalePrice) ~/ total : 0;
    final avgRetail = total > 0 ? _products.fold(0, (sum, p) => sum + p.retailPrice) ~/ total : 0;
    final totalWholesale = _products.fold(0, (sum, p) => sum + p.wholesalePrice);
    final totalRetail = _products.fold(0, (sum, p) => sum + p.retailPrice);

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Row(children: [
          _summaryCard('総商品数', '${fmt.format(total)}件', Icons.inventory, cs.primary, cs),
          const SizedBox(width: 8),
          _summaryCard('平均卸価格', '¥${fmt.format(avgWholesale)}', Icons.shopping_cart, Colors.orange, cs),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          _summaryCard('平均上代価格', '¥${fmt.format(avgRetail)}', Icons.attach_money, Colors.green, cs),
          const SizedBox(width: 8),
          _summaryCard('総卸金額', '¥${fmt.format(totalWholesale)}', Icons.account_balance, cs.primary, cs),
        ]),
        const SizedBox(height: 8),
        _summaryCard('総上代金額', '¥${fmt.format(totalRetail)}', Icons.account_balance_wallet, Colors.green, cs),
        const SizedBox(height: 16),
        Text('利益率サマリー', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: cs.onSurfaceVariant)),
        const SizedBox(height: 8),
        if (totalWholesale > 0)
          LinearProgressIndicator(
            value: (totalRetail - totalWholesale) / totalRetail,
            backgroundColor: cs.surfaceContainerHighest,
          ),
        const SizedBox(height: 4),
        Text('平均粗利: ${totalWholesale > 0 ? ((totalRetail - totalWholesale) / totalWholesale * 100).toStringAsFixed(1) : "0.0"}%',
          style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
      ],
    );
  }

  Widget _summaryCard(String label, String value, IconData icon, Color color, ColorScheme cs) => Expanded(
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(children: [
          Icon(icon, size: 28, color: color),
          const SizedBox(width: 12),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant)),
            Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: cs.onSurface)),
          ]),
        ]),
      ),
    ),
  );
}
