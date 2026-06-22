import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/tracking_model.dart';
import '../models/shipping_label_model.dart';
import '../services/tracking_service.dart';
import '../services/tracking_repository.dart';
import 'shipping_label_detail_screen.dart';

class TrackingDetailScreen extends StatefulWidget {
  final Tracking tracking;

  const TrackingDetailScreen({super.key, required this.tracking});

  @override
  State<TrackingDetailScreen> createState() => _TrackingDetailScreenState();
}

class _TrackingDetailScreenState extends State<TrackingDetailScreen> {
  final TrackingService _trackingService = TrackingService();
  Tracking? _tracking;
  ShippingLabel? _linkedLabel;

  @override
  void initState() {
    super.initState();
    _tracking = widget.tracking;
    _loadLinkedLabel();
  }

  Future<void> _loadLinkedLabel() async {
    if (_tracking?.labelId == null) return;
    final label = await ShippingLabelRepository().getById(_tracking!.labelId!);
    if (mounted) setState(() => _linkedLabel = label);
  }

  Future<void> _openTrackingUrl() async {
    final url = _trackingService.getTrackingUrl(_tracking!.carrier, _tracking!.trackingNumber);
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('URLを開けません: $url')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tracking = _tracking!;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('追跡詳細'),
        actions: [
          IconButton(
            icon: const Icon(Icons.open_in_browser),
            onPressed: _openTrackingUrl,
            tooltip: 'ブラウザで開く',
          ),
          IconButton(
            icon: const Icon(Icons.qr_code),
            onPressed: _showQrCode,
            tooltip: 'QRコード',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tracking.carrier.displayName,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      tracking.trackingNumber,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${tracking.direction.displayName} - ${tracking.status.displayName}',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 16),
                    LinearProgressIndicator(
                      value: tracking.status.progress / 100,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${tracking.status.progress}%',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '詳細情報',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    if (tracking.entityName != null) ...[
                      _buildInfoRow('紐付け先', tracking.entityName!),
                      const SizedBox(height: 8),
                    ],
                    if (tracking.shippedAt != null) ...[
                      _buildInfoRow('発送日', _formatDate(tracking.shippedAt!)),
                      const SizedBox(height: 8),
                    ],
                    if (tracking.deliveredAt != null) ...[
                      _buildInfoRow('配達日', _formatDate(tracking.deliveredAt!)),
                      const SizedBox(height: 8),
                    ],
                    if (tracking.trackingUpdatedAt != null) ...[
                      _buildInfoRow('最終更新', _formatDate(tracking.trackingUpdatedAt!)),
                      const SizedBox(height: 8),
                    ],
                    if (tracking.notes != null) ...[
                      _buildInfoRow('メモ', tracking.notes!),
                    ],
                    // 連携送り状リンク
                    if (_linkedLabel != null) ...[
                      const SizedBox(height: 8),
                      const Divider(),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.receipt, size: 16, color: Colors.grey),
                          const SizedBox(width: 8),
                          const Text('連携送り状:',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                          const Spacer(),
                          TextButton(
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ShippingLabelDetailScreen(label: _linkedLabel!),
                              ),
                            ),
                            child: Text('${_linkedLabel!.carrier.displayName} ${_linkedLabel!.labelType.displayName}'),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Expanded(
          child: Text(value),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')} '
           '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  void _showQrCode() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('QRコード'),
        content: SizedBox(
          width: 250,
          height: 250,
          child: _QrCodeWidget(trackingNumber: _tracking!.trackingNumber),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('閉じる'),
          ),
        ],
      ),
    );
  }
}

class _QrCodeWidget extends StatelessWidget {
  final String trackingNumber;

  const _QrCodeWidget({required this.trackingNumber});

  @override
  Widget build(BuildContext context) {
    return QrImageView(
      data: trackingNumber,
      version: QrVersions.auto,
      size: 250.0,
      backgroundColor: Colors.white,
    );
  }
}
