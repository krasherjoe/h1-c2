import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import '../models/billing_template_model.dart';
import '../models/invoice_models.dart';
import '../models/customer_model.dart';
import 'invoice_repository.dart';
import 'customer_repository.dart';
import '../plugins/documents/models/document_model.dart' hide DocumentType;
import '../plugins/documents/services/document_repository.dart';

/// 売掛レポート生成サービス
class ArReportGenerator {
  final _invoiceRepo = InvoiceRepository();
  final _customerRepo = CustomerRepository();
  final _docRepo = DocumentRepository();
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
      final allInvoices = await _invoiceRepo.getAllInvoices(customers);
      final invoices = allInvoices
          .where((inv) =>
              inv.customer.id == customer.id &&
              !inv.isLocked
          )
          .toList();

      // 先月の繰越分を取得
      final lastMonth = DateTime(asOfDate.year, asOfDate.month - 1);
      final lastMonthInvoices = invoices
          .where((inv) =>
              inv.date.year == lastMonth.year &&
              inv.date.month == lastMonth.month
          )
          .toList();

      // 繰越がある場合、先月分も追加
      if (lastMonthInvoices.isNotEmpty) {
        invoices.addAll(lastMonthInvoices);
      }

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
            hasCarryOver: lastMonthInvoices.isNotEmpty,
          ),
        ),
      );

      // メタデータをPDFに添付
      final pdfBytes = await pdf.save();
      return pdfBytes;
    } catch (e) {
      debugPrint('[ArReportGenerator] generateArReport error: $e');
      rethrow;
    }
  }

  /// 根拠納品書を取得（DocumentModel版）
  Future<List<Map<String, dynamic>>> _getSourceDocumentsFromDocuments(List<DocumentModel> documents) async {
    final sourceDocs = <Map<String, dynamic>>[];

    for (final doc in documents) {
      if (doc.linkedDocumentId != null) {
        final source = await _docRepo.fetchById(doc.linkedDocumentId!);
        if (source != null) {
          sourceDocs.add({
            'documentId': source.id,
            'documentType': source.documentType.name,
            'documentNumber': source.documentNumber,
            'date': source.date.toIso8601String(),
            'total': source.total,
            'customerId': source.customerId,
            'customerName': source.customerName,
            'items': source.items.map((item) => {
              'productId': item.productId,
              'productName': item.productName,
              'quantity': item.quantity,
              'unitPrice': item.unitPrice,
              'subtotal': item.subtotal,
              'discountAmount': item.discountAmount,
              'discountRate': item.discountRate,
            }).toList(),
          });
        }
      }
    }

    return sourceDocs;
  }

  /// 根拠納品書を取得
  Future<List<Map<String, dynamic>>> _getSourceDocuments(List<Invoice> invoices) async {
    final sourceDocs = <Map<String, dynamic>>[];

    for (final invoice in invoices) {
      // 請求書に紐づく納品書を取得
      if (invoice.linkedDeliveryId != null) {
        final delivery = await _docRepo.fetchById(invoice.linkedDeliveryId!);
        if (delivery != null) {
          sourceDocs.add({
            'documentId': delivery.id,
            'documentType': delivery.documentType.name,
            'documentNumber': delivery.documentNumber,
            'date': delivery.date.toIso8601String(),
            'total': delivery.total,
            'customerId': delivery.customerId,
            'customerName': delivery.customerName,
            'items': delivery.items.map((item) => {
              'productId': item.productId,
              'productName': item.productName,
              'quantity': item.quantity,
              'unitPrice': item.unitPrice,
              'subtotal': item.subtotal,
              'discountAmount': item.discountAmount,
              'discountRate': item.discountRate,
            }).toList(),
          });
        }
      }
    }

    return sourceDocs;
  }

  /// レポートメタデータ構築（DocumentModel版）
  Map<String, dynamic> _buildReportMetadataFromDocuments(
    String customerId,
    String customerName,
    List<DocumentModel> documents,
    List<Map<String, dynamic>> sourceDocuments,
    DateTime asOfDate, {
    bool hasCarryOver = false,
  }) {
    final totalUnpaid = documents.fold<int>(
      0,
      (sum, doc) => sum + (doc.total - (doc.receivedAmount ?? 0)),
    );

    return {
      'report': {
        'reportType': 'ar_report',
        'customerId': customerId,
        'customerName': customerName,
        'asOfDate': asOfDate.toIso8601String(),
        'totalUnpaid': totalUnpaid,
        'invoiceCount': documents.length,
        'hasCarryOver': hasCarryOver,
        'generatedAt': DateTime.now().toIso8601String(),
      },
      'sourceDocuments': sourceDocuments,
    };
  }

  /// レポートメタデータ構築
  Map<String, dynamic> _buildReportMetadata(
    Customer customer,
    List<Invoice> invoices,
    List<Map<String, dynamic>> sourceDocuments,
    DateTime asOfDate, {
    bool hasCarryOver = false,
  }) {
    final totalUnpaid = invoices.fold<int>(
      0,
      (sum, inv) => sum + inv.remainingAmount,
    );

    return {
      'report': {
        'reportType': 'ar_report',
        'customerId': customer.id,
        'customerName': customer.displayName,
        'asOfDate': asOfDate.toIso8601String(),
        'totalUnpaid': totalUnpaid,
        'invoiceCount': invoices.length,
        'hasCarryOver': hasCarryOver,
        'generatedAt': DateTime.now().toIso8601String(),
      },
      'sourceDocuments': sourceDocuments,
    };
  }

  /// 特定請求書に関連する売掛レポート生成
  Future<Uint8List> generateArReportForInvoice(Invoice invoice) async {
    return generateArReport(
      customer: invoice.customer,
      asOfDate: DateTime.now(),
    );
  }

  /// 特定伝文書に関連する売掛レポート生成（DocumentModel版）
  Future<Uint8List> generateArReportForDocument(DocumentModel document) async {
    return generateArReportFromDocument(
      customerId: document.customerId,
      customerName: document.customerName,
      asOfDate: DateTime.now(),
    );
  }

  /// 売掛レポートPDF生成（DocumentModel版）
  Future<Uint8List> generateArReportFromDocument({
    required String customerId,
    required String customerName,
    required DateTime asOfDate,
    BillingTemplate? template,
  }) async {
    try {
      // 顧客の未入金請求書を取得
      final unpaidDocuments = await _docRepo.getUnpaidDocuments();
      final documents = unpaidDocuments
          .where((doc) => doc.customerId == customerId)
          .toList();

      // 先月の繰越分を取得
      final lastMonth = DateTime(asOfDate.year, asOfDate.month - 1);
      final lastMonthDocuments = documents
          .where((doc) =>
              doc.date.year == lastMonth.year &&
              doc.date.month == lastMonth.month)
          .toList();

      // PDF生成
      final pdf = pw.Document();
      final font = _getFont();

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (context) => _buildReportContentFromDocuments(
            context,
            customerName,
            documents,
            asOfDate,
            font,
            hasCarryOver: lastMonthDocuments.isNotEmpty,
          ),
        ),
      );

      final pdfBytes = await pdf.save();
      return pdfBytes;
    } catch (e) {
      debugPrint('[ArReportGenerator] generateArReportFromDocument error: $e');
      rethrow;
    }
  }

  /// 売掛レポート生成（メタデータ付き, DocumentModel版）
  Future<Map<String, dynamic>> generateArReportWithMetadataFromDocument({
    required String customerId,
    required String customerName,
    required DateTime asOfDate,
    BillingTemplate? template,
  }) async {
    try {
      final pdfBytes = await generateArReportFromDocument(
        customerId: customerId,
        customerName: customerName,
        asOfDate: asOfDate,
        template: template,
      );

      final unpaidDocuments = await _docRepo.getUnpaidDocuments();
      final documents = unpaidDocuments
          .where((doc) => doc.customerId == customerId)
          .toList();

      final lastMonth = DateTime(asOfDate.year, asOfDate.month - 1);
      final lastMonthDocuments = documents
          .where((doc) =>
              doc.date.year == lastMonth.year &&
              doc.date.month == lastMonth.month)
          .toList();

      final sourceDocuments = await _getSourceDocumentsFromDocuments(documents);
      final metadata = _buildReportMetadataFromDocuments(
        customerId, customerName, documents, sourceDocuments, asOfDate,
        hasCarryOver: lastMonthDocuments.isNotEmpty,
      );

      return {
        'pdfBytes': pdfBytes,
        'metadata': metadata,
      };
    } catch (e) {
      debugPrint('[ArReportGenerator] generateArReportWithMetadataFromDocument error: $e');
      rethrow;
    }
  }

  /// 売掛レポートを一時ファイルとして生成（DocumentModel版）
  Future<File> generateArReportAsTempFileFromDocument({
    required String customerId,
    required String customerName,
    required DateTime asOfDate,
    BillingTemplate? template,
  }) async {
    try {
      final result = await generateArReportWithMetadataFromDocument(
        customerId: customerId,
        customerName: customerName,
        asOfDate: asOfDate,
        template: template,
      );

      final pdfBytes = result['pdfBytes'] as Uint8List;
      final tempDir = await getTemporaryDirectory();

      final dateStr = asOfDate.toString().substring(0, 10).replaceAll('-', '');
      final periodStr = '${asOfDate.year}年${asOfDate.month}月';
      final safeCustomerName = customerName.replaceAll(RegExp(r'[/:*?"<>|]'), '');
      final filename = '${dateStr}_売掛レポート_${safeCustomerName}_${periodStr}.pdf';

      final file = File('${tempDir.path}/$filename');
      await file.writeAsBytes(pdfBytes);

      debugPrint('[ArReportGenerator] Temp file created: ${file.path}');
      return file;
    } catch (e) {
      debugPrint('[ArReportGenerator] generateArReportAsTempFileFromDocument error: $e');
      rethrow;
    }
  }

  /// 売掛レポート生成（メタデータ付き）
  Future<Map<String, dynamic>> generateArReportWithMetadata({
    required Customer customer,
    required DateTime asOfDate,
    BillingTemplate? template,
  }) async {
    try {
      // 顧客の未入金請求書を取得
      final customers = await _customerRepo.getAllCustomers();
      final allInvoices = await _invoiceRepo.getAllInvoices(customers);
      final invoices = allInvoices
          .where((inv) =>
              inv.customer.id == customer.id &&
              !inv.isLocked
          )
          .toList();

      // 先月の繰越分を取得
      final lastMonth = DateTime(asOfDate.year, asOfDate.month - 1);
      final lastMonthInvoices = invoices
          .where((inv) =>
              inv.date.year == lastMonth.year &&
              inv.date.month == lastMonth.month
          )
          .toList();

      // 繰越がある場合、先月分も追加
      if (lastMonthInvoices.isNotEmpty) {
        invoices.addAll(lastMonthInvoices);
      }

      // 根拠納品書を取得
      final sourceDocuments = await _getSourceDocuments(invoices);

      // JSONメタデータ作成
      final metadata = _buildReportMetadata(customer, invoices, sourceDocuments, asOfDate, hasCarryOver: lastMonthInvoices.isNotEmpty);

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
            hasCarryOver: lastMonthInvoices.isNotEmpty,
          ),
        ),
      );

      final pdfBytes = await pdf.save();

      return {
        'pdfBytes': pdfBytes,
        'metadata': metadata,
      };
    } catch (e) {
      debugPrint('[ArReportGenerator] generateArReportWithMetadata error: $e');
      rethrow;
    }
  }

  /// 売掛レポートを一時ファイルとして生成
  Future<File> generateArReportAsTempFile({
    required Customer customer,
    required DateTime asOfDate,
    BillingTemplate? template,
  }) async {
    try {
      final result = await generateArReportWithMetadata(
        customer: customer,
        asOfDate: asOfDate,
        template: template,
      );

      final pdfBytes = result['pdfBytes'] as Uint8List;
      final tempDir = await getTemporaryDirectory();
      
      // ファイル名: 20260630_売掛レポート_お客_{期間}.pdf
      final dateStr = asOfDate.toString().substring(0, 10).replaceAll('-', '');
      final periodStr = '${asOfDate.year}年${asOfDate.month}月';
      final customerName = customer.displayName.replaceAll(RegExp(r'[/:*?"<>|]'), '');
      final filename = '${dateStr}_売掛レポート_${customerName}_${periodStr}.pdf';
      
      final file = File('${tempDir.path}/$filename');
      await file.writeAsBytes(pdfBytes);

      debugPrint('[ArReportGenerator] Temp file created: ${file.path}');
      return file;
    } catch (e) {
      debugPrint('[ArReportGenerator] generateArReportAsTempFile error: $e');
      rethrow;
    }
  }

  pw.Font _getFont() {
    // TODO: 日本語フォントのロード
    // 既存のFontCacheを使用
    return pw.Font.courier();
  }

  pw.Widget _buildReportContentFromDocuments(
    pw.Context context,
    String customerName,
    List<DocumentModel> documents,
    DateTime asOfDate,
    pw.Font font, {
    bool hasCarryOver = false,
  }) {
    final totalUnpaid = documents.fold<int>(
      0,
      (sum, doc) => sum + (doc.total - (doc.receivedAmount ?? 0)),
    );

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // ヘッダー
        _buildHeaderFromDocuments(customerName, asOfDate, font, hasCarryOver),
        pw.SizedBox(height: 20),

        // サマリー
        _buildSummary(totalUnpaid, font),
        pw.SizedBox(height: 20),

        // 伝票一覧テーブル
        _buildDocumentTable(documents, font),
        pw.SizedBox(height: 20),

        // フッター
        _buildFooter(font),
      ],
    );
  }

  pw.Widget _buildReportContent(
    pw.Context context,
    Customer customer,
    List<Invoice> invoices,
    DateTime asOfDate,
    pw.Font font, {
    bool hasCarryOver = false,
  }) {
    final totalUnpaid = invoices.fold<int>(
      0,
      (sum, inv) => sum + inv.remainingAmount,
    );

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // ヘッダー
        _buildHeader(customer, asOfDate, font, hasCarryOver),
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

  pw.Widget _buildHeader(Customer customer, DateTime asOfDate, pw.Font font, bool hasCarryOver) {
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
        if (hasCarryOver)
          pw.Text(
            '※先月の繰越分を含みます',
            style: pw.TextStyle(font: font, fontSize: 10, color: PdfColors.orange800),
          ),
      ],
    );
  }

  pw.Widget _buildHeaderFromDocuments(String customerName, DateTime asOfDate, pw.Font font, bool hasCarryOver) {
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
          '顧客名: $customerName',
          style: pw.TextStyle(font: font, fontSize: 14),
        ),
        pw.Text(
          '作成日: ${_dateFormat.format(asOfDate)}',
          style: pw.TextStyle(font: font, fontSize: 12),
        ),
        if (hasCarryOver)
          pw.Text(
            '※先月の繰越分を含みます',
            style: pw.TextStyle(font: font, fontSize: 10, color: PdfColors.orange800),
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

  pw.Widget _buildDocumentTable(List<DocumentModel> documents, pw.Font font) {
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
            _tableCell('伝票番号', font, isHeader: true),
            _tableCell('発行日', font, isHeader: true),
            _tableCell('請求額', font, isHeader: true, alignRight: true),
            _tableCell('入金済', font, isHeader: true, alignRight: true),
            _tableCell('残高', font, isHeader: true, alignRight: true),
          ],
        ),
        // データ行
        ...documents.map((doc) {
          final remaining = doc.total - (doc.receivedAmount ?? 0);
          return pw.TableRow(
            children: [
              _tableCell(doc.documentNumber, font),
              _tableCell(_dateFormat.format(doc.date), font),
              _tableCell('¥${_currencyFormat.format(doc.total)}', font, alignRight: true),
              _tableCell('¥${_currencyFormat.format(doc.receivedAmount ?? 0)}', font, alignRight: true),
              _tableCell(
                '¥${_currencyFormat.format(remaining)}',
                font,
                alignRight: true,
                isBold: remaining > 0,
              ),
            ],
          );
        }),
      ],
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
