import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../services/database_helper.dart';

class TaxReportScreen extends StatefulWidget {
  const TaxReportScreen({super.key});
  @override
  State<TaxReportScreen> createState() => _TaxReportScreenState();
}

class _TaxReportScreenState extends State<TaxReportScreen> {
  final _nf = NumberFormat('#,###');
  final _dbHelper = DatabaseHelper();

  int _startYear = DateTime.now().year;
  int _startMonth = 1;
  int _endYear = DateTime.now().year;
  int _endMonth = DateTime.now().month;

  bool _loading = false;
  int _totalSales = 0;
  int _totalTaxCollected = 0;
  int _totalPurchases = 0;
  int _totalTaxPaid = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  String get _startStr => '$_startYear-${_startMonth.toString().padLeft(2, '0')}-01';
  String get _endStr {
    if (_endMonth == 12) return '${_endYear + 1}-01-01';
    return '$_endYear-${(_endMonth + 1).toString().padLeft(2, '0')}-01';
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final db = await _dbHelper.database;

      final salesRow = await db.rawQuery('''
        SELECT COALESCE(SUM(total), 0) as total, COALESCE(SUM(total * tax_rate), 0) as tax
        FROM documents
        WHERE status = 'confirmed'
          AND document_type IN ('invoice', 'receipt')
          AND date >= ? AND date < ?
      ''', [_startStr, _endStr]);

      final purchaseRow = await db.rawQuery('''
        SELECT COALESCE(SUM(total), 0) as total, COALESCE(SUM(total * 0.1), 0) as tax
        FROM purchases
        WHERE status NOT IN ('draft', 'cancelled')
          AND date >= ? AND date < ?
      ''', [_startStr, _endStr]);

      final invTaxRow = await db.rawQuery('''
        SELECT COALESCE(SUM(total_amount * COALESCE(tax_rate, 0.1)), 0) as tax
        FROM invoices
        WHERE is_current = 1 AND is_draft = 0 AND document_type = 'invoice'
          AND date >= ? AND date < ?
      ''', [_startStr, _endStr]);

      if (!mounted) return;
      setState(() {
        _totalSales = (salesRow.first['total'] as num?)?.toInt() ?? 0;
        _totalTaxCollected = (invTaxRow.first['tax'] as num?)?.toInt() ?? 0;
        _totalPurchases = (purchaseRow.first['total'] as num?)?.toInt() ?? 0;
        _totalTaxPaid = (purchaseRow.first['tax'] as num?)?.toInt() ?? 0;
        _loading = false;
      });
    } catch (e) {
      debugPrint('[TX] _load error: $e');
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final netTax = _totalTaxCollected - _totalTaxPaid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('TX:税務レポート'),
      ),
      body: Column(
        children: [
          _buildPeriodPicker(cs),
          if (_loading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _buildSummaryCard(cs, '売上高', '¥${_nf.format(_totalSales)}', Icons.trending_up, cs.primary),
                    const SizedBox(height: 8),
                    _buildSummaryCard(cs, '消費税（売上）', '¥${_nf.format(_totalTaxCollected)}', Icons.receipt_long, cs.secondary),
                    const SizedBox(height: 8),
                    _buildSummaryCard(cs, '仕入高', '¥${_nf.format(_totalPurchases)}', Icons.shopping_cart, cs.primary),
                    const SizedBox(height: 8),
                    _buildSummaryCard(cs, '消費税（仕入）', '¥${_nf.format(_totalTaxPaid)}', Icons.receipt, cs.tertiary),
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: cs.primaryContainer.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: cs.primary.withValues(alpha: 0.3)),
                      ),
                      child: Column(
                        children: [
                          Text('納付税額', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                          const SizedBox(height: 4),
                          Text('¥${_nf.format(netTax)}',
                              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: netTax >= 0 ? cs.error : cs.tertiary)),
                          Text(netTax >= 0 ? '納付が必要です' : '還付があります',
                              style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPeriodPicker(ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.all(12),
      color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
      child: Column(
        children: [
          Row(
            children: [
              const Text('開始: ', style: TextStyle(fontSize: 13)),
              _yearMonthPicker(_startYear, _startMonth, (y, m) {
                _startYear = y; _startMonth = m; _load();
              }),
              const SizedBox(width: 16),
              const Text('終了: ', style: TextStyle(fontSize: 13)),
              _yearMonthPicker(_endYear, _endMonth, (y, m) {
                _endYear = y; _endMonth = m; _load();
              }),
            ],
          ),
        ],
      ),
    );
  }

  Widget _yearMonthPicker(int year, int month, Function(int, int) onChanged) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 70,
          child: TextFormField(
            initialValue: year.toString(),
            style: const TextStyle(fontSize: 13),
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
            ),
            onFieldSubmitted: (v) {
              final y = int.tryParse(v) ?? year;
              onChanged(y, month);
            },
          ),
        ),
        const Text('年', style: TextStyle(fontSize: 13)),
        const SizedBox(width: 4),
        SizedBox(
          width: 55,
          child: TextFormField(
            initialValue: month.toString(),
            style: const TextStyle(fontSize: 13),
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
            ),
            onFieldSubmitted: (v) {
              var m = int.tryParse(v) ?? month;
              m = m.clamp(1, 12);
              onChanged(year, m);
            },
          ),
        ),
        const Text('月', style: TextStyle(fontSize: 13)),
      ],
    );
  }

  Widget _buildSummaryCard(ColorScheme cs, String title, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 42, height: 42,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                  const SizedBox(height: 2),
                  Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: cs.onSurface)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
