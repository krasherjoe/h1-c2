import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../../services/company_repository.dart';
import '../../../services/preview_settings_service.dart';
import '../../../utils/font_cache.dart';
import '../models/purchase_model.dart';

Future<pw.Document> generatePurchasePdf(PurchaseModel purchase) async {
  final maxItems = await loadMaxPreviewItems();
  final pdf = pw.Document(title: '${purchase.purchaseType.label} ${purchase.documentNumber}');

  final ipaex = await loadIpaexFont();
  final dateFormatter = DateFormat('yyyy年MM月dd日');
  final amountFormatter = NumberFormat('#,###');

  final companyRepo = CompanyRepository();
  final companyInfo = await companyRepo.getCompanyInfo();

  pdf.addPage(
    pw.MultiPage(
      pageTheme: pw.PageTheme(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        theme: pw.ThemeData.withFont(base: ipaex, bold: ipaex),
      ),
      header: (context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  if (companyInfo != null) ...[
                    pw.Text(companyInfo.name,
                        style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                    if (companyInfo.address != null)
                      pw.Text(companyInfo.address!, style: const pw.TextStyle(fontSize: 9)),
                    if (companyInfo.tel != null)
                      pw.Text('TEL: ${companyInfo.tel}', style: const pw.TextStyle(fontSize: 9)),
                    if (companyInfo.registrationNumber != null)
                      pw.Text('登録番号: ${companyInfo.registrationNumber}',
                          style: const pw.TextStyle(fontSize: 8)),
                  ],
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(purchase.purchaseType.label,
                      style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 4),
                  pw.Text('No. ${purchase.documentNumber}', style: const pw.TextStyle(fontSize: 10)),
                  pw.Text(dateFormatter.format(purchase.date),
                      style: const pw.TextStyle(fontSize: 10)),
                ],
              ),
            ],
          ),
          pw.Divider(thickness: 1.5),
        ],
      ),
      footer: (context) => pw.Column(
        children: [
          pw.Divider(thickness: 0.5),
          pw.Text('この書類はシステムにより自動生成されています',
              style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey)),
        ],
      ),
      build: (context) => [
        pw.SizedBox(height: 20),
        pw.Container(
          padding: const pw.EdgeInsets.all(12),
          decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey300)),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(purchase.supplierName,
                  style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
            ],
          ),
        ),
        pw.SizedBox(height: 20),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey400),
          columnWidths: {
            0: const pw.FlexColumnWidth(3),
            1: const pw.FlexColumnWidth(1),
            2: const pw.FlexColumnWidth(1.2),
            3: const pw.FlexColumnWidth(1.2),
          },
          children: [
            pw.TableRow(
              decoration: pw.BoxDecoration(color: PdfColors.grey200),
              children: [
                _cell('品名', isHeader: true),
                _cell('数量', isHeader: true, align: pw.TextAlign.right),
                _cell('単価', isHeader: true, align: pw.TextAlign.right),
                _cell('金額', isHeader: true, align: pw.TextAlign.right),
              ],
            ),
            ...purchase.items.take(maxItems).map((item) => pw.TableRow(
                  children: [
                    _cell(item.productName),
                    _cell(amountFormatter.format(item.quantity), align: pw.TextAlign.right),
                    _cell(amountFormatter.format(item.unitPrice), align: pw.TextAlign.right),
                    _cell(amountFormatter.format(item.subtotal), align: pw.TextAlign.right),
                  ],
                )),
            if (purchase.items.length > maxItems)
              pw.TableRow(
                children: [
                  _cell('他 ${purchase.items.length - maxItems} 件', isHeader: true),
                  _cell('', align: pw.TextAlign.right),
                  _cell('', align: pw.TextAlign.right),
                  _cell('', align: pw.TextAlign.right),
                ],
              ),
          ],
        ),
        pw.SizedBox(height: 12),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.end,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Row(
                  children: [
                    pw.SizedBox(
                      width: 100,
                      child: pw.Text('小計', style: const pw.TextStyle(fontSize: 10)),
                    ),
                    pw.SizedBox(
                      width: 100,
                      child: pw.Text('${amountFormatter.format(purchase.total)} 円',
                          style: const pw.TextStyle(fontSize: 10),
                          textAlign: pw.TextAlign.right),
                    ),
                  ],
                ),
                pw.SizedBox(height: 6),
                pw.Row(
                  children: [
                    pw.SizedBox(
                      width: 100,
                      child:
                          pw.Text('合計', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                    ),
                    pw.SizedBox(
                      width: 100,
                      child: pw.Text('${amountFormatter.format(purchase.total)} 円',
                          style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
                          textAlign: pw.TextAlign.right),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ],
    ),
  );

  return pdf;
}

pw.Widget _cell(String text, {bool isHeader = false, pw.TextAlign align = pw.TextAlign.left}) {
  return pw.Padding(
    padding: const pw.EdgeInsets.all(6),
    child: pw.Text(text,
        textAlign: align,
        style: pw.TextStyle(
            fontSize: isHeader ? 10 : 9,
            fontWeight: isHeader ? pw.FontWeight.bold : null)),
  );
}
