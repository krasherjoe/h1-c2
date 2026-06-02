import 'dart:io';
import 'dart:math' as math;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../../services/company_repository.dart';
import '../../../utils/font_cache.dart';
import '../../documents/logic/document_pdf_generator.dart' show kSealPreviewPageFormat;
import '../models/memorandum_model.dart';

Future<pw.Document> buildMemorandumDocument(Memorandum memo, {
  double? sealOffsetXOverride,
  double? sealOffsetYOverride,
}) async {
  final pdf = pw.Document(
    title: '覚書 ${memo.documentNumber}',
    author: 'h1-app',
  );

  final ipaex = await loadIpaexFont();
  final dateFormatter = DateFormat('yyyy年M月d日');
  final amountFormatter = NumberFormat('#,###');

  final companyRepo = CompanyRepository();
  final companyInfo = await companyRepo.getCompanyInfo();
  final companyName = companyInfo?.name ?? '';

pw.MemoryImage? sealImage;
if (companyInfo?.sealPath != null) {
  final file = File(companyInfo!.sealPath!);

    if (await file.exists()) {
      sealImage = pw.MemoryImage(await file.readAsBytes());
    }
  }

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
                  child: pw.Image(sealImage, width: 100, height: 100),
                ),
              ),
            ],
          );
        },
      ),
      build: (context) => [
        pw.Center(
          child: pw.Text('保守サービスに関する覚え書き',
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
        ),
        pw.SizedBox(height: 20),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('No. ${memo.documentNumber}', style: const pw.TextStyle(fontSize: 11)),
            pw.Text('作成日: ${dateFormatter.format(memo.contractDate)}',
              style: const pw.TextStyle(fontSize: 11)),
          ],
        ),
        pw.SizedBox(height: 20),
        pw.Text('発注者（以下「甲」という）', style: const pw.TextStyle(fontSize: 11)),
        pw.SizedBox(height: 4),
        pw.Text('    ${memo.customerName}', style: const pw.TextStyle(fontSize: 11)),
        pw.SizedBox(height: 12),
        pw.Text('受注者（以下「乙」という）', style: const pw.TextStyle(fontSize: 11)),
        pw.SizedBox(height: 4),
        pw.Text('    $companyName', style: const pw.TextStyle(fontSize: 11)),
        pw.SizedBox(height: 20),
        pw.Text('第1条（契約の目的）', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 4),
        pw.Text('甲は乙に対し、別紙に記載する役務（以下「本サービス」という）の提供を委託し、乙はこれを受託する。',
          style: const pw.TextStyle(fontSize: 11)),
        pw.SizedBox(height: 12),
        pw.Text('第2条（契約期間）', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 4),
        pw.Text('本契約の有効期間は、${dateFormatter.format(memo.startDate)}から${dateFormatter.format(memo.endDate)}までの${memo.contractMonths}ヶ月間とする。',
          style: const pw.TextStyle(fontSize: 11)),
        pw.SizedBox(height: 12),
        pw.Text('第3条（保守料金）', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 4),
        pw.Text('甲は乙に対し、本サービスの対価として、月額${amountFormatter.format(memo.monthlyAmount)}円（税別）を支払うものとする。',
          style: const pw.TextStyle(fontSize: 11)),
        pw.SizedBox(height: 4),
        pw.Text('契約期間中の総額は${amountFormatter.format(memo.totalAmount)}円（税別）となる。',
          style: const pw.TextStyle(fontSize: 11)),
        pw.SizedBox(height: 12),
        pw.Text('第4条（サービス内容）', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 4),
        pw.Text(memo.serviceContent, style: const pw.TextStyle(fontSize: 11)),
        pw.SizedBox(height: 12),
        pw.Text('第5条（秘密保持）', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 4),
        pw.Text('甲乙は、本契約に関して知り得た相手方の秘密情報を、正当な理由なく第三者に開示または漏洩してはならない。',
          style: const pw.TextStyle(fontSize: 11)),
        pw.SizedBox(height: 12),
        pw.Text('第6条（自動更新）', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 4),
        pw.Text('本契約の期間満了の際、甲乙双方から特に異議の申出がないときは、本契約と同一の条件をもって更に1年間自動更新されるものとし、以降も同様とする。',
          style: const pw.TextStyle(fontSize: 11)),
        pw.SizedBox(height: 12),
        pw.Text('第7条（協議）', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 4),
        pw.Text('本契約に定めのない事項または疑義が生じた場合は、甲乙誠意をもって協議の上解決するものとする。',
          style: const pw.TextStyle(fontSize: 11)),
        pw.SizedBox(height: 30),
        pw.Center(
          child: pw.Column(
            children: [
              pw.Text('本契約の成立を証するため、本書2通を作成し、甲乙署名の上、各1通を保有する。',
                style: const pw.TextStyle(fontSize: 11)),
              pw.SizedBox(height: 16),
              pw.Text(dateFormatter.format(memo.contractDate),
                style: const pw.TextStyle(fontSize: 11)),
              pw.SizedBox(height: 24),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.Text('甲（発注者）', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                      pw.SizedBox(height: 12),
                      pw.Container(
                        width: 180,
                        child: pw.Column(
                          children: [
                            pw.Text(memo.customerName, style: const pw.TextStyle(fontSize: 11)),
                            pw.SizedBox(height: 8),
                            pw.Align(
                              alignment: pw.Alignment.centerLeft,
                              child: pw.Text('署名:', style: const pw.TextStyle(fontSize: 10)),
                            ),
                            pw.SizedBox(height: 4),
                            pw.Container(
                              width: 140,
                              height: 24,
                              decoration: pw.BoxDecoration(
                                border: pw.Border(bottom: pw.BorderSide(color: PdfColors.black)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.Text('乙（受注者）', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                      pw.SizedBox(height: 12),
                      pw.Container(
                        width: 180,
                        child: pw.Column(
                          children: [
                            pw.Text(companyName, style: const pw.TextStyle(fontSize: 11)),
                            pw.SizedBox(height: 8),
                            pw.Align(
                              alignment: pw.Alignment.centerLeft,
                              child: pw.Text('署名:', style: const pw.TextStyle(fontSize: 10)),
                            ),
                            pw.SizedBox(height: 4),
                            pw.Container(
                              width: 140,
                              height: 24,
                              decoration: pw.BoxDecoration(
                                border: pw.Border(bottom: pw.BorderSide(color: PdfColors.black)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
      footer: (context) => pw.Container(
        alignment: pw.Alignment.centerRight,
        child: pw.Text(
          "Page ${context.pageNumber} / ${context.pagesCount}",
          style: const pw.TextStyle(color: PdfColors.grey),
        ),
      ),
    ),
  );

  return pdf;
}
