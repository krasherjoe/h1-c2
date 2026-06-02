import 'package:flutter/material.dart';
import '../models/stock_transaction_model.dart';
import '../services/inventory_repository.dart';
import '../../../services/product_repository.dart';
import '../../../models/product_model.dart';
import '../../../widgets/h1_text_field.dart';

class StockOutboundScreen extends StatefulWidget {
  const StockOutboundScreen({super.key});

  @override
  State<StockOutboundScreen> createState() => _StockOutboundScreenState();
}

class _StockOutboundScreenState extends State<StockOutboundScreen> {
  final _repo = InventoryRepository();
  final _productRepo = ProductRepository();
  String _productId = '';
  String _productName = '';
  final _qtyController = TextEditingController(text: '1');
  DateTime _selectedDate = DateTime.now();
  final _noteController = TextEditingController();
  bool _isSaving = false;

  @override
  void dispose() {
    _qtyController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _selectProduct() async {
    final result = await showSearch<String>(
      context: context,
      delegate: _ProductSearchDelegate(repo: _productRepo),
    );
    if (result != null && mounted) {
      final product = await _productRepo.getProduct(result);
      if (product != null && mounted) {
        setState(() {
          _productId = product.id;
          _productName = product.name;
        });
      }
    }
  }

  Future<void> _save() async {
    if (_productId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('商品を選択してください')),
      );
      return;
    }
    final qty = double.tryParse(_qtyController.text) ?? 0;
    if (qty <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('数量を入力してください')),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      await _repo.save(StockTransaction(
        id: _repo.generateId(),
        type: StockTransactionType.outbound,
        productId: _productId,
        productName: _productName,
        quantity: -qty,
        date: _selectedDate,
        note: _noteController.text.isNotEmpty ? _noteController.text : null,
      ));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('出庫を記録しました')),
      );
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('出庫')),
      body: ListView(
        padding: const EdgeInsets.all(16),
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
          H1TextField(
            controller: _qtyController,
            decoration: const InputDecoration(
              labelText: '数量',
            ),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 12),
          InkWell(
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
          ),
          const SizedBox(height: 12),
          H1TextField(
            controller: _noteController,
            decoration: const InputDecoration(
              labelText: 'メモ',
            ),
            maxLines: 2,
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            icon: const Icon(Icons.save),
            label: const Text('保存'),
            onPressed: _isSaving ? null : _save,
          ),
        ],
      ),
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
