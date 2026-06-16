import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/account.dart';
import '../models/journal_entry.dart';

class ExportService {
  String formatMoney(int v) => '¥${v.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}';

  Future<void> exportTrialBalance({
    required List<Account> accounts,
    required List<JournalEntry> entries,
    required int totalDebit,
    required int totalCredit,
    required String dateLabel,
  }) async {
    final pdf = pw.Document();
    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(20),
      header: (ctx) => pw.Text('合計残高試算表', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
      footer: (ctx) => pw.Text('$dateLabel  ページ ${ctx.pageNumber}', style: pw.TextStyle(fontSize: 8)),
      build: (ctx) => [
        pw.SizedBox(height: 8),
        pw.Table.fromTextArray(
          headers: ['コード', '科目名', '区分', '借方合計', '貸方合計'],
          data: accounts.map((a) {
            final d = entries.where((e) => e.debitAccountId == a.id).fold(0, (s, e) => s + e.amount);
            final c = entries.where((e) => e.creditAccountId == a.id).fold(0, (s, e) => s + e.amount);
            if (d == 0 && c == 0) return null;
            return [a.code, a.name, a.category, d > 0 ? formatMoney(d) : '', c > 0 ? formatMoney(c) : ''];
          }).whereType<List<String>>().toList(),
          border: pw.TableBorder.all(width: 0.5),
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8),
          cellStyle: pw.TextStyle(fontSize: 7),
          headerDecoration: pw.BoxDecoration(color: PdfColors.grey200),
        ),
        pw.SizedBox(height: 8),
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.end, children: [
          pw.Text('借方合計: ${formatMoney(totalDebit)}  貸方合計: ${formatMoney(totalCredit)}',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
        ]),
        if (totalDebit != totalCredit)
          pw.Text('※ 借方合計と貸方合計が一致しません', style: pw.TextStyle(color: PdfColors.red, fontSize: 10)),
      ],
    ));
    await Printing.sharePdf(bytes: await pdf.save(), filename: '試算表.pdf');
  }

  Future<void> exportFinancialStatements({
    required List<Account> accounts,
    required List<JournalEntry> entries,
    required String dateLabel,
  }) async {
    final pdf = pw.Document();
    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(20),
      header: (ctx) => pw.Text('決算書', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
      footer: (ctx) => pw.Text('$dateLabel  ページ ${ctx.pageNumber}', style: pw.TextStyle(fontSize: 8)),
      build: (ctx) => [
        pw.Text('貸借対照表', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 8),
        pw.Text('資産の部', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
        ..._bsLines(accounts, entries, 'asset'),
        pw.SizedBox(height: 8),
        pw.Text('負債の部', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
        ..._bsLines(accounts, entries, 'liability'),
        pw.SizedBox(height: 8),
        pw.Text('純資産の部', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
        ..._bsLines(accounts, entries, 'equity'),
        pw.SizedBox(height: 16),
        pw.Divider(),
        pw.Text('損益計算書', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 8),
        pw.Text('収益', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
        ..._plLines(accounts, entries, 'revenue'),
        pw.SizedBox(height: 8),
        pw.Text('費用', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
        ..._plLines(accounts, entries, 'expense'),
      ],
    ));
    await Printing.sharePdf(bytes: await pdf.save(), filename: '決算書.pdf');
  }

  List<pw.Widget> _bsLines(List<Account> accounts, List<JournalEntry> entries, String cat) {
    final items = accounts.where((a) => a.category == cat && _balance(a.id!, entries) != 0).toList();
    return items.map((a) => pw.Padding(
      padding: pw.EdgeInsets.only(left: 8, top: 2),
      child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
        pw.Text(a.name, style: pw.TextStyle(fontSize: 9)),
        pw.Text(formatMoney(_balance(a.id!, entries).abs()), style: pw.TextStyle(fontSize: 9)),
      ]),
    )).toList();
  }

  List<pw.Widget> _plLines(List<Account> accounts, List<JournalEntry> entries, String cat) {
    final items = accounts.where((a) => a.category == cat && _balance(a.id!, entries) != 0).toList();
    return items.map((a) => pw.Padding(
      padding: pw.EdgeInsets.only(left: 8, top: 2),
      child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
        pw.Text(a.name, style: pw.TextStyle(fontSize: 9)),
        pw.Text(formatMoney(_balance(a.id!, entries).abs()), style: pw.TextStyle(fontSize: 9)),
      ]),
    )).toList();
  }

  int _balance(int accountId, List<JournalEntry> entries) {
    final d = entries.where((e) => e.debitAccountId == accountId).fold(0, (s, e) => s + e.amount);
    final c = entries.where((e) => e.creditAccountId == accountId).fold(0, (s, e) => s + e.amount);
    return d - c;
  }
}
