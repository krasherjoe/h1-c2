import 'package:flutter/material.dart';
import '../models/shipping_label_model.dart';
import '../models/tracking_model.dart';
import '../services/tracking_repository.dart';
import '../widgets/shipping_label_add_dialog.dart';
import 'shipping_label_detail_screen.dart';

class ShippingLabelScreen extends StatefulWidget {
  const ShippingLabelScreen({super.key});

  @override
  State<ShippingLabelScreen> createState() => _ShippingLabelScreenState();
}

class _ShippingLabelScreenState extends State<ShippingLabelScreen> {
  final ShippingLabelRepository _labelRepo = ShippingLabelRepository();
  List<ShippingLabel> _labels = [];
  List<ShippingLabel> _filteredLabels = [];
  bool _isLoading = true;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadLabels();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadLabels() async {
    setState(() => _isLoading = true);
    try {
      final labels = await _labelRepo.getAll();
      setState(() {
        _labels = labels;
        _filteredLabels = labels;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('送り状の読み込みに失敗しました: $e')),
        );
      }
    }
  }

  void _filterLabels(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredLabels = _labels;
      } else {
        _filteredLabels = _labels.where((label) {
          return label.trackingNumber.toLowerCase().contains(query.toLowerCase()) ||
                 label.recipientName.toLowerCase().contains(query.toLowerCase()) ||
                 label.recipientAddress.toLowerCase().contains(query.toLowerCase()) ||
                 label.carrier.displayName.toLowerCase().contains(query.toLowerCase());
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_labels.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.print, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text('送り状がありません'),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _showPrintDialog,
              icon: const Icon(Icons.add),
              label: const Text('送り状を作成'),
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
                hintText: '追跡番号、宛先、宅配便会社で検索',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: _filterLabels,
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _filteredLabels.length,
              itemBuilder: (context, index) {
                final label = _filteredLabels[index];
                return ListTile(
                  leading: _getCarrierIcon(label.carrier),
                  title: Text(label.recipientName),
                  subtitle: Text(
                    '${label.carrier.displayName} ${label.labelType.displayName}\n'
                    '${label.recipientAddress}',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _showLabelDetail(label),
                  onLongPress: () => _showLabelMenu(label),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showPrintDialog,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _getCarrierIcon(Carrier carrier) {
    switch (carrier) {
      case Carrier.yamato:
        return const Icon(Icons.local_shipping, color: Colors.blue);
      case Carrier.sagawa:
        return const Icon(Icons.local_shipping, color: Colors.green);
      case Carrier.jpPost:
        return const Icon(Icons.local_shipping, color: Colors.red);
      default:
        return const Icon(Icons.local_shipping, color: Colors.grey);
    }
  }

  void _showPrintDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => const ShippingLabelAddDialog(),
    );
    if (result == true) {
      await _loadLabels();
    }
  }

  void _showLabelDetail(ShippingLabel label) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ShippingLabelDetailScreen(label: label),
      ),
    ).then((_) => _loadLabels());
  }

  void _showLabelMenu(ShippingLabel label) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('編集'),
              onTap: () {
                Navigator.pop(context);
                _showEditDialog(label);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('削除', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                _deleteLabel(label);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showEditDialog(ShippingLabel label) {
    showDialog(
      context: context,
      builder: (context) => ShippingLabelAddDialog(
        initialLabel: label,
        onSaved: () => _loadLabels(),
      ),
    );
  }

  Future<void> _deleteLabel(ShippingLabel label) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('削除確認'),
        content: Text('送り状「${label.trackingNumber}」を削除しますか？'),
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
      try {
        await _labelRepo.delete(label.id);
        await _loadLabels();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('削除しました')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('削除に失敗しました: $e')),
          );
        }
      }
    }
  }
}
