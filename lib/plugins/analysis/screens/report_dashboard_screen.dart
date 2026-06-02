import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../models/analysis_models.dart';
import '../services/analysis_repository.dart';

class ReportDashboardScreen extends StatefulWidget {
  const ReportDashboardScreen({super.key});
  @override
  State<ReportDashboardScreen> createState() => _ReportDashboardScreenState();
}

class _ReportDashboardScreenState extends State<ReportDashboardScreen> {
  final _repo = AnalysisRepository();
  final _nf = NumberFormat('#,###');

  bool _loading = true;
  List<MonthlySummary> _monthlyData = [];
  Map<String, int> _summary = {};
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      _monthlyData = await _repo.getMonthlySales(12);
      _summary = await _repo.getDashboardSummary();
      if (!mounted) return;
      setState(() => _loading = false);
    } catch (e) {
      debugPrint('[RD] _load error: $e');
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('RD:レポートダッシュボード')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildSummaryRow(cs),
                  const SizedBox(height: 16),
                  _buildMonthlyChart(cs),
                ],
              ),
            ),
    );
  }

  Widget _buildSummaryRow(ColorScheme cs) {
    final thisMonth = _summary['this_month'] ?? 0;
    final lastMonth = _summary['last_month'] ?? 0;
    final unpaid = _summary['unpaid'] ?? 0;
    final today = _summary['today'] ?? 0;

    final prevRatio = lastMonth > 0
        ? ((thisMonth - lastMonth) / lastMonth * 100).toStringAsFixed(1)
        : '-';

    return Row(
      children: [
        Expanded(child: _summaryCard(cs, '今月売上', '¥${_nf.format(thisMonth)}', cs.primary)),
        const SizedBox(width: 8),
        Expanded(child: _summaryCard(cs, '前月比', '$prevRatio%', cs.tertiary)),
        const SizedBox(width: 8),
        Expanded(child: _summaryCard(cs, '未回収', '¥${_nf.format(unpaid)}', cs.error)),
        const SizedBox(width: 8),
        Expanded(child: _summaryCard(cs, '本日売上', '¥${_nf.format(today)}', Colors.blue)),
      ],
    );
  }

  Widget _summaryCard(ColorScheme cs, String label, String value, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Text(label, style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthlyChart(ColorScheme cs) {
    if (_monthlyData.isEmpty) return const SizedBox();

    final maxVal = _monthlyData.fold<double>(
      0, (max, m) => m.salesAmount > max ? m.salesAmount.toDouble() : max,
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '月次売上推移',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 220,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: maxVal * 1.1,
                  barTouchData: BarTouchData(
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        final m = _monthlyData[group.x];
                        return BarTooltipItem(
                          '${m.month}月\n¥${_nf.format(m.salesAmount)}',
                          TextStyle(color: cs.onSurface, fontSize: 11),
                        );
                      },
                    ),
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final idx = value.toInt();
                          if (idx < 0 || idx >= _monthlyData.length) {
                            return const SizedBox();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              '${_monthlyData[idx].month}',
                              style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant),
                            ),
                          );
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 50,
                        getTitlesWidget: (value, meta) {
                          if (value == 0) return const SizedBox();
                          return Text(
                            '¥${_nf.format(value.toInt())}',
                            style: TextStyle(fontSize: 9, color: cs.onSurfaceVariant),
                          );
                        },
                      ),
                    ),
                    topTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: maxVal > 0 ? maxVal / 4 : 1,
                  ),
                  borderData: FlBorderData(show: false),
                  barGroups: _monthlyData.asMap().entries.map((e) {
                    final i = e.key;
                    final m = e.value;
                    return BarChartGroupData(x: i, barRods: [
                      BarChartRodData(
                        toY: m.salesAmount.toDouble(),
                        color: cs.primary,
                        width: 16,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(4),
                          topRight: Radius.circular(4),
                        ),
                      ),
                    ]);
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
