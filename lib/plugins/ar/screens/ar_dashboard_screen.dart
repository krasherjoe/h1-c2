import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../services/database_helper.dart';
import '../../../services/error_reporter.dart';
import 'payment_processing_screen.dart';
import '../../../constants/screen_ids.dart';

class _ArRow {
  final String id;
  final DateTime date;
  final String customerName;
  final int totalAmount;
  final int receivedAmount;
  final String? paymentStatus;
  final String? sourceDocumentId;
  _ArRow({
    required this.id,
    required this.date,
    required this.customerName,
    required this.totalAmount,
    required this.receivedAmount,
    this.paymentStatus,
    this.sourceDocumentId,
  });
  bool get isCreditNote => totalAmount < 0;
  int get remaining => isCreditNote ? totalAmount : (totalAmount - receivedAmount).clamp(0, totalAmount);
}

class ArDashboardScreen extends StatefulWidget {
  const ArDashboardScreen({super.key});
  @override
  State<ArDashboardScreen> createState() => _ArDashboardScreenState();
}

class _ArDashboardScreenState extends State<ArDashboardScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final NumberFormat _nf = NumberFormat('#,###');
  final DateFormat _df = DateFormat('yyyy/MM/dd');

  bool _loading = true;
  List<_ArRow> _unpaid = [];
  Map<String, int> _customerTotals = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final db = await _dbHelper.database;
      final rows = await db.rawQuery('''
        SELECT i.id, i.date, i.total_amount, i.received_amount,
               i.payment_status, i.source_document_id,
               COALESCE(c.display_name, i.customer_formal_name, '不明') AS customer_name
        FROM invoices i
        LEFT JOIN customers c ON c.id = i.customer_id AND c.is_current = 1
        WHERE i.is_current = 1 AND i.is_draft = 0
          AND i.document_type = 'invoice'
          AND (i.payment_status IS NULL OR i.payment_status != 'paid')
        ORDER BY i.date ASC
      ''');
      final list = rows.map((r) => _ArRow(
        id: r['id'] as String? ?? '',
        date: DateTime.tryParse(r['date'] as String? ?? '') ?? DateTime.now(),
        customerName: r['customer_name'] as String? ?? '不明',
        totalAmount: (r['total_amount'] as num?)?.toInt() ?? 0,
        receivedAmount: (r['received_amount'] as num?)?.toInt() ?? 0,
        paymentStatus: r['payment_status'] as String?,
        sourceDocumentId: r['source_document_id'] as String?,
      )).toList();
      final totals = <String, int>{};
      for (final r in list) {
        totals[r.customerName] = (totals[r.customerName] ?? 0) + r.remaining;
      }
      if (!mounted) return;
      setState(() {
        _unpaid = list;
        _customerTotals = totals;
        _loading = false;
      });
    } catch (e, s) {
      ErrorReporter.showError(context, message: 'AR: _load failed: $e', screenId: S.ar, stackTrace: s);
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('\${S.ar}:売掛金管理'),
        actions: [
          TextButton.icon(
            onPressed: () async {
              await Navigator.push(context, MaterialPageRoute(builder: (_) => const PaymentProcessingScreen()));
              if (!mounted) return;
              await _load();
            },
            icon: const Icon(Icons.add),
            label: const Text('入金登録'),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _unpaid.isEmpty
              ? const Center(child: Text('未回収の売掛金はありません'))
              : Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              children: [
                                Text('未回収サマリー（${_customerTotals.length}社）',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: cs.onSurface)),
                                const Spacer(),
                                Text('売掛合計 ￥${_nf.format(_customerTotals.values.fold(0, (a, b) => a + b))}',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: cs.error)),
                              ],
                            ),
                          ),
                          ..._customerTotals.entries.map((e) => Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Row(
                              children: [
                                Expanded(child: Text(e.key, style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant))),
                                Text('￥${_nf.format(e.value)}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: cs.error)),
                              ],
                            ),
                          )),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: _unpaid.length,
                        itemBuilder: (_, i) {
                          final inv = _unpaid[i];
                          final days = DateTime.now().difference(inv.date).inDays;
                          final aging = days <= 30 ? '30日以内' : days <= 60 ? '60日以内' : '60日超';
                          final agingColor = days <= 30 ? Colors.orange : days <= 60 ? Colors.deepOrange : cs.error;
                          return Card(
                            child: InkWell(
                              borderRadius: BorderRadius.circular(4),
                              onTap: () => _showInvoiceDetail(inv),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(child: Text(inv.customerName,
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14))),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: agingColor.withValues(alpha: 0.12),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(aging, style: TextStyle(
                                            fontSize: 9, fontWeight: FontWeight.bold, color: agingColor)),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Text(_df.format(inv.date), style: const TextStyle(fontSize: 11)),
                                        const SizedBox(width: 8),
                                        Text(inv.id.length > 8 ? inv.id.substring(0, 8) : inv.id,
                                            style: const TextStyle(fontSize: 11)),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Text('未回収: ￥${_nf.format(inv.remaining)}',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold, fontSize: 14, color: cs.error)),
                                        const Spacer(),
                                        Text('請求: ￥${_nf.format(inv.totalAmount)}',
                                            style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.push(context, MaterialPageRoute(builder: (_) => const PaymentProcessingScreen()));
          if (!mounted) return;
          await _load();
        },
        child: const Icon(Icons.payments),
      ),
    );
  }

  void _showInvoiceDetail(_ArRow inv) {
    final cs = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(inv.customerName),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('請求日: ${_df.format(inv.date)}'),
            const SizedBox(height: 4),
            Text('請求額: ￥${_nf.format(inv.totalAmount)}'),
            Text('入金額: ￥${_nf.format(inv.receivedAmount)}'),
            Text('未回収額: ￥${_nf.format(inv.remaining)}',
                style: TextStyle(fontWeight: FontWeight.bold, color: cs.error)),
            const SizedBox(height: 8),
            Text('ステータス: ${inv.paymentStatus ?? "未処理"}'),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('閉じる')),
        ],
      ),
    );
  }
}
