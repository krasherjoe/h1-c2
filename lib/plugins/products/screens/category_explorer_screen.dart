import 'package:flutter/material.dart';
import 'package:csv/csv.dart';
import '../../../models/product_model.dart';
import '../../../services/product_repository.dart';
import '../../../services/product_category_repository.dart';
import '../../../models/product_category_model.dart';
import '../../../services/input_style_service.dart';
import '../../../services/error_reporter.dart';
import '../../../services/sheets_sync_service.dart';
import '../screens/product_editor_screen.dart';
import 'product_spreadsheet_screen.dart';
import 'product_tree_view_screen.dart';
import '../../../constants/screen_ids.dart';

class CategoryExplorerScreen extends StatefulWidget {
  const CategoryExplorerScreen({super.key});
  @override
  State<CategoryExplorerScreen> createState() => _CategoryExplorerScreenState();
}

class _CategoryExplorerScreenState extends State<CategoryExplorerScreen> {
  final _productRepo = ProductRepository();
  final _catRepo = ProductCategoryRepository();

  List<Product> _products = [];
  List<ProductCategory> _categories = [];
  bool _loading = true;
  String _searchQuery = '';
  String? _selectedCategoryId;

  // --- デザインシステム定数 (D1基準) ---
  static const _kSpacing = 8.0;   // D1と統一: Card margin = 8
  static const _kPadding = 6.0;   // D1と統一: Card内padding = 6

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final products = await _productRepo.getAllProducts();
    final categories = await _catRepo.getAll();
    if (!mounted) return;
    setState(() {
      _products = products;
      _categories = categories;
      _loading = false;
    });
    final showShadows = inputStyleNotifier.value == 'raised';
    final logMsg = 'P1 ログ: products=${_products.length}, categories=${_categories.length}, showShadows=$showShadows';
    debugPrint(logMsg);
    ErrorReporter.sendLog(message: logMsg);
    debugPrint('[P1] sample products: ${_products.take(3).map((p) => '${p.name}(${p.categoryId})').join(', ')}');
  }

  List<Product> get _filteredProducts {
    var list = _products;
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list.where((p) =>
        p.name.toLowerCase().contains(q) ||
        (p.barcode?.toLowerCase().contains(q) ?? false) ||
        (p.modelNumber?.toLowerCase().contains(q) ?? false)
      ).toList();
    }
    if (_selectedCategoryId != null) {
      list = list.where((p) => p.categoryId == _selectedCategoryId).toList();
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('${S.p1}:商品マスター'),
          centerTitle: true,
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(icon: Icon(Icons.account_tree), text: 'ツリー'),
              Tab(icon: Icon(Icons.table_chart), text: 'スプレッドシート'),
              Tab(icon: Icon(Icons.view_module), text: 'カード'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            const ProductTreeView(),
            const SpreadsheetProductScreen(),
            _buildCardTab(),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: _showProductActions,
          child: const Icon(Icons.add),
        ),
      ),
    );
  }

  Widget _buildSearchBar(ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: TextField(
        decoration: InputDecoration(
          hintText: '商品名で検索...',
          prefixIcon: const Icon(Icons.search),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        onChanged: (v) => setState(() => _searchQuery = v),
      ),
    );
  }

  Widget _buildCategoryFilter(ColorScheme cs) {
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        children: [
          FilterChip(
            label: const Text('すべて'),
            selected: _selectedCategoryId == null,
            onSelected: (_) => setState(() => _selectedCategoryId = null),
            visualDensity: VisualDensity.compact,
          ),
          const SizedBox(width: 8),
          ..._categories.map((cat) => Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(cat.name),
              selected: _selectedCategoryId == cat.id,
              onSelected: (_) => setState(() => _selectedCategoryId = cat.id),
              visualDensity: VisualDensity.compact,
            ),
          )),
        ],
      ),
    );
  }

  // --- カードタブ (旧リスト表示) ---
  Widget _buildCardTab() {
    final cs = Theme.of(context).colorScheme;
    return Column(
      children: [
        _buildSearchBar(cs),
        _buildCategoryFilter(cs),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _buildListView(cs),
        ),
      ],
    );
  }

  Widget _buildProductCard(Product product, int depth, ColorScheme cs, {bool showShadows = true}) {
    return LongPressDraggable<Product>(
      data: product,
      feedback: Material(
        elevation: 8,
        color: Colors.transparent,
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: cs.primaryContainer,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [BoxShadow(blurRadius: 8, color: cs.shadow.withValues(alpha: 0.3))],
          ),
          child: Icon(Icons.inventory_2, size: 24, color: cs.primary),
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.25,
        child: _buildProductCardContent(product, depth, cs, showShadows),
      ),
      child: _buildProductCardContent(product, depth, cs, showShadows),
    );
  }

  Widget _buildProductCardContent(Product product, int depth, ColorScheme cs, bool showShadows) {
    final priceStr = '¥${product.defaultUnitPrice.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}';
    const iconSize = 22.0;
    const textS = 14.0;
    const subS = 11.0;
    const priceS = 13.0;
    return Card(
      margin: EdgeInsets.symmetric(horizontal: _kSpacing / 2, vertical: 4.0),
      elevation: showShadows ? null : 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => _openProductViewer(product),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: _kPadding, vertical: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(Icons.inventory_2, size: iconSize, color: cs.primary,
                  shadows: showShadows ? [Shadow(blurRadius: 2, color: cs.shadow.withValues(alpha: 0.35))] : null),
              SizedBox(width: _kPadding),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(product.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: textS, fontWeight: FontWeight.w500)),
                    if (product.barcode != null)
                      Text('バーコード: ${product.barcode}',
                        style: TextStyle(fontSize: subS, color: cs.onSurfaceVariant)),
                  ],
                ),
              ),
              Text(priceStr, style: TextStyle(
                fontSize: priceS, fontWeight: FontWeight.bold, color: cs.primary)),
            ],
          ),
        ),
      ),
    );
  }

  // --- リスト表示 ---
  Widget _buildListView(ColorScheme cs) {
    final products = _filteredProducts;
    return ValueListenableBuilder<String>(
      valueListenable: inputStyleNotifier,
      builder: (context, inputStyle, _) {
        final showShadows = inputStyle == 'raised';
        return RefreshIndicator(
          onRefresh: _load,
          child: products.isEmpty
              ? Center(child: Text(_searchQuery.isNotEmpty ? '検索結果がありません' : '商品がありません'))
              : ListView.builder(
                  key: ValueKey('list_${products.length}_$_searchQuery'),
                  padding: EdgeInsets.all(_kSpacing),
                  itemCount: products.length,
                  itemBuilder: (ctx, i) => LayoutBuilder(
                    builder: (context, constraints) {
                      final availableW = constraints.maxWidth;
                      final cols = availableW > 600 ? 2 : 1;
                      final cardW = cols > 1 
                        ? (availableW - _kSpacing * (cols + 1)) / cols 
                        : availableW - _kSpacing * 2;
                      return SizedBox(width: cardW, child: _buildProductCard(products[i], 0, cs, showShadows: showShadows));
                    },
                  ),
                ),
        );
      },
    );
  }

  // --- 操作 ---
  void _showProductActions() async {
    final cs = Theme.of(context).colorScheme;
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: Icon(Icons.edit, color: cs.primary),
            title: const Text('手動で登録'),
            subtitle: const Text('フォームから1件ずつ入力'),
            onTap: () => Navigator.pop(ctx, 'manual'),
          ),
          ListTile(
            leading: Icon(Icons.file_upload, color: Colors.blue),
            title: const Text('CSVから取込'),
            subtitle: const Text('CSVファイルから商品を一括登録'),
            onTap: () => Navigator.pop(ctx, 'csv'),
          ),
          ListTile(
            leading: Icon(Icons.table_chart, color: Colors.green),
            title: const Text('スプレッドシートから取込'),
            subtitle: const Text('Google Sheetsのデータを商品として登録'),
            onTap: () => Navigator.pop(ctx, 'import'),
          ),
          ListTile(
            leading: Icon(Icons.file_download_outlined, color: Colors.orange),
            title: const Text('テンプレートを出力'),
            subtitle: const Text('商品データをGoogle Sheetsに書き出し'),
            onTap: () => Navigator.pop(ctx, 'export'),
          ),
        ]),
      ),
    );
    if (!mounted || action == null) return;
    switch (action) {
      case 'manual':
        final result = await Navigator.push<Product>(
          context,
          MaterialPageRoute(builder: (_) => const ProductEditorScreen()),
        );
        if (result != null) _load();
      case 'csv':
        await _importFromCsv();
      case 'import':
        await _importFromSheets();
      case 'export':
        await _exportToSheets();
    }
  }

  Future<void> _exportToSheets() async {
    try {
      final svc = SheetsSyncService.instance;
      final id = await svc.ensureProductSheet();
      if (id == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('❌ Google Sheets連携に失敗しました')),
        );
        return;
      }
      await svc.exportProducts(id);
      final url = 'https://docs.google.com/spreadsheets/d/$id';
      await svc.openUrl(url);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ テンプレートを作成しました。記入後「取込」を実行')),
      );
    } catch (e) {
      debugPrint('[Products] exportSheets error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ エクスポート失敗: $e')),
      );
    }
  }

  Future<void> _importFromSheets() async {
    try {
      final svc = SheetsSyncService.instance;
      final id = await svc.ensureProductSheet();
      if (id == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('❌ 先に「テンプレートを出力」してください')),
        );
        return;
      }
      final result = await svc.importProducts(id);
      if (!mounted) return;
      if (result.createdIds.isNotEmpty) {
        final ids = List<String>.from(result.createdIds);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ ${result.count}件の商品を取り込みました（新規${ids.length}件）'),
            duration: const Duration(seconds: 10),
            action: SnackBarAction(
              label: '元に戻す',
              onPressed: () {
                _undoImport(ids);
              },
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('✅ ${result.count}件の商品を更新しました')),
        );
      }
      await _load();
    } catch (e) {
      debugPrint('[Products] importSheets error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ インポート失敗: $e')),
      );
    }
  }

  Future<void> _importFromCsv() async {
    final csvText = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('CSVデータを貼り付け'),
        content: SingleChildScrollView(
          child: TextField(
            maxLines: 20,
            decoration: const InputDecoration(
              hintText: '商品名,単価,バーコード,型番,メーカー,カテゴリID',
              border: OutlineInputBorder(),
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('キャンセル')),
          FilledButton(onPressed: () => Navigator.pop(ctx, null), child: const Text('OK')),
        ],
      ),
    );
    if (csvText == null) return;
    
    try {
      final rows = const CsvToListConverter().convert(csvText);
      if (rows.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('❌ CSVデータが空です')),
        );
        return;
      }
      
      final createdIds = <String>[];
      final dataRows = rows.skip(1).toList();
      
      for (final row in dataRows) {
        if (row.length < 2) continue;
        final name = row[0]?.toString().trim() ?? '';
        final price = int.tryParse(row[1]?.toString() ?? '') ?? 0;
        if (name.isEmpty) continue;
        final product = Product(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          name: name,
          defaultUnitPrice: price,
          barcode: row.length > 2 ? row[2]?.toString() : null,
          modelNumber: row.length > 3 ? row[3]?.toString() : null,
          manufacturer: row.length > 4 ? row[4]?.toString() : null,
          categoryId: row.length > 5 ? row[5]?.toString() : null,
        );
        await _productRepo.saveProduct(product);
        createdIds.add(product.id);
      }
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ ${createdIds.length}件の商品を取り込みました'),
          duration: const Duration(seconds: 10),
          action: SnackBarAction(
            label: '元に戻す',
            onPressed: () {
              _undoImport(createdIds);
            },
          ),
        ),
      );
      await _load();
    } catch (e) {
      debugPrint('[Products] importCsv error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ CSVインポート失敗: $e')),
      );
    }
  }



  void _undoImport(List<String> productIds) async {
    for (final id in productIds) {
      try {
        await _productRepo.deleteProduct(id);
      } catch (_) {}
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('✅ ${productIds.length}件の商品を元に戻しました')),
    );
    _load();
  }

  void _openProductViewer(Product product) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _ProductViewer(
          product: product,
          onEdit: (p) async {
            final result = await Navigator.push<Product>(
              context,
              MaterialPageRoute(builder: (_) => ProductEditorScreen(product: p)),
            );
            if (result != null) _load();
          },
          onDelete: () async {
            await _productRepo.deleteProduct(product.id);
            _load();
          },
        ),
      ),
    ).then((_) => _load());
  }


}

// --- ビューアー画面 ---
class _ProductViewer extends StatelessWidget {
  final Product product;
  final Future<void> Function(Product) onEdit;
  final VoidCallback onDelete;

  const _ProductViewer({
    required this.product,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final priceStr = '¥${product.defaultUnitPrice.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}';
    return Scaffold(
      appBar: AppBar(
        title: Text(product.name),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete),
            tooltip: '削除',
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('削除確認'),
                  content: Text('「${product.name}」を削除しますか？'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('キャンセル')),
                    FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('削除')),
                  ],
                ),
              );
              if (confirm == true) {
                onDelete();
                if (context.mounted) Navigator.pop(context);
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: '編集',
            onPressed: () => onEdit(product),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _infoRow('商品名', product.name, cs),
          if (product.productNameKana != null) _infoRow('商品名カナ', product.productNameKana!, cs),
          _infoRow('単価', priceStr, cs),
          if (product.barcode != null) _infoRow('バーコード', product.barcode!, cs),
          if (product.modelNumber != null) _infoRow('型番', product.modelNumber!, cs),
          if (product.manufacturer != null) _infoRow('メーカー', product.manufacturer!, cs),
          if (product.manufacturerCode != null) _infoRow('メーカーコード', product.manufacturerCode!, cs),
          if (product.classificationCode != null) _infoRow('分類コード', product.classificationCode!, cs),
          if (product.divisionCode != null) _infoRow('ジャンルコード', product.divisionCode!, cs),
          if (product.category != null) _infoRow('カテゴリ', product.category!, cs),
          if (product.supplierName != null) _infoRow('仕入先', product.supplierName!, cs),
          if (product.stockQuantity != null) _infoRow('在庫数', '${product.stockQuantity}', cs),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value, ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(label, style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant, fontWeight: FontWeight.w500)),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 14))),
        ],
      ),
    );
  }
}
