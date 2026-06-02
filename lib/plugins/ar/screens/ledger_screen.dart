import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../../services/database_helper.dart';

class LedgerScreen extends StatefulWidget {
  const LedgerScreen({super.key});
  @override
  State<LedgerScreen> createState() => _LedgerScreenState();
}

class _LedgerScreenState extends State<LedgerScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _dbHelper = DatabaseHelper();
  final _nf = NumberFormat('#,###');
  final _df = DateFormat('yyyy/MM/dd');

  bool _arLoading = true;
  bool _apLoading = true;
  List<_ArSummaryRow> _arRows = [];
  List<_ApSummaryRow> _apRows = [];
  int _arTotal = 0;
  int _apTotal = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadAr();
    _loadAp();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAr() async {
    setState(() => _arLoading = true);
    try {
      final db = await _dbHelper.database;
      final rows = await db.rawQuery('''
        SELECT COALESCE(c.display_name, i.customer_formal_name, '不明') as customer_name,
               SUM(i.total_amount) as total_amount,
               SUM(CASE WHEN i.payment_status = 'paid' THEN i.total_amount ELSE 0 END) as paid_amount,
               MAX(i.date) as last_date,
               COUNT(*) as count,
               SUM(CASE WHEN julianday('now') - julianday(i.date) <= 30 THEN i.total_amount - i.received_amount ELSE 0 END) as aging_30,
               SUM(CASE WHEN julianday('now') - julianday(i.date) > 30 AND julianday('now') - julianday(i.date) <= 60 THEN i.total_amount - i.received_amount ELSE 0 END) as aging_60,
               SUM(CASE WHEN julianday('now') - julianday(i.date) > 60 THEN i.total_amount - i.received_amount ELSE 0 END) as aging_90
        FROM invoices i
        LEFT JOIN customers c ON c.id = i.customer_id AND c.is_current = 1
        WHERE i.is_current = 1 AND i.is_draft = 0 AND i.document_type = 'invoice'
          AND (i.payment_status IS NULL OR i.payment_status != 'paid')
        GROUP BY COALESCE(c.display_name, i.customer_formal_name, '不明')
        ORDER BY total_amount DESC
      ''');
      final list = rows.map((r) => _ArSummaryRow(
        customerName: r['customer_name'] as String? ?? '不明',
        totalAmount: (r['total_amount'] as num?)?.toInt() ?? 0,
        paidAmount: (r['paid_amount'] as num?)?.toInt() ?? 0,
        lastDate: r['last_date'] as String? ?? '',
        count: (r['count'] as num?)?.toInt() ?? 0,
        aging30: (r['aging_30'] as num?)?.toInt() ?? 0,
        aging60: (r['aging_60'] as num?)?.toInt() ?? 0,
        aging90: (r['aging_90'] as num?)?.toInt() ?? 0,
      )).toList();
      final total = list.fold(0, (s, r) => s + (r.totalAmount - r.paidAmount));
      if (!mounted) return;
      setState(() { _arRows = list; _arTotal = total; _arLoading = false; });
    } catch (e) {
      debugPrint('[LR:AR] _loadAr error: $e');
      if (!mounted) return;
      setState(() => _arLoading = false);
    }
  }

  Future<void> _loadAp() async {
    setState(() => _apLoading = true);
    try {
      final db = await _dbHelper.database;
      final rows = await db.rawQuery('''
        SELECT COALESCE(s.display_name, '') as supplier_name,
               SUM(p.total) as total_amount,
               SUM(CASE WHEN p.payment_status = 'paid' THEN p.total ELSE 0 END) as paid_amount,
               MAX(p.date) as last_date,
               COUNT(*) as count,
               SUM(CASE WHEN julianday('now') - julianday(p.date) <= 30 THEN p.total ELSE 0 END) as aging_30,
               SUM(CASE WHEN julianday('now') - julianday(p.date) > 30 AND julianday('now') - julianday(p.date) <= 60 THEN p.total ELSE 0 END) as aging_60,
               SUM(CASE WHEN julianday('now') - julianday(p.date) > 60 THEN p.total ELSE 0 END) as aging_90
        FROM purchases p
        LEFT JOIN suppliers s ON p.supplier_id = s.id
        WHERE p.status NOT IN ('draft', 'cancelled')
        GROUP BY COALESCE(s.display_name, '')
        ORDER BY total_amount DESC
      ''');
      final list = rows.map((r) => _ApSummaryRow(
        supplierName: r['supplier_name'] as String? ?? '',
        totalAmount: (r['total_amount'] as num?)?.toInt() ?? 0,
        paidAmount: (r['paid_amount'] as num?)?.toInt() ?? 0,
        lastDate: r['last_date'] as String? ?? '',
        count: (r['count'] as num?)?.toInt() ?? 0,
        aging30: (r['aging_30'] as num?)?.toInt() ?? 0,
        aging60: (r['aging_60'] as num?)?.toInt() ?? 0,
        aging90: (r['aging_90'] as num?)?.toInt() ?? 0,
      )).toList();
      final total = list.fold(0, (s, r) => s + (r.totalAmount - r.paidAmount));
      if (!mounted) return;
      setState(() { _apRows = list; _apTotal = total; _apLoading = false; });
    } catch (e) {
      debugPrint('[LR:AP] _loadAp error: $e');
      if (!mounted) return;
      setState(() => _apLoading = false);
    }
  }

  Future<void> _exportPdfAr() async {
    final pdf = pw.Document();
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(20),
        header: (ctx) => pw.Text('売掛台帳', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
        footer: (ctx) => pw.Text('${_df.format(DateTime.now())}  ページ ${ctx.pageNumber}', style: const pw.TextStyle(fontSize: 8)),
        build: (ctx) => [
          pw.SizedBox(height: 8),
          pw.Table.fromTextArray(
            headers: ['得意先', '件数', '請求額', '未回収額', '30日以内', '31-60日', '60日超'],
            data: _arRows.map((r) => [
              r.customerName, '${r.count}',
              '¥${_nf.format(r.totalAmount)}', '¥${_nf.format(r.totalAmount - r.paidAmount)}',
              '¥${_nf.format(r.aging30)}', '¥${_nf.format(r.aging60)}', '¥${_nf.format(r.aging90)}',
            ]).toList(),
            border: pw.TableBorder.all(width: 0.5),
            headerStyle: const pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8),
            cellStyle: const pw.TextStyle(fontSize: 7),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
          ),
          pw.SizedBox(height: 8),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.end,
            children: [pw.Text('未回収残高: ¥${_nf.format(_arTotal)}', style: const pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12))],
          ),
        ],
      ),
    );
    await Printing.sharePdf(bytes: await pdf.save(), filename: '売掛台帳.pdf');
  }

  Future<void> _exportPdfAp() async {
    final pdf = pw.Document();
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(20),
        header: (ctx) => pw.Text('買掛台帳', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
        footer: (ctx) => pw.Text('${_df.format(DateTime.now())}  ページ ${ctx.pageNumber}', style: const pw.TextStyle(fontSize: 8)),
        build: (ctx) => [
          pw.SizedBox(height: 8),
          pw.Table.fromTextArray(
            headers: ['仕入先', '件数', '仕入額', '未払額'],
            data: _apRows.map((r) => [
              r.supplierName, '${r.count}',
              '¥${_nf.format(r.totalAmount)}', '¥${_nf.format(r.totalAmount - r.paidAmount)}',
            ]).toList(),
            border: pw.TableBorder.all(width: 0.5),
            headerStyle: const pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8),
            cellStyle: const pw.TextStyle(fontSize: 7),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
          ),
          pw.SizedBox(height: 8),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.end,
            children: [pw.Text('未払残高: ¥${_nf.format(_apTotal)}', style: const pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12))],
          ),
        ],
      ),
    );
    await Printing.sharePdf(bytes: await pdf.save(), filename: '買掛台帳.pdf');
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('LR:台帳'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '売掛台帳'),
            Tab(text: '買掛台帳'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildArTab(cs),
          _buildApTab(cs),
        ],
      ),
    );
  }

  Widget _buildArTab(ColorScheme cs) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          color: cs.errorContainer.withValues(alpha: 0.2),
          child: Row(
            children: [
              Expanded(
                child: Text('未回収残高: ¥${_nf.format(_arTotal)}',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: cs.error)),
              ),
              IconButton(
                icon: const Icon(Icons.picture_as_pdf),
                tooltip: 'PDF出力',
                onPressed: _arRows.isEmpty ? null : _exportPdfAr,
              ),
            ],
          ),
        ),
        Expanded(
          child: _arLoading
              ? const Center(child: CircularProgressIndicator())
              : _arRows.isEmpty
                  ? const Center(child: Text('売掛金はありません'))
                  : ListView.builder(
                      padding: const EdgeInsets.all(8),
                      itemCount: _arRows.length,
                      itemBuilder: (_, i) {
                        final r = _arRows[i];
                        final balance = r.totalAmount - r.paidAmount;
                        return Card(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(child: Text(r.customerName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14))),
                                    Text('¥${_nf.format(balance)}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: cs.error)),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text('${r.count}件 / 最終: ${r.lastDate.isNotEmpty ? _df.format(DateTime.parse(r.lastDate)) : "-"}',
                                    style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    _agingBadge('~30日', r.aging30, Colors.orange, cs),
                                    const SizedBox(width: 4),
                                    _agingBadge('31~60日', r.aging60, Colors.deepOrange, cs),
                                    const SizedBox(width: 4),
                                    _agingBadge('60日~', r.aging90, cs.error, cs),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildApTab(ColorScheme cs) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          color: cs.errorContainer.withValues(alpha: 0.2),
          child: Row(
            children: [
              Expanded(
                child: Text('未払残高: ¥${_nf.format(_apTotal)}',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: cs.error)),
              ),
              IconButton(
                icon: const Icon(Icons.picture_as_pdf),
                tooltip: 'PDF出力',
                onPressed: _apRows.isEmpty ? null : _exportPdfAp,
              ),
            ],
          ),
        ),
        Expanded(
          child: _apLoading
              ? const Center(child: CircularProgressIndicator())
              : _apRows.isEmpty
                  ? const Center(child: Text('買掛金はありません'))
                  : ListView.builder(
                      padding: const EdgeInsets.all(8),
                      itemCount: _apRows.length,
                      itemBuilder: (_, i) {
                        final r = _apRows[i];
                        final balance = r.totalAmount - r.paidAmount;
                        return Card(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(child: Text(r.supplierName.isNotEmpty ? r.supplierName : '(名称未設定)',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14))),
                                    Text('¥${_nf.format(balance)}',
                                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: cs.error)),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text('${r.count}件 / 最終: ${r.lastDate.isNotEmpty ? _df.format(DateTime.parse(r.lastDate)) : "-"}',
                                    style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  Widget _agingBadge(String label, int amount, Color color, ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text('$label ¥${_nf.format(amount)}',
          style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: color)),
    );
  }
}

class _ArSummaryRow {
  final String customerName;
  final int totalAmount;
  final int paidAmount;
  final String lastDate;
  final int count;
  final int aging30;
  final int aging60;
  final int aging90;
  const _ArSummaryRow({
    required this.customerName, required this.totalAmount, required this.paidAmount,
    required this.lastDate, required this.count,
    required this.aging30, required this.aging60, required this.aging90,
  });
}

class _ApSummaryRow {
  final String supplierName;
  final int totalAmount;
  final int paidAmount;
  final String lastDate;
  final int count;
  final int aging30;
  final int aging60;
  final int aging90;
  const _ApSummaryRow({
    required this.supplierName, required this.totalAmount, required this.paidAmount,
    required this.lastDate, required this.count,
    required this.aging30, required this.aging60, required this.aging90,
  });
}
