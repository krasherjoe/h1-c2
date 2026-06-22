import 'package:flutter/material.dart';
import '../models/tracking_model.dart';
import '../services/tracking_repository.dart';

class ShippingStatsScreen extends StatefulWidget {
  const ShippingStatsScreen({super.key});

  @override
  State<ShippingStatsScreen> createState() => _ShippingStatsScreenState();
}

class _ShippingStatsScreenState extends State<ShippingStatsScreen> {
  bool _isLoading = true;

  // 追跡統計
  int _totalTrackings = 0;
  int _deliveredCount = 0;
  int _inTransitCount = 0;
  int _notShippedCount = 0;
  int _failedCount = 0;
  Map<String, int> _byCarrier = {};

  // 送り状統計
  int _totalLabels = 0;
  Map<String, int> _labelsByCarrier = {};

  // 平均配達日数
  double? _avgDeliveryDays;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() => _isLoading = true);

    final trackingRepo = TrackingRepository();
    final labelRepo = ShippingLabelRepository();

    final trackings = await trackingRepo.getAll();
    final labels = await labelRepo.getAll();

    // 追跡集計
    int delivered = 0, inTransit = 0, notShipped = 0, failed = 0;
    final byCarrier = <String, int>{};
    final deliveryDays = <double>[];

    for (final t in trackings) {
      switch (t.status) {
        case TrackingStatus.delivered:
          delivered++;
          if (t.shippedAt != null && t.deliveredAt != null) {
            deliveryDays.add(t.deliveredAt!.difference(t.shippedAt!).inHours / 24.0);
          }
        case TrackingStatus.inTransit:
        case TrackingStatus.outForDelivery:
        case TrackingStatus.pickedUp:
          inTransit++;
        case TrackingStatus.notShipped:
          notShipped++;
        case TrackingStatus.failed:
        case TrackingStatus.returned:
          failed++;
      }
      byCarrier[t.carrier.displayName] = (byCarrier[t.carrier.displayName] ?? 0) + 1;
    }

    // 送り状集計
    final labelsByCarrier = <String, int>{};
    for (final l in labels) {
      labelsByCarrier[l.carrier.displayName] = (labelsByCarrier[l.carrier.displayName] ?? 0) + 1;
    }

    setState(() {
      _totalTrackings = trackings.length;
      _deliveredCount = delivered;
      _inTransitCount = inTransit;
      _notShippedCount = notShipped;
      _failedCount = failed;
      _byCarrier = byCarrier;
      _totalLabels = labels.length;
      _labelsByCarrier = labelsByCarrier;
      _avgDeliveryDays = deliveryDays.isEmpty
          ? null
          : deliveryDays.reduce((a, b) => a + b) / deliveryDays.length;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    return RefreshIndicator(
      onRefresh: _loadStats,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 追跡サマリー
          _buildSectionTitle(context, '追跡番号サマリー'),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildStatCard(context, '合計', '$_totalTrackings件', Icons.local_shipping, Colors.blue),
              const SizedBox(width: 8),
              _buildStatCard(context, '配達済み', '$_deliveredCount件', Icons.check_circle, Colors.green),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildStatCard(context, '輸送中', '$_inTransitCount件', Icons.directions_car, Colors.orange),
              const SizedBox(width: 8),
              _buildStatCard(context, '未発送', '$_notShippedCount件', Icons.inventory, Colors.grey),
            ],
          ),
          if (_failedCount > 0) ...[
            const SizedBox(height: 8),
            _buildStatCard(context, '配達失敗', '$_failedCount件', Icons.error, Colors.red, fullWidth: true),
          ],
          if (_totalTrackings > 0) ...[
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('配達完了率', style: Theme.of(context).textTheme.bodySmall),
                    const SizedBox(height: 4),
                    LinearProgressIndicator(
                      value: _deliveredCount / _totalTrackings,
                      backgroundColor: Colors.grey[200],
                      valueColor: const AlwaysStoppedAnimation(Colors.green),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${(_deliveredCount / _totalTrackings * 100).toStringAsFixed(1)}%  ($_deliveredCount / $_totalTrackings)',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
          ],
          if (_avgDeliveryDays != null) ...[
            const SizedBox(height: 8),
            _buildStatCard(
              context,
              '平均配達日数',
              '${_avgDeliveryDays!.toStringAsFixed(1)}日',
              Icons.schedule,
              Colors.purple,
              fullWidth: true,
            ),
          ],

          const SizedBox(height: 24),
          _buildSectionTitle(context, '宅配便会社別（追跡）'),
          const SizedBox(height: 8),
          ..._byCarrier.entries.map((e) => _buildCarrierRow(context, e.key, e.value, _totalTrackings)),

          const SizedBox(height: 24),
          // 送り状サマリー
          _buildSectionTitle(context, '送り状サマリー'),
          const SizedBox(height: 8),
          _buildStatCard(context, '合計', '$_totalLabels件', Icons.receipt, Colors.teal, fullWidth: true),
          const SizedBox(height: 8),
          ..._labelsByCarrier.entries.map((e) => _buildCarrierRow(context, e.key, e.value, _totalLabels)),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
    );
  }

  Widget _buildStatCard(
    BuildContext context,
    String label,
    String value,
    IconData icon,
    Color color, {
    bool fullWidth = false,
  }) {
    final card = Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Theme.of(context).textTheme.bodySmall),
                Text(value, style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
          ],
        ),
      ),
    );
    return fullWidth ? card : Expanded(child: card);
  }

  Widget _buildCarrierRow(BuildContext context, String carrier, int count, int total) {
    final ratio = total > 0 ? count / total : 0.0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(carrier),
                  Text('$count件 (${(ratio * 100).toStringAsFixed(0)}%)'),
                ],
              ),
              const SizedBox(height: 4),
              LinearProgressIndicator(
                value: ratio,
                backgroundColor: Colors.grey[200],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
