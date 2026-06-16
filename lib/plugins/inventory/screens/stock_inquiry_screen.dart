import 'package:flutter/material.dart';
import '../../../services/product_repository.dart';
import '../../../models/product_model.dart';
import '../../../widgets/h1_text_field.dart';
import '../../../constants/screen_ids.dart';

class StockInquiryScreen extends StatefulWidget {
  const StockInquiryScreen({super.key});

  @override
  State<StockInquiryScreen> createState() => _StockInquiryScreenState();
}

class _StockInquiryScreenState extends State<StockInquiryScreen> {
  final ProductRepository _repo = ProductRepository();
  final TextEditingController _searchController = TextEditingController();

  List<Product> _products = [];
  List<Product> _filtered = [];
  bool _isLoading = true;
  String _sortMode = 'name_asc';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final data = await _repo.getAllProducts(includeHidden: false);
    if (!mounted) return;
    setState(() {
      _products = data;
      _isLoading = false;
      _applyFilter();
    });
  }

  void _applyFilter() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filtered = _products.where((p) {
        return p.name.toLowerCase().contains(query) ||
            (p.category?.toLowerCase().contains(query) ?? false) ||
            (p.barcode?.toLowerCase().contains(query) ?? false);
      }).toList();

      switch (_sortMode) {
        case 'stock_asc':
          _filtered.sort((a, b) => (a.stockQuantity ?? 0).compareTo(b.stockQuantity ?? 0));
          break;
        case 'stock_desc':
          _filtered.sort((a, b) => (b.stockQuantity ?? 0).compareTo(a.stockQuantity ?? 0));
          break;
        case 'name_desc':
          _filtered.sort((a, b) => b.name.toLowerCase().compareTo(a.name.toLowerCase()));
          break;
        case 'name_asc':
        default:
          _filtered.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
          break;
      }
    });
  }

  int get _totalStock => _filtered.fold(0, (sum, p) => sum + (p.stockQuantity ?? 0));
  int get _lowStockCount => _filtered.where((p) => (p.stockQuantity ?? 0) < 10).length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text('${S.iq}:在庫照会'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.sort),
            onSelected: (value) {
              setState(() {
                _sortMode = value;
                _applyFilter();
              });
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'name_asc', child: Text('商品名 (昇順)')),
              const PopupMenuItem(value: 'name_desc', child: Text('商品名 (降順)')),
              const PopupMenuItem(value: 'stock_asc', child: Text('在庫数 (少→多)')),
              const PopupMenuItem(value: 'stock_desc', child: Text('在庫数 (多→少)')),
            ],
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: H1TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: '商品名・カテゴリ・バーコードで検索',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Theme.of(context).colorScheme.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: EdgeInsets.zero,
              ),
              onChanged: (_) => _applyFilter(),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: Theme.of(context).colorScheme.secondaryContainer.withValues(alpha: 0.2),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('合計在庫数', style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                      Text(
                        '$_totalStock 個',
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('少在庫品目', style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                      Text(
                        '$_lowStockCount 品',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: _lowStockCount > 0 ? Theme.of(context).colorScheme.secondary : Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('登録商品数', style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                      Text(
                        '${_filtered.length} 品',
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filtered.isEmpty
                    ? const Center(child: Text('商品が見つかりません'))
                    : ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.only(bottom: 16, top: 8),
                        itemCount: _filtered.length,
                        itemBuilder: (context, index) {
                          final p = _filtered[index];
                          final isLowStock = (p.stockQuantity ?? 0) < 10;
                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: isLowStock ? Theme.of(context).colorScheme.secondaryContainer.withValues(alpha: 0.3) : Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
                                child: Icon(
                                  Icons.inventory_2,
                                  color: isLowStock ? Theme.of(context).colorScheme.secondary : Theme.of(context).colorScheme.primary,
                                ),
                              ),
                              title: Text(
                                p.name,
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              subtitle: Text(
                                '${p.category ?? '未分類'} ${p.barcode != null ? '/ ${p.barcode}' : ''}',
                              ),
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '${p.stockQuantity}',
                                    style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: isLowStock ? Theme.of(context).colorScheme.secondary : Theme.of(context).colorScheme.primary,
                                    ),
                                  ),
                                  Text('個', style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
