import 'dart:typed_data';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/billing_template_model.dart';
import '../models/invoice_models.dart';
import '../models/customer_model.dart';
import 'invoice_repository.dart';
import 'customer_repository.dart';

/// 売掛レポート生成サービス
class ArReportGenerator {
  final _invoiceRepo = InvoiceRepository();
  final _customerRepo = CustomerRepository();
  final _dateFormat = DateFormat('yyyy/MM/dd');
  final _currencyFormat = NumberFormat('#,###');

  /// 売掛レポートPDF生成
  Future<Uint8List> generateArReport({
    required Customer customer,
    required DateTime asOfDate,
    BillingTemplate? template,
  }) async {
    try {
      // 顧客の未入金請求書を取得
      final customers = await _customerRepo.getAllCustomers();
      final invoices = await _invoiceRepo.getAllInvoices(customers)
          .where((inv) =>
              inv.customer.id == customer.id &&
              inv.documentType == DocumentType.invoice &&
              inv.paymentStatus != PaymentStatus.paid &&
              inv.paymentStatus != PaymentStatus.cancelled
          )
          .toList();

      // PDF生成
      final pdf = pw.Document();
      final font = await _getFont();

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (context) => _buildReportContent(
            context,
            customer,
            invoices,
            asOfDate,
            font,
          ),
        ),
      );

      return await pdf.save();
    } catch (e) {
      debugPrint('[ArReportGenerator] generateArReport error: $e');
      rethrow;
    }
  }

  /// 特定請求書に関連する売掛レポート生成
  Future<Uint8List> generateArReportForInvoice(Invoice invoice) async {
    return generateArReport(
      customer: invoice.customer,
      asOfDate: DateTime.now(),
    );
  }

  pw.Font _getFont() {
    // TODO: 日本語フォントのロード
    // 既存のFontCacheを使用
    return pw.Font.courier();
  }

  pw.Widget _buildReportContent(
    pw.Context context,
    Customer customer,
    List<Invoice> invoices,
    DateTime asOfDate,
    pw.Font font,
  ) {
    final totalUnpaid = invoices.fold<int>(
      0,
      (sum, inv) => sum + inv.remainingAmount,
    );

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // ヘッダー
        _buildHeader(customer, asOfDate, font),
        pw.SizedBox(height: 20),

        // サマリー
        _buildSummary(totalUnpaid, font),
        pw.SizedBox(height: 20),

        // 請求書一覧テーブル
        _buildInvoiceTable(invoices, font),
        pw.SizedBox(height: 20),

        // フッター
        _buildFooter(font),
      ],
    );
  }

  pw.Widget _buildHeader(Customer customer, DateTime asOfDate, pw.Font font) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          '売掛金レポート',
          style: pw.TextStyle(
            font: font,
            fontSize: 20,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 10),
        pw.Text(
          '顧客名: ${customer.displayName}',
          style: pw.TextStyle(font: font, fontSize: 14),
        ),
        pw.Text(
          '作成日: ${_dateFormat.format(asOfDate)}',
          style: pw.TextStyle(font: font, fontSize: 12),
        ),
      ],
    );
  }

  pw.Widget _buildSummary(int totalUnpaid, pw.Font font) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey200,
        border: pw.Border.all(color: PdfColors.grey400),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            '未入金合計',
            style: pw.TextStyle(
              font: font,
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.Text(
            '¥${_currencyFormat.format(totalUnpaid)}',
            style: pw.TextStyle(
              font: font,
              fontSize: 16,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.red800,
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildInvoiceTable(List<Invoice> invoices, pw.Font font) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey400),
      columnWidths: const {
        0: pw.FlexColumnWidth(2),
        1: pw.FlexColumnWidth(2),
        2: pw.FlexColumnWidth(1.5),
        3: pw.FlexColumnWidth(1.5),
        4: pw.FlexColumnWidth(1.5),
      },
      children: [
        // ヘッダー
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey300),
          children: [
            _tableCell('請求書番号', font, isHeader: true),
            _tableCell('発行日', font, isHeader: true),
            _tableCell('請求額', font, isHeader: true, alignRight: true),
            _tableCell('入金済', font, isHeader: true, alignRight: true),
            _tableCell('残高', font, isHeader: true, alignRight: true),
          ],
        ),
        // データ行
        ...invoices.map((inv) => pw.TableRow(
          children: [
            _tableCell(inv.invoiceNumber, font),
            _tableCell(_dateFormat.format(inv.date), font),
            _tableCell('¥${_currencyFormat.format(inv.totalAmount)}', font, alignRight: true),
            _tableCell('¥${_currencyFormat.format(inv.receivedAmount)}', font, alignRight: true),
            _tableCell(
              '¥${_currencyFormat.format(inv.remainingAmount)}',
              font,
              alignRight: true,
              isBold: inv.remainingAmount > 0,
            ),
          ],
        )),
      ],
    );
  }

  pw.Widget _tableCell(
    String text,
    pw.Font font, {
    bool isHeader = false,
    bool alignRight = false,
    bool isBold = false,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          font: font,
          fontSize: 10,
          fontWeight: isHeader || isBold ? pw.FontWeight.bold : null,
        ),
        textAlign: alignRight ? pw.TextAlign.right : pw.TextAlign.left,
      ),
    );
  }

  pw.Widget _buildFooter(pw.Font font) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Divider(color: PdfColors.grey400),
        pw.SizedBox(height: 10),
        pw.Text(
          'このレポートはシステムにより自動生成されています',
          style: pw.TextStyle(font: font, fontSize: 8, color: PdfColors.grey700),
        ),
        pw.Text(
          'ご不明な点がございましたら、お問い合わせください',
          style: pw.TextStyle(font: font, fontSize: 8, color: PdfColors.grey700),
        ),
      ],
    );
  }

  /// 期間別売掛レポート生成
  Future<Uint8List> generatePeriodArReport({
    required Customer customer,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      final customers = await _customerRepo.getAllCustomers();
      final allInvoices = await _invoiceRepo.getAllInvoices(customers);

      // 期間内の請求書をフィルタ
      final invoices = allInvoices
          .where((inv) =>
              inv.customer.id == customer.id &&
              inv.documentType == DocumentType.invoice &&
              !inv.date.isBefore(startDate) &&
              !inv.date.isAfter(endDate))
          .toList();

      return generateArReport(
        customer: customer,
        asOfDate: endDate,
      );
    } catch (e) {
      debugPrint('[ArReportGenerator] generatePeriodArReport error: $e');
      rethrow;
    }
  }
}
