import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart' show debugPrint;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../../models/company_info.dart';
import '../../../services/company_repository.dart';
import '../../../services/preview_settings_service.dart';
import '../../../utils/font_cache.dart';
import '../models/document_model.dart';

const kSealPreviewPageFormat = PdfPageFormat(
  210 * PdfPageFormat.mm,
  297 * PdfPageFormat.mm,
  marginAll: 11.29 * PdfPageFormat.mm,
);

const _systemInfo = 'この書類はシステムにより自動生成されています';

bool _isExemptNoT(CompanyInfo? c) =>
    c != null && c.isExemptTaxpayer && (c.registrationNumber == null || c.registrationNumber!.isEmpty);

pw.Widget _buildSummaryRow(String label, String value, {bool isBold = false}) {
  final style = pw.TextStyle(fontSize: 12, fontWeight: isBold ? pw.FontWeight.bold : null);
  return pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 2),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(label, style: style),
        pw.Text(value, style: style),
      ],
    ),
  );
}

String _docTypeTitle(DocumentType type) {
  switch (type) {
    case DocumentType.invoice:
      return 'ご請求書';
    case DocumentType.receipt:
      return '領収書';
    case DocumentType.estimation:
      return '見積書';
    case DocumentType.order:
      return '受注書';
    case DocumentType.delivery:
      return '納品書';
  }
}

String _amountLabel(DocumentType type) {
  switch (type) {
    case DocumentType.invoice:
      return 'ご請求金額';
    case DocumentType.receipt:
      return '領収金額';
    case DocumentType.estimation:
      return 'お見積り金額';
    case DocumentType.order:
      return '受注金額';
    case DocumentType.delivery:
      return '納品金額';
  }
}

String _tableLastColumnLabel(DocumentType type) {
  switch (type) {
    case DocumentType.receipt:
      return '領収金額';
    default:
      return '金額';
  }
}

String _totalLabel(DocumentType type) {
  switch (type) {
    case DocumentType.invoice:
      return 'ご請求合計';
    case DocumentType.receipt:
      return '領収金額合計';
    case DocumentType.estimation:
      return 'お見積り合計';
    case DocumentType.order:
      return '受注合計';
    case DocumentType.delivery:
      return '納品合計';
  }
}

String _footerMessage(DocumentType type) {
  switch (type) {
    case DocumentType.estimation:
      return 'この見積書の有効期限は発行日から2週間です';
    case DocumentType.receipt:
      return '領収書として正式に発行済みの書類です';
    default:
      return _systemInfo;
  }
}

Future<pw.Document> generateDocumentPdf(DocumentModel document, {
  double? sealOffsetXOverride,
  double? sealOffsetYOverride,
}) async {
  final maxItems = await loadMaxPreviewItems();

  final pdf = pw.Document(
    title: '${_docTypeTitle(document.documentType)} ${document.documentNumber}',
    author: 'h1-app',
  );

  final ipaex = await loadIpaexFont();
  final dateFormatter = DateFormat('yyyy年MM月dd日');
  final amountFormatter = NumberFormat('#,###');

  final companyRepo = CompanyRepository();
  final companyInfo = await companyRepo.getCompanyInfo();

  pw.MemoryImage? sealImage;
  if (companyInfo?.sealPath != null) {
    final file = File(companyInfo!.sealPath!);
    if (await file.exists()) {
      sealImage = pw.MemoryImage(await file.readAsBytes());
    }
  }

  final subtotal = document.items.map((i) => i.subtotal).fold(0, (a, b) => a + b);
  final tax = document.total - subtotal;

  pdf.addPage(
    pw.MultiPage(
      pageTheme: pw.PageTheme(
        pageFormat: kSealPreviewPageFormat,
        margin: const pw.EdgeInsets.all(32),
        theme: pw.ThemeData.withFont(
          base: ipaex,
          bold: ipaex,
          italic: ipaex,
          boldItalic: ipaex,
        ).copyWith(defaultTextStyle: pw.TextStyle(fontFallback: [ipaex])),
        buildBackground: (context) {
          if (sealImage == null) return pw.SizedBox();
          final sealX = sealOffsetXOverride ?? companyInfo?.sealOffsetX ?? 10.0;
          final sealY = sealOffsetYOverride ?? companyInfo?.sealOffsetY ?? 50.0;
          return pw.Stack(
            fit: pw.StackFit.expand,
            children: [
              pw.Positioned(
                right: sealX,
                top: sealY,
                child: pw.Transform.rotate(
                  angle: (companyInfo?.sealRotation ?? 0.0) * math.pi / 180,
                  child: pw.Image(sealImage!, width: 100, height: 100),
                ),
              ),
            ],
          );
        },
        buildForeground: (context) {
          if (!document.isDraft) return pw.SizedBox();
          return pw.Center(
            child: pw.Transform.rotate(
              angle: -0.5,
              child: pw.Opacity(
                opacity: 0.18,
                child: pw.Text(
                  '下書き',
                  style: pw.TextStyle(
                    fontSize: 120,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.grey600,
                  ),
                ),
              ),
            ),
          );
        },
      ),
      build: (context) {
        final content = <pw.Widget>[
          pw.Header(
            level: 0,
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  _docTypeTitle(document.documentType),
                  style: pw.TextStyle(fontSize: 28, fontWeight: pw.FontWeight.bold),
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('番号: ${document.documentNumber}'),
                    pw.Text('発行日: ${dateFormatter.format(document.date)}'),
                  ],
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 20),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Container(
                      decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(width: 1))),
                      child: pw.Text(document.customerName, style: const pw.TextStyle(fontSize: 18)),
                    ),
                    if (document.subject != null && document.subject!.isNotEmpty)
                      pw.Padding(
                        padding: const pw.EdgeInsets.only(top: 8),
                        child: pw.Text(document.subject!, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                      ),
                    pw.SizedBox(height: 10),
                    pw.Text(
                      () {
                        switch (document.documentType) {
                          case DocumentType.receipt:
                            return '上記の金額を正に領収いたしました。';
                          case DocumentType.estimation:
                            return '下記の通り、お見積り申し上げます。';
                          case DocumentType.delivery:
                            return '下記の通り、納品いたしました。';
                          case DocumentType.order:
                            return '下記の通り、受注申し上げます。';
                          case DocumentType.invoice:
                          default:
                            return '下記の通り、ご請求申し上げます。';
                        }
                      }(),
                    ),
                  ],
                ),
              ),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    if (companyInfo != null) ...[
                      pw.Text(companyInfo.name, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                      if (companyInfo.zipCode != null) pw.Text('〒${companyInfo.zipCode}'),
                      if (companyInfo.address != null) pw.Text(companyInfo.address!),
                      if (companyInfo.address2 != null && companyInfo.address2!.isNotEmpty)
                        pw.Text(companyInfo.address2!),
                      if (companyInfo.tel != null) pw.Text('TEL: ${companyInfo.tel}'),
                      if (companyInfo.fax != null && companyInfo.fax!.isNotEmpty)
                        pw.Text('FAX: ${companyInfo.fax}'),
                      if (companyInfo.email != null && companyInfo.email!.isNotEmpty)
                        pw.Text(companyInfo.email!),
                      if (companyInfo.url != null && companyInfo.url!.isNotEmpty)
                        pw.Text(companyInfo.url!),
                      if (companyInfo.registrationNumber != null &&
                          companyInfo.registrationNumber!.isNotEmpty &&
                          companyInfo.taxDisplayMode != 'hidden')
                        pw.Text('登録番号: ${companyInfo.registrationNumber!}',
                            style: const pw.TextStyle(fontSize: 10)),
                    ],
                  ],
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 30),
          pw.Container(
            padding: const pw.EdgeInsets.all(8),
            decoration: const pw.BoxDecoration(color: PdfColors.grey200),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(_amountLabel(document.documentType), style: const pw.TextStyle(fontSize: 16)),
                pw.Text(
                  '￥${amountFormatter.format(document.total)} -',
                  style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 20),
          pw.TableHelper.fromTextArray(
            headers: ['品名', '数量', '単価', _tableLastColumnLabel(document.documentType)],
            data: document.items
                .take(maxItems)
                .map((item) => [
                      item.productName,
                      item.quantity.toString(),
                      amountFormatter.format(item.unitPrice),
                      amountFormatter.format(item.subtotal),
                    ])
                .toList(),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, font: ipaex),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
            cellAlignment: pw.Alignment.centerLeft,
            columnWidths: const {
              0: pw.FlexColumnWidth(3),
              1: pw.FlexColumnWidth(1),
              2: pw.FlexColumnWidth(2),
              3: pw.FlexColumnWidth(2),
            },
            cellAlignments: const {
              0: pw.Alignment.centerLeft,
              1: pw.Alignment.centerRight,
              2: pw.Alignment.centerRight,
              3: pw.Alignment.centerRight,
            },
          ),
          pw.SizedBox(height: 20),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.end,
            children: [
              pw.Container(
                width: 200,
                child: pw.Column(
                  children: [
                    _buildSummaryRow('小計', amountFormatter.format(subtotal)),
                    if (tax > 0 && !_isExemptNoT(companyInfo))
                      _buildSummaryRow('消費税 (10%)', amountFormatter.format(tax)),
                    pw.Divider(),
                    _buildSummaryRow(
                      _totalLabel(document.documentType),
                      '￥${amountFormatter.format(document.total)}',
                      isBold: true,
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (companyInfo != null &&
              companyInfo.isExemptTaxpayer &&
              (companyInfo.registrationNumber == null || companyInfo.registrationNumber!.isEmpty)) ...[
            pw.SizedBox(height: 10),
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(8),
              decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey400)),
              child: pw.Text('※当方は適格請求書発行事業者ではありません。',
                  textAlign: pw.TextAlign.left,
                  style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
            ),
          ],
          pw.SizedBox(height: 20),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  if (document.isDraft)
                    pw.Text('下書き下書き下書き下書き下書き下書き',
                        style: pw.TextStyle(
                            fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.grey500)),
                ],
              ),
              if (document.isDraft)
                pw.Container(
                  width: 50,
                  height: 50,
                  decoration: const pw.BoxDecoration(
                    border: pw.Border.fromBorderSide(pw.BorderSide(color: PdfColors.grey400, width: 1)),
                  ),
                ),
            ],
          ),
        ];

        return [pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: content)];
      },
      footer: (context) => pw.Column(
        mainAxisSize: pw.MainAxisSize.min,
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Container(
            margin: const pw.EdgeInsets.only(bottom: 4),
            child: pw.Text(
              _footerMessage(document.documentType),
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
            ),
          ),
          pw.Container(
            alignment: pw.Alignment.centerRight,
            child: pw.Text(
              'Page ${context.pageNumber} / ${context.pagesCount}',
              style: const pw.TextStyle(color: PdfColors.grey),
            ),
          ),
        ],
      ),
    ),
  );

  return pdf;
}
