import 'package:flutter/material.dart';
import '../models/shipping_address_model.dart';
import '../services/tracking_repository.dart';
import '../widgets/shipping_address_add_dialog.dart';

class ShippingAddressScreen extends StatefulWidget {
  const ShippingAddressScreen({super.key});

  @override
  State<ShippingAddressScreen> createState() => _ShippingAddressScreenState();
}

class _ShippingAddressScreenState extends State<ShippingAddressScreen> {
  final ShippingAddressRepository _addressRepo = ShippingAddressRepository();
  List<ShippingAddress> _addresses = [];
  List<ShippingAddress> _filteredAddresses = [];
  bool _isLoading = true;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadAddresses();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadAddresses() async {
    setState(() => _isLoading = true);
    try {
      final addresses = await _addressRepo.getAll();
      setState(() {
        _addresses = addresses;
        _filteredAddresses = addresses;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('送付先の読み込みに失敗しました: $e')),
        );
      }
    }
  }

  void _filterAddresses(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredAddresses = _addresses;
      } else {
        _filteredAddresses = _addresses.where((address) {
          return address.name.toLowerCase().contains(query.toLowerCase()) ||
                 address.company.toLowerCase().contains(query.toLowerCase()) ||
                 address.address.toLowerCase().contains(query.toLowerCase()) ||
                 address.zip.contains(query);
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_addresses.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.location_on, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text('送付先がありません'),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _showAddAddressDialog,
              icon: const Icon(Icons.add),
              label: const Text('送付先を追加'),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                hintText: '名前、会社、住所、郵便番号で検索',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: _filterAddresses,
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _filteredAddresses.length,
              itemBuilder: (context, index) {
                final address = _filteredAddresses[index];
                return ListTile(
                  leading: address.isDefault
                      ? const Icon(Icons.star, color: Colors.amber)
                      : const Icon(Icons.location_on),
                  title: Text(address.name),
                  subtitle: Text(
                    '${address.company.isNotEmpty ? '${address.company} ' : ''}'
                    '〒${address.zip} ${address.address}',
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete),
                    onPressed: () => _deleteAddress(address.id),
                  ),
                  onTap: () => _showAddressDetail(address),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddAddressDialog,
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showAddAddressDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => const ShippingAddressAddDialog(),
    );
    if (result == true) {
      await _loadAddresses();
    }
  }

  void _showAddressDetail(ShippingAddress address) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => ShippingAddressAddDialog(address: address),
    );
    if (result == true) {
      await _loadAddresses();
    }
  }

  Future<void> _deleteAddress(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('送付先を削除'),
        content: const Text('この送付先を削除しますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('削除'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _addressRepo.delete(id);
      await _loadAddresses();
    }
  }
}
