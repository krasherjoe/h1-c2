import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:crypto/crypto.dart';
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

bool _anyItemHasDiscount(List<DocumentItem> items) =>
    items.any((i) => i.discountAmount != null || i.discountRate != null);

pw.Widget _buildItemTable(DocumentModel doc, int maxItems, NumberFormat fmt, pw.Font font) {
  final hasDiscount = _anyItemHasDiscount(doc.items);
  final items = doc.items.take(maxItems).toList();

  return pw.Table(
    border: pw.TableBorder.symmetric(
      outside: const pw.BorderSide(color: PdfColors.grey400),
      inside: const pw.BorderSide(color: PdfColors.grey200),
    ),
    columnWidths: const {
      0: pw.FlexColumnWidth(3.5),
      1: pw.FlexColumnWidth(1),
      2: pw.FlexColumnWidth(1.5),
      3: pw.FlexColumnWidth(1.5),
    },
    children: [
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: PdfColors.grey300),
        children: [
          _headerCell('品名', font),
          _headerCell('数量', font, alignRight: true),
          _headerCell('単価', font, alignRight: true),
          _headerCell('金額', font, alignRight: true),
        ],
      ),
      ...items.asMap().entries.map((entry) {
        final i = entry.value;
        final isEven = entry.key.isEven;
        final rowChildren = <pw.Widget>[];
        final makerCode = [if (i.maker.isNotEmpty) i.maker, if (i.productCode.isNotEmpty) i.productCode].join(' / ');
        final label = makerCode.isNotEmpty
            ? '   ${i.productName}  ($makerCode)'
            : '   ${i.productName}';
        rowChildren.add(_cell(label, font, isEven));
        rowChildren.add(_cell(i.quantity.toString(), font, isEven, alignRight: true));
        rowChildren.add(_cell(fmt.format(i.unitPrice), font, isEven, alignRight: true));
        if (hasDiscount && i.discountAmount != null) {
          rowChildren.add(_cell('${fmt.format(i.subtotal)} (値引${fmt.format(i.discountAmount!)})', font, isEven, alignRight: true));
        } else if (hasDiscount && i.discountRate != null) {
          rowChildren.add(_cell('${fmt.format(i.subtotal)} (${(i.discountRate! * 100).round()}%OFF)', font, isEven, alignRight: true));
        } else {
          rowChildren.add(_cell(fmt.format(i.subtotal), font, isEven, alignRight: true));
        }
        return pw.TableRow(
          decoration: pw.BoxDecoration(
            color: isEven ? PdfColors.white : PdfColors.grey100,
          ),
          children: rowChildren,
        );
      }),
    ],
  );
}

pw.Widget _headerCell(String text, pw.Font font, {bool alignRight = false}) {
  return pw.Padding(
    padding: const pw.EdgeInsets.all(6),
    child: pw.Text(
      text,
      style: pw.TextStyle(fontWeight: pw.FontWeight.bold, font: font, fontSize: 10),
      textAlign: alignRight ? pw.TextAlign.right : pw.TextAlign.left,
    ),
  );
}

pw.Widget _cell(String text, pw.Font font, bool isEven, {bool alignRight = false}) {
  return pw.Padding(
    padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
    child: pw.Text(
      text,
      style: pw.TextStyle(font: font, fontSize: 9, color: PdfColors.black),
      textAlign: alignRight ? pw.TextAlign.right : pw.TextAlign.left,
    ),
  );
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

  final subtotal = document.subtotal;
  final discount = document.discountAmount;
  final taxable = document.taxableAmount;
  final tax = document.tax;

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
                      child: pw.Text('${document.customerName} 様', style: const pw.TextStyle(fontSize: 18)),
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
                      pw.SizedBox(height: 2),
                      if (companyInfo.zipCode != null) ...[pw.Text('〒${companyInfo.zipCode}'), pw.SizedBox(height: 2)],
                      if (companyInfo.address != null) ...[pw.Text(companyInfo.address!), pw.SizedBox(height: 2)],
                      if (companyInfo.address2 != null && companyInfo.address2!.isNotEmpty) ...[pw.Text(companyInfo.address2!), pw.SizedBox(height: 2)],
                      if (companyInfo.tel != null) ...[pw.Text('TEL: ${companyInfo.tel}'), pw.SizedBox(height: 2)],
                      if (companyInfo.fax != null && companyInfo.fax!.isNotEmpty) ...[pw.Text('FAX: ${companyInfo.fax}'), pw.SizedBox(height: 2)],
                      if (companyInfo.email != null && companyInfo.email!.isNotEmpty) ...[pw.Text(companyInfo.email!), pw.SizedBox(height: 2)],
                      if (companyInfo.url != null && companyInfo.url!.isNotEmpty) ...[pw.Text(companyInfo.url!), pw.SizedBox(height: 2)],
                      if (companyInfo.registrationNumber != null &&
                          companyInfo.registrationNumber!.isNotEmpty &&
                          companyInfo.taxDisplayMode != 'hidden') ...[
                        pw.Text('登録番号: ${companyInfo.registrationNumber!}',
                            style: const pw.TextStyle(fontSize: 10)),
                        pw.SizedBox(height: 2),
                      ],
                      if (document.documentType == DocumentType.invoice ||
                          document.documentType == DocumentType.receipt)
                        ..._buildBankAccountPdfLines(companyInfo, ipaex),
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
          _buildItemTable(document, maxItems, amountFormatter, ipaex),
          pw.SizedBox(height: 20),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.end,
            children: [
              pw.Container(
                width: 200,
                child: pw.Column(
                  children: [
                    _buildSummaryRow('小計', amountFormatter.format(subtotal)),
                    if (discount > 0)
                      _buildSummaryRow('値引き', '-${amountFormatter.format(discount)}'),
                    if (taxable != subtotal && discount > 0)
                      _buildSummaryRow('税抜合計', amountFormatter.format(taxable)),
                    if (tax > 0 && !_isExemptNoT(companyInfo))
                      _buildSummaryRow('消費税 (${(document.taxRate * 100).round()}%)', amountFormatter.format(tax)),
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
          ..._buildVerificationSection(document, ipaex),
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

List<pw.Widget> _buildBankAccountPdfLines(CompanyInfo company, pw.Font font) {
  final json = company.bankAccounts;
  if (json == null || json.isEmpty) return [];
  try {
    final list = (jsonDecode(json) as List).cast<Map<String, dynamic>>();
    final accounts = list.map((e) => CompanyBankAccount.fromJson(e)).toList();
    final active = accounts.where((a) => a.isActive).toList();
    if (active.isEmpty) return [];
    final lines = <pw.Widget>[
      pw.SizedBox(height: 4),
      pw.Text('振込先:', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, font: font)),
    ];
    for (final a in active) {
      final parts = <String>[a.bankName];
      if (a.branchName.isNotEmpty) parts.add(a.branchName);
      parts.add(a.accountType);
      if (a.accountNumber.isNotEmpty) parts.add(a.accountNumber);
      if (a.holderName.isNotEmpty) parts.add(a.holderName);
      lines.add(pw.Text(parts.join(' '), style: pw.TextStyle(fontSize: 8, font: font)));
    }
    return lines;
  } catch (_) {
    return [];
  }
}

List<pw.Widget> _buildVerificationSection(DocumentModel doc, pw.Font font) {
  if (!doc.isConfirmed) return [];
  final payload = {
    'id': doc.id,
    'type': doc.documentType.name,
    'number': doc.documentNumber,
    'date': '${doc.date.year}/${doc.date.month.toString().padLeft(2, '0')}/${doc.date.day.toString().padLeft(2, '0')}',
    'customer': doc.customerName,
    'total': doc.total,
    'status': doc.status,
    'items': doc.items.map((i) => {
      'name': i.productName,
      'maker': i.maker,
      'code': i.productCode,
      'qty': i.quantity,
      'price': i.unitPrice,
    }).toList(),
  };
  final jsonStr = jsonEncode(payload);
  final hash = sha256.convert(utf8.encode(jsonStr)).toString();
  final shortHash = hash.substring(0, 16);
  return [
    pw.SizedBox(height: 8),
    pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Container(
          width: 48, height: 48,
          child: pw.BarcodeWidget(
            barcode: pw.Barcode.qrCode(),
            data: hash,
            width: 48, height: 48,
          ),
        ),
        pw.SizedBox(width: 8),
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('SHA-256: $shortHash...',
                style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600)),
              pw.SizedBox(height: 2),
              pw.Text('この情報は発行時のデータを元に計算されています',
                style: const pw.TextStyle(fontSize: 6.5, color: PdfColors.grey500)),
            ],
          ),
        ),
      ],
    ),
  ];
}
