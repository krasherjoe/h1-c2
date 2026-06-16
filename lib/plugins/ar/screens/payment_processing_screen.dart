import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../services/database_helper.dart';
import '../../../services/error_reporter.dart';
import '../models/ar_models.dart';
import '../../../constants/screen_ids.dart';

class PaymentProcessingScreen extends StatefulWidget {
  const PaymentProcessingScreen({super.key});
  @override
  State<PaymentProcessingScreen> createState() => _PaymentProcessingScreenState();
}

class _PaymentProcessingScreenState extends State<PaymentProcessingScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final NumberFormat _nf = NumberFormat('#,###');
  final DateFormat _df = DateFormat('yyyy/MM/dd');

  List<Map<String, dynamic>> _invoices = [];
  bool _loading = true;

  Map<String, dynamic>? _selected;
  final _amountCtrl = TextEditingController();
  DateTime _paymentDate = DateTime.now();
  String _paymentMethod = '振込';
  bool _saving = false;

  static const _methods = ['現金', '振込', 'クレジットカード', '手形', 'その他'];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final db = await _dbHelper.database;
      final rows = await db.rawQuery('''
        SELECT i.id, i.date, i.total_amount, i.received_amount,
               i.payment_status, i.invoice_number,
               COALESCE(c.display_name, i.customer_formal_name, '不明') AS customer_name
        FROM invoices i
        LEFT JOIN customers c ON c.id = i.customer_id AND c.is_current = 1
        WHERE i.is_current = 1 AND i.is_draft = 0
          AND i.document_type = 'invoice'
          AND (i.payment_status IS NULL OR i.payment_status != 'paid')
          AND i.total_amount > 0
        ORDER BY i.date DESC
      ''');
      if (!mounted) return;
      setState(() {
        _invoices = rows;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ErrorReporter.showError(context, message: 'RP: 読込失敗: $e', screenId: S.rp);
    }
  }

  void _select(Map<String, dynamic> inv) {
    final received = (inv['received_amount'] as num?)?.toInt() ?? 0;
    final total = (inv['total_amount'] as num?)?.toInt() ?? 0;
    setState(() {
      _selected = inv;
      _amountCtrl.text = (total - received).toString();
    });
  }

  int get _remainingAmount {
    if (_selected == null) return 0;
    final total = (_selected!['total_amount'] as num?)?.toInt() ?? 0;
    final received = (_selected!['received_amount'] as num?)?.toInt() ?? 0;
    return total - received;
  }

  Future<void> _register() async {
    if (_selected == null) return;
    final amount = int.tryParse(_amountCtrl.text.replaceAll(RegExp(r'[,\s]'), ''));
    if (amount == null || amount <= 0) return;

    setState(() => _saving = true);
    try {
      final db = await _dbHelper.database;
      final inv = _selected!;
      final invId = inv['id'] as String;
      final currentReceived = (inv['received_amount'] as num?)?.toInt() ?? 0;
      final newReceived = currentReceived + amount;
      final total = (inv['total_amount'] as num?)?.toInt() ?? 0;
      final newStatus = newReceived >= total ? 'paid' : 'partial';

      await db.update(
        'invoices',
        {
          'received_amount': newReceived,
          'payment_status': newStatus,
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [invId],
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${inv['customer_name']} から ${_nf.format(amount)} の入金を登録しました')),
      );
      setState(() { _selected = null; _amountCtrl.clear(); });
      await _load();
    } catch (e) {
      if (!mounted) return;
      ErrorReporter.showError(context, message: 'RP: 登録失敗: $e', screenId: S.rp);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('\${S.rp}:入金処理')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _invoices.isEmpty
              ? const Center(child: Text('未入金の請求書はありません'))
              : Column(
                  children: [
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: _invoices.length,
                        itemBuilder: (_, i) {
                          final inv = _invoices[i];
                          final selected = _selected?['id'] == inv['id'];
                          final total = (inv['total_amount'] as num?)?.toInt() ?? 0;
                          final received = (inv['received_amount'] as num?)?.toInt() ?? 0;
                          final remaining = total - received;
                          final isPartial = received > 0 && remaining > 0;
                          final statusColor = isPartial ? Colors.orange : cs.error;
                          return Card(
                            color: selected ? cs.primaryContainer.withValues(alpha: 0.3) : null,
                            child: InkWell(
                              onTap: () => _select(inv),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(inv['customer_name'] as String? ?? '',
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                          const SizedBox(height: 4),
                                          Text('${_df.format(DateTime.tryParse(inv['date'] as String? ?? '') ?? DateTime.now())} ${inv['invoice_number'] ?? ''}',
                                              style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
                                          Text('残高: ${_nf.format(remaining)} / ${_nf.format(total)}',
                                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: statusColor)),
                                        ],
                                      ),
                                    ),
                                    Text(isPartial ? '一部入金' : '未入金', style: TextStyle(fontSize: 11, color: statusColor)),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    if (_selected != null) _buildPaymentForm(cs),
                  ],
                ),
    );
  }

  Widget _buildPaymentForm(ColorScheme cs) {
    final bottomPad = MediaQuery.of(context).padding.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottomPad),
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(top: BorderSide(color: cs.outlineVariant)),
        boxShadow: [BoxShadow(color: cs.shadow.withValues(alpha: 0.08), blurRadius: 8, offset: const Offset(0, -2))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('入金登録: ${_selected!['customer_name']}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _amountCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: '入金額', isDense: true, border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12)))),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _paymentDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) setState(() => _paymentDate = picked);
                  },
                  icon: const Icon(Icons.calendar_today, size: 16),
                  label: Text(_df.format(_paymentDate), style: const TextStyle(fontSize: 11)),
                ),
              ),
              const SizedBox(width: 8),
              DropdownButton<String>(
                value: _paymentMethod,
                underline: const SizedBox(),
                onChanged: (v) => setState(() => _paymentMethod = v!),
                items: _methods.map((m) => DropdownMenuItem(value: m, child: Text(m, style: const TextStyle(fontSize: 12)))).toList(),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _saving ? null : _register,
              icon: _saving
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.check_circle),
              label: Text(_saving ? '登録中...' : '入金登録する'),
            ),
          ),
        ],
      ),
    );
  }
}
