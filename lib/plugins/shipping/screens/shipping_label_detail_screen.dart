import 'package:flutter/material.dart';
import 'package:h_1_core/constants/screen_ids.dart';
import 'package:h_1_core/widgets/screen_id_title.dart';
import '../models/shipping_label_model.dart';
import '../models/tracking_model.dart';
import '../services/shipping_label_printer.dart';
import '../services/tracking_repository.dart';
import 'tracking_detail_screen.dart';

class ShippingLabelDetailScreen extends StatefulWidget {
  final ShippingLabel label;

  const ShippingLabelDetailScreen({super.key, required this.label});

  @override
  State<ShippingLabelDetailScreen> createState() => _ShippingLabelDetailScreenState();
}

class _ShippingLabelDetailScreenState extends State<ShippingLabelDetailScreen> {
  Tracking? _linkedTracking;

  @override
  void initState() {
    super.initState();
    _loadLinkedTracking();
  }

  Future<void> _loadLinkedTracking() async {
    final tracking = await TrackingRepository().getByLabelId(widget.label.id);
    if (mounted) setState(() => _linkedTracking = tracking);
  }

  @override
  Widget build(BuildContext context) {
    final label = widget.label;
    return Scaffold(
      appBar: AppBar(
        title: const ScreenAppBarTitle(screenId: S.sh2, title: '送り状詳細'),
        actions: [
          IconButton(
            icon: const Icon(Icons.print),
            onPressed: () => _printLabel(context),
            tooltip: '印刷',
          ),
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () => _sharePdf(context),
            tooltip: 'PDF共有',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 追跡ステータスカード（連携中の場合）
          if (_linkedTracking != null) ...[
            Card(
              color: Theme.of(context).colorScheme.primaryContainer,
              child: ListTile(
                leading: const Icon(Icons.local_shipping),
                title: Text('追跡ステータス: ${_linkedTracking!.status.displayName}'),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    LinearProgressIndicator(
                      value: _linkedTracking!.status.progress / 100,
                    ),
                  ],
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => TrackingDetailScreen(tracking: _linkedTracking!),
                  ),
                ).then((_) => _loadLinkedTracking()),
              ),
            ),
            const SizedBox(height: 8),
          ],
          _buildSection('追跡番号', label.trackingNumber),
          _buildSection('宅配便会社', label.carrier.displayName),
          _buildSection('送り状種別', label.labelType.displayName),
          const Divider(height: 32),
          _buildSection('送付者', label.senderName),
          _buildSection('送付者郵便番号', label.senderZip),
          _buildSection('送付者住所', label.senderAddress),
          _buildSection('送付者電話', label.senderPhone),
          const Divider(height: 32),
          _buildSection('宛先', label.recipientName),
          _buildSection('宛先会社', label.recipientCompany ?? '-'),
          _buildSection('宛先郵便番号', label.recipientZip),
          _buildSection('宛先住所', label.recipientAddress),
          _buildSection('宛先電話', label.recipientPhone),
          const Divider(height: 32),
          _buildSection('内容品', label.contents ?? '-'),
          _buildSection('個数', '${label.quantity ?? 0}個'),
          _buildSection('重量', '${label.weight ?? 0}g'),
          _buildSection('サービス', label.serviceType ?? '-'),
          _buildSection('代引金額', label.codAmount != null ? '${label.codAmount}円' : '-'),
          const Divider(height: 32),
          _buildSection('作成日', _formatDate(label.createdAt)),
          if (label.printedAt != null) _buildSection('印刷日', _formatDate(label.printedAt!)),
        ],
      ),
    );
  }

  Widget _buildSection(String title, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.grey,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(fontSize: 16),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')} '
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _printLabel(BuildContext context) async {
    try {
      final printer = ShippingLabelPrinter();
      await printer.printLabel(widget.label);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('印刷に失敗しました: $e')),
        );
      }
    }
  }

  Future<void> _sharePdf(BuildContext context) async {
    try {
      final printer = ShippingLabelPrinter();
      await printer.savePdf(widget.label);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('PDFの保存に失敗しました: $e')),
        );
      }
    }
  }
}
