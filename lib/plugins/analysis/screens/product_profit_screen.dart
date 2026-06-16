import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/analysis_models.dart';
import '../services/analysis_repository.dart';
import '../../../constants/screen_ids.dart';

class ProductProfitScreen extends StatefulWidget {
  const ProductProfitScreen({super.key});
  @override
  State<ProductProfitScreen> createState() => _ProductProfitScreenState();
}

class _ProductProfitScreenState extends State<ProductProfitScreen> {
  final _repo = AnalysisRepository();
  final _nf = NumberFormat('#,###');

  List<ProductProfit> _data = [];
  bool _isLoading = true;
  int _days = 30;
  String _sortColumn = 'sales';
  bool _sortAsc = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final to = DateTime.now();
      final from = to.subtract(Duration(days: _days));
      final data = await _repo.getProductProfits(from, to);
      if (!mounted) return;
      setState(() {
        _data = data;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('[PA] _loadData error: $e');
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  void _sort(String column) {
    setState(() {
      if (_sortColumn == column) {
        _sortAsc = !_sortAsc;
      } else {
        _sortColumn = column;
        _sortAsc = false;
      }
      _data.sort((a, b) {
        int cmp;
        switch (column) {
          case 'name':
            cmp = a.productName.compareTo(b.productName);
          case 'quantity':
            cmp = a.quantity.compareTo(b.quantity);
          case 'sales':
            cmp = a.salesAmount.compareTo(b.salesAmount);
          case 'cost':
            cmp = a.costAmount.compareTo(b.costAmount);
          case 'profit':
            cmp = a.profitAmount.compareTo(b.profitAmount);
          case 'rate':
            cmp = a.profitRate.compareTo(b.profitRate);
          default:
            cmp = 0;
        }
        return _sortAsc ? cmp : -cmp;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final totalSales = _data.fold(0, (s, e) => s + e.salesAmount);
    final totalCost = _data.fold(0, (s, e) => s + e.costAmount);
    final totalProfit = _data.fold(0, (s, e) => s + e.profitAmount);
    final avgRate = totalSales > 0
        ? (totalProfit / totalSales * 100).toStringAsFixed(1)
        : '0.0';

    return Scaffold(
      appBar: AppBar(
        title: const Text('\${S.pa}:商品別粗利分析'),
        actions: [
          PopupMenuButton<int>(
            icon: const Icon(Icons.date_range),
            onSelected: (value) {
              _days = value;
              _loadData();
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 7, child: Text('過去1週間')),
              const PopupMenuItem(value: 30, child: Text('過去1ヶ月')),
              const PopupMenuItem(value: 90, child: Text('過去3ヶ月')),
              const PopupMenuItem(value: 365, child: Text('過去1年')),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _data.isEmpty
              ? const Center(child: Text('該当期間の売上データがありません'))
              : Column(
                  children: [
                    _buildSummary(cs, totalSales, totalCost, totalProfit, avgRate),
                    Expanded(child: _buildTable(cs)),
                  ],
                ),
    );
  }

  Widget _buildSummary(
    ColorScheme cs,
    int totalSales,
    int totalCost,
    int totalProfit,
    String avgRate,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      color: cs.primaryContainer.withValues(alpha: 0.4),
      child: Row(
        children: [
          _summaryItem(cs, '売上', '¥${_nf.format(totalSales)}'),
          _summaryItem(cs, '原価', '¥${_nf.format(totalCost)}'),
          _summaryItem(cs, '粗利', '¥${_nf.format(totalProfit)}'),
          _summaryItem(cs, '粗利率', '$avgRate%'),
        ],
      ),
    );
  }

  Widget _summaryItem(ColorScheme cs, String label, String value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildTable(ColorScheme cs) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        child: DataTable(
          sortColumnIndex: _sortColumnIndex,
          sortAscending: _sortAsc,
          columns: [
            DataColumn(
              label: const Text('商品名'),
              onSort: (col, asc) => _sort('name'),
            ),
            DataColumn(
              label: const Text('数量'),
              numeric: true,
              onSort: (col, asc) => _sort('quantity'),
            ),
            DataColumn(
              label: const Text('売上'),
              numeric: true,
              onSort: (col, asc) => _sort('sales'),
            ),
            DataColumn(
              label: const Text('原価'),
              numeric: true,
              onSort: (col, asc) => _sort('cost'),
            ),
            DataColumn(
              label: const Text('粗利'),
              numeric: true,
              onSort: (col, asc) => _sort('profit'),
            ),
            DataColumn(
              label: const Text('粗利率'),
              numeric: true,
              onSort: (col, asc) => _sort('rate'),
            ),
          ],
          rows: _data.map((e) => DataRow(cells: [
            DataCell(Text(e.productName, style: const TextStyle(fontSize: 13))),
            DataCell(Text('${e.quantity}')),
            DataCell(Text('¥${_nf.format(e.salesAmount)}')),
            DataCell(Text('¥${_nf.format(e.costAmount)}')),
            DataCell(Text(
              '¥${_nf.format(e.profitAmount)}',
              style: TextStyle(
                color: e.profitAmount >= 0 ? null : cs.error,
              ),
            )),
            DataCell(Text(
              '${e.profitRate.toStringAsFixed(1)}%',
              style: TextStyle(
                color: e.profitRate >= 0 ? null : cs.error,
              ),
            )),
          ])).toList(),
        ),
      ),
    );
  }

  int? get _sortColumnIndex {
    switch (_sortColumn) {
      case 'name':
        return 0;
      case 'quantity':
        return 1;
      case 'sales':
        return 2;
      case 'cost':
        return 3;
      case 'profit':
        return 4;
      case 'rate':
        return 5;
      default:
        return 2;
    }
  }
}
