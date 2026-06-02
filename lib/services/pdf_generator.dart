import 'dart:io';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/customer_model.dart';
import '../models/invoice_models.dart';
import 'company_repository.dart';

Future<Uint8List> generateInvoicePdf(Invoice invoice) async {
  final pdf = pw.Document(
    title: '${invoice.documentTypeName} ${invoice.invoiceNumber}',
    author: 'h1-core',
  );

  final fontData = await rootBundle.load("fonts/ipaexg.ttf");
  final ipaex = pw.Font.ttf(fontData);
  final dateFormatter = DateFormat('yyyy年MM月dd日');
  final amountFormatter = NumberFormat("#,###");

  final companyRepo = CompanyRepository();
  final companyInfo = await companyRepo.getCompanyInfo();

  pdf.addPage(
    pw.MultiPage(
      pageTheme: pw.PageTheme(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        theme: pw.ThemeData.withFont(
          base: ipaex,
          bold: ipaex,
        ),
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
                    pw.Text(
                      companyInfo.name,
                      style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
                    ),
                    if (companyInfo.address != null)
                      pw.Text(companyInfo.address!, style: const pw.TextStyle(fontSize: 9)),
                    if (companyInfo.tel != null)
                      pw.Text('TEL: ${companyInfo.tel}', style: const pw.TextStyle(fontSize: 9)),
                    if (companyInfo.registrationNumber != null)
                      pw.Text('登録番号: ${companyInfo.registrationNumber}', style: const pw.TextStyle(fontSize: 8)),
                  ],
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(
                    invoice.documentTypeName,
                    style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text('No. ${invoice.invoiceNumber}', style: const pw.TextStyle(fontSize: 10)),
                  pw.Text(dateFormatter.format(invoice.date), style: const pw.TextStyle(fontSize: 10)),
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
          pw.Text(
            'この書類はシステムにより自動生成されています',
            style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey),
          ),
        ],
      ),
      build: (context) => [
        pw.SizedBox(height: 20),
        pw.Container(
          padding: const pw.EdgeInsets.all(12),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.grey300),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                invoice.customer.invoiceName,
                style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
              ),
              if (invoice.customer.address != null && invoice.customer.address!.isNotEmpty)
                pw.Text(invoice.customer.address!, style: const pw.TextStyle(fontSize: 9)),
              if (invoice.customer.tel != null && invoice.customer.tel!.isNotEmpty)
                pw.Text('TEL: ${invoice.customer.tel}', style: const pw.TextStyle(fontSize: 9)),
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
                _tableCell('品名', isHeader: true),
                _tableCell('数量', isHeader: true, align: pw.TextAlign.right),
                _tableCell('単価', isHeader: true, align: pw.TextAlign.right),
                _tableCell('金額', isHeader: true, align: pw.TextAlign.right),
              ],
            ),
            ...invoice.items.map((item) => pw.TableRow(
              children: [
                _tableCell(item.description),
                _tableCell(amountFormatter.format(item.quantity), align: pw.TextAlign.right),
                _tableCell(amountFormatter.format(item.unitPrice), align: pw.TextAlign.right),
                _tableCell(amountFormatter.format(item.subtotal), align: pw.TextAlign.right),
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
                      child: pw.Text(
                        '${amountFormatter.format(invoice.subtotal)} 円',
                        style: const pw.TextStyle(fontSize: 10),
                        textAlign: pw.TextAlign.right,
                      ),
                    ),
                  ],
                ),
                if (invoice.includeTax) ...[
                  pw.SizedBox(height: 4),
                  pw.Row(
                    children: [
                      pw.SizedBox(
                        width: 100,
                        child: pw.Text('消費税', style: const pw.TextStyle(fontSize: 10)),
                      ),
                      pw.SizedBox(
                        width: 100,
                        child: pw.Text(
                          '${amountFormatter.format(invoice.tax)} 円',
                          style: const pw.TextStyle(fontSize: 10),
                          textAlign: pw.TextAlign.right,
                        ),
                      ),
                    ],
                  ),
                ],
                pw.SizedBox(height: 6),
                pw.Row(
                  children: [
                    pw.SizedBox(
                      width: 100,
                      child: pw.Text('合計', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                    ),
                    pw.SizedBox(
                      width: 100,
                      child: pw.Text(
                        '${amountFormatter.format(invoice.totalAmount)} 円',
                        style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
                        textAlign: pw.TextAlign.right,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
        if (invoice.notes != null && invoice.notes!.isNotEmpty) ...[
          pw.SizedBox(height: 20),
          pw.Container(
            padding: const pw.EdgeInsets.all(8),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey300),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('備考', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 4),
                pw.Text(invoice.notes!, style: const pw.TextStyle(fontSize: 9)),
              ],
            ),
          ),
        ],
      ],
    ),
  );

  return pdf.save();
}

pw.Widget _tableCell(String text, {bool isHeader = false, pw.TextAlign align = pw.TextAlign.left}) {
  return pw.Padding(
    padding: const pw.EdgeInsets.all(6),
    child: pw.Text(
      text,
      textAlign: align,
      style: pw.TextStyle(
        fontSize: isHeader ? 10 : 9,
        fontWeight: isHeader ? pw.FontWeight.bold : null,
      ),
    ),
  );
}

class PdfGenerator {
  static Future<Uint8List> generateInvoice(Invoice invoice) async {
    return generateInvoicePdf(invoice);
  }

  static Future<String> generateAndSaveInvoice(Invoice invoice) async {
    final pdf = await generateInvoicePdf(invoice);
    final dir = await getApplicationDocumentsDirectory();
    final filePath = '${dir.path}/${invoice.mailAttachmentFileName}';
    final file = File(filePath);
    await file.writeAsBytes(pdf);
    debugPrint('[PdfGenerator] saved to $filePath');
    return filePath;
  }

  static Future<void> printInvoice(Invoice invoice) async {
    final pdf = await generateInvoicePdf(invoice);
    await Printing.layoutPdf(onLayout: (_) => pdf);
  }

  static Future<void> previewInvoice(Invoice invoice) async {
    final pdf = await generateInvoicePdf(invoice);
    await Printing.layoutPdf(onLayout: (_) => pdf);
  }
}
