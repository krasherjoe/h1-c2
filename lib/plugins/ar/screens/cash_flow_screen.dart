import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../../services/database_helper.dart';
import '../models/ar_models.dart';
import '../services/payment_repository.dart';
import '../services/payment_schedule_repository.dart';

class CashFlowScreen extends StatefulWidget {
  const CashFlowScreen({super.key});

  @override
  State<CashFlowScreen> createState() => _CashFlowScreenState();
}

class _CashFlowScreenState extends State<CashFlowScreen> {
  final PaymentRepository _paymentRepo = PaymentRepository();
  final PaymentScheduleRepository _scheduleRepo = PaymentScheduleRepository();
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final NumberFormat _nf = NumberFormat('#,###');

  List<PaymentSchedule> _upcoming = [];
  List<PaymentSchedule> _overdue = [];
  Map<String, int> _monthlyPayments = {};
  Map<String, int> _monthlySchedules = {};
  Map<String, int> _methodTotals = {};
  int _totalScheduled = 0;
  int _totalOverdue = 0;
  int _totalBalance = 0;
  bool _isLoading = true;

  static const Map<String, Color> _methodChartColors = {
    'bankTransfer': Colors.blue,
    'cash': Colors.green,
    'creditCard': Colors.orange,
    'advancePayment': Colors.purple,
    'other': Colors.grey,
  };

  static const Map<String, String> _methodDisplayNames = {
    'bankTransfer': '銀行振込',
    'cash': '現金',
    'creditCard': 'クレジットカード',
    'advancePayment': '代表者立替',
    'other': 'その他',
  };

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final now = DateTime.now();
      _upcoming = await _scheduleRepo.getUpcomingSchedules(days: 30);
      _overdue = await _scheduleRepo.getOverdueSchedules();
      _monthlyPayments = await _paymentRepo.getMonthlyPaymentTotals(months: 6);
      _monthlySchedules = await _scheduleRepo.getMonthlyScheduleTotals(months: 9);

      final db = await _dbHelper.database;
      final methodRows = await db.rawQuery('''
        SELECT payment_method, SUM(amount) as total
        FROM payments
        GROUP BY payment_method
      ''');
      _methodTotals = {};
      for (final row in methodRows) {
        _methodTotals[row['payment_method'] as String? ?? 'other'] =
            row['total'] as int? ?? 0;
      }

      final balanceResult = await db.rawQuery(
        "SELECT COALESCE(SUM(amount), 0) as total FROM payment_schedules WHERE status != 'paid'",
      );
      _totalBalance = balanceResult.first['total'] as int? ?? 0;

      final thisMonthKey = DateFormat('yyyy-MM').format(now);
      _totalScheduled = _monthlySchedules[thisMonthKey] ?? 0;
      _totalOverdue = _overdue.fold<int>(0, (sum, s) => sum + s.amount);

      if (!mounted) return;
      setState(() => _isLoading = false);
    } catch (e) {
      debugPrint('[CF] _loadData error: $e');
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('CF:資金繰り'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSummaryCards(),
                  const SizedBox(height: 24),
                  _buildMonthlyChart(),
                  const SizedBox(height: 24),
                  _buildPaymentMethodChart(),
                  const SizedBox(height: 24),
                  _buildUpcomingPayments(),
                  const SizedBox(height: 24),
                  _buildOverdueList(),
                ],
              ),
            ),
    );
  }

  Widget _buildSummaryCards() {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        _summaryCard('今月支払予定', _totalScheduled, cs.primary),
        const SizedBox(width: 12),
        _summaryCard('延滞合計', _totalOverdue, cs.error),
        const SizedBox(width: 12),
        _summaryCard('残高', _totalBalance, cs.secondary),
      ],
    );
  }

  Widget _summaryCard(String label, int amount, Color color) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 11)),
              const SizedBox(height: 4),
              Text(
                '¥${_nf.format(amount)}',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMonthlyChart() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('月次支払推移', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            SizedBox(height: 220, child: _buildBarChart()),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _legendItem(Theme.of(context).colorScheme.primary, '支払実績'),
                const SizedBox(width: 16),
                _legendItem(Theme.of(context).colorScheme.secondary, '支払予定'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _legendItem(Color color, String label) {
    return Row(
      children: [
        Container(width: 12, height: 12, color: color),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  Widget _buildBarChart() {
    final now = DateTime.now();
    final months = <String>[];
    final paymentValues = <double>[];
    final scheduleValues = <double>[];

    for (int i = 5; i >= 0; i--) {
      final month = DateTime(now.year, now.month - i, 1);
      final key = DateFormat('yyyy-MM').format(month);
      months.add(DateFormat('M月').format(month));
      paymentValues.add((_monthlyPayments[key] ?? 0).toDouble());
      scheduleValues.add((_monthlySchedules[key] ?? 0).toDouble());
    }
    for (int i = 1; i <= 3; i++) {
      final month = DateTime(now.year, now.month + i, 1);
      final key = DateFormat('yyyy-MM').format(month);
      months.add(DateFormat('M月').format(month));
      paymentValues.add(0);
      scheduleValues.add((_monthlySchedules[key] ?? 0).toDouble());
    }

    final allValues = [...paymentValues, ...scheduleValues];
    final maxVal = allValues.reduce((a, b) => a > b ? a : b);
    final maxY = maxVal > 0 ? maxVal * 1.3 : 10000.0;

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxY,
        barTouchData: BarTouchData(enabled: false),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 22,
              getTitlesWidget: (value, meta) {
                final idx = value.toInt();
                if (idx < 0 || idx >= months.length) return const SizedBox();
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(months[idx], style: const TextStyle(fontSize: 9)),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: FlGridData(show: false),
        borderData: FlBorderData(show: false),
        barGroups: List.generate(months.length, (i) {
          return BarChartGroupData(
            x: i,
            barRods: [
              BarChartRodData(
                toY: paymentValues[i],
                color: Theme.of(context).colorScheme.primary,
                width: 8,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(2),
                  topRight: Radius.circular(2),
                ),
              ),
              BarChartRodData(
                toY: scheduleValues[i],
                color: Theme.of(context).colorScheme.secondary,
                width: 8,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(2),
                  topRight: Radius.circular(2),
                ),
              ),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildPaymentMethodChart() {
    final total = _methodTotals.values.fold<int>(0, (a, b) => a + b);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('支払方法別内訳', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            if (total == 0)
              const Text('データがありません')
            else ...[
              SizedBox(
                height: 150,
                child: PieChart(
                  PieChartData(
                    sectionsSpace: 2,
                    centerSpaceRadius: 40,
                    sections: _methodTotals.entries
                        .where((e) => e.value > 0)
                        .map((e) => PieChartSectionData(
                              value: e.value.toDouble(),
                              color: _methodChartColors[e.key] ?? Colors.grey,
                              radius: 50,
                              title:
                                  '${(e.value / total * 100).toStringAsFixed(0)}%',
                              titleStyle: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ))
                        .toList(),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              ..._methodTotals.entries.map((e) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      children: [
                        Icon(Icons.circle,
                            size: 12,
                            color: _methodChartColors[e.key] ?? Colors.grey),
                        const SizedBox(width: 8),
                        Text(_methodDisplayNames[e.key] ?? e.key,
                            style: const TextStyle(fontSize: 13)),
                        const Spacer(),
                        Text(
                          '¥${_nf.format(e.value)} (${(e.value / total * 100).toStringAsFixed(1)}%)',
                          style: const TextStyle(fontSize: 13),
                        ),
                      ],
                    ),
                  )),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildUpcomingPayments() {
    final cs = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('直近の支払予定（${_upcoming.length}件）',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            if (_upcoming.isEmpty)
              const Text('支払予定がありません')
            else
              ..._upcoming.map((s) => ListTile(
                    dense: true,
                    title: Text(s.displayTitle,
                        style: const TextStyle(fontSize: 14)),
                    subtitle: Text(s.displaySubtitle,
                        style: const TextStyle(fontSize: 12)),
                    trailing: Text(s.displayAmount,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    leading: CircleAvatar(
                      backgroundColor: s.getStatusColor(cs),
                      radius: 16,
                      child: const Icon(Icons.payment,
                          size: 16, color: Colors.white),
                    ),
                  )),
          ],
        ),
      ),
    );
  }

  Widget _buildOverdueList() {
    final cs = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '延滞一覧（${_overdue.length}件）',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: cs.error,
              ),
            ),
            const SizedBox(height: 12),
            if (_overdue.isEmpty)
              const Text('延滞はありません')
            else
              ..._overdue.map((s) => ListTile(
                    dense: true,
                    title: Text(s.displayTitle,
                        style: const TextStyle(fontSize: 14)),
                    subtitle: Text('${-s.daysUntilDue}日延滞',
                        style: const TextStyle(fontSize: 12)),
                    trailing: Text(s.displayAmount,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    leading: CircleAvatar(
                      backgroundColor: cs.errorContainer,
                      radius: 16,
                      child: Icon(Icons.warning,
                          size: 16, color: cs.onErrorContainer),
                    ),
                  )),
          ],
        ),
      ),
    );
  }
}
