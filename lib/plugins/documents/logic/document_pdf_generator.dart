import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../../services/company_repository.dart';
import '../models/document_model.dart';

Future<pw.Document> generateDocumentPdf(DocumentModel document) async {
  final pdf = pw.Document(title: '${document.documentType.label} ${document.documentNumber}');

  final fontData = await rootBundle.load('assets/fonts/ipaexg.ttf');
  final ipaex = pw.Font.ttf(fontData);
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
                  pw.Text(document.documentType.label,
                      style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 4),
                  pw.Text('No. ${document.documentNumber}', style: const pw.TextStyle(fontSize: 10)),
                  pw.Text(dateFormatter.format(document.date),
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
              pw.Text(document.customerName,
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
            ...document.items.map((item) => pw.TableRow(
                  children: [
                    _cell(item.productName),
                    _cell(amountFormatter.format(item.quantity), align: pw.TextAlign.right),
                    _cell(amountFormatter.format(item.unitPrice), align: pw.TextAlign.right),
                    _cell(amountFormatter.format(item.subtotal), align: pw.TextAlign.right),
                  ],
                )),
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
                      child: pw.Text('${amountFormatter.format(document.total)} 円',
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
                      child: pw.Text('${amountFormatter.format(document.total)} 円',
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
