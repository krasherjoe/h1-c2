import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/shipping_label_model.dart';
import '../models/tracking_model.dart';

/// 送り状印刷サービス
class ShippingLabelPrinter {
  Future<void> printLabel(ShippingLabel label) async {
    final pdf = await _generatePdf(label);
    await Printing.layoutPdf(onLayout: (format) => pdf.save());
  }

  Future<void> savePdf(ShippingLabel label) async {
    final pdf = await _generatePdf(label);
    await Printing.sharePdf(bytes: await pdf.save(), filename: 'shipping_label_${label.trackingNumber}.pdf');
  }

  Future<pw.Document> _generatePdf(ShippingLabel label) async {
    switch (label.carrier) {
      case Carrier.yamato:
        return _generateYamatoLabel(label);
      case Carrier.sagawa:
        return _generateSagawaLabel(label);
      case Carrier.jpPost:
        return _generateJpPostLabel(label);
      default:
        return _generateGenericLabel(label);
    }
  }

  Future<pw.Document> _generateYamatoLabel(ShippingLabel label) async {
    final pdf = pw.Document();
    pdf.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      build: (context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('クロネコヤマト', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
          pw.Text('送り状', style: pw.TextStyle(fontSize: 18)),
          pw.SizedBox(height: 20),
          pw.Text('追跡番号：${label.trackingNumber}', style: pw.TextStyle(fontSize: 16)),
          pw.SizedBox(height: 20),
          pw.Text('送付者', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          pw.Text(label.senderName),
          pw.Text('〒${label.senderZip}'),
          pw.Text(label.senderAddress),
          pw.Text('TEL:${label.senderPhone}'),
          pw.SizedBox(height: 20),
          pw.Text('宛先', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          pw.Text(label.recipientName),
          if (label.recipientCompany != null) pw.Text(label.recipientCompany!),
          pw.Text('〒${label.recipientZip}'),
          pw.Text(label.recipientAddress),
          pw.Text('TEL:${label.recipientPhone}'),
          pw.SizedBox(height: 20),
          pw.Text('内容品：${label.contents ?? ''}'),
          pw.Text('個数：${label.quantity ?? 0}個'),
          pw.Text('重量：${label.weight ?? 0}g'),
          if (label.serviceType != null) pw.Text('サービス：${label.serviceType}'),
          if (label.codAmount != null) pw.Text('代引金額：${label.codAmount}円'),
        ],
      ),
    ));
    return pdf;
  }

  Future<pw.Document> _generateSagawaLabel(ShippingLabel label) async {
    final pdf = pw.Document();
    pdf.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      build: (context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('佐川急便', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
          pw.Text('送り状', style: pw.TextStyle(fontSize: 18)),
          pw.SizedBox(height: 20),
          pw.Text('追跡番号：${label.trackingNumber}', style: pw.TextStyle(fontSize: 16)),
          pw.SizedBox(height: 20),
          pw.Text('送付者', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          pw.Text(label.senderName),
          pw.Text('〒${label.senderZip}'),
          pw.Text(label.senderAddress),
          pw.Text('TEL:${label.senderPhone}'),
          pw.SizedBox(height: 20),
          pw.Text('宛先', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          pw.Text(label.recipientName),
          if (label.recipientCompany != null) pw.Text(label.recipientCompany!),
          pw.Text('〒${label.recipientZip}'),
          pw.Text(label.recipientAddress),
          pw.Text('TEL:${label.recipientPhone}'),
          pw.SizedBox(height: 20),
          pw.Text('内容品：${label.contents ?? ''}'),
          pw.Text('個数：${label.quantity ?? 0}個'),
          pw.Text('重量：${label.weight ?? 0}g'),
          if (label.serviceType != null) pw.Text('サービス：${label.serviceType}'),
          if (label.codAmount != null) pw.Text('代引金額：${label.codAmount}円'),
        ],
      ),
    ));
    return pdf;
  }

  Future<pw.Document> _generateJpPostLabel(ShippingLabel label) async {
    final pdf = pw.Document();
    pdf.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      build: (context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('日本郵便', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
          pw.Text('送り状', style: pw.TextStyle(fontSize: 18)),
          pw.SizedBox(height: 20),
          pw.Text('追跡番号：${label.trackingNumber}', style: pw.TextStyle(fontSize: 16)),
          pw.SizedBox(height: 20),
          pw.Text('送付者', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          pw.Text(label.senderName),
          pw.Text('〒${label.senderZip}'),
          pw.Text(label.senderAddress),
          pw.Text('TEL:${label.senderPhone}'),
          pw.SizedBox(height: 20),
          pw.Text('宛先', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          pw.Text(label.recipientName),
          if (label.recipientCompany != null) pw.Text(label.recipientCompany!),
          pw.Text('〒${label.recipientZip}'),
          pw.Text(label.recipientAddress),
          pw.Text('TEL:${label.recipientPhone}'),
          pw.SizedBox(height: 20),
          pw.Text('内容品：${label.contents ?? ''}'),
          pw.Text('個数：${label.quantity ?? 0}個'),
          pw.Text('重量：${label.weight ?? 0}g'),
          if (label.serviceType != null) pw.Text('サービス：${label.serviceType}'),
          if (label.codAmount != null) pw.Text('代引金額：${label.codAmount}円'),
        ],
      ),
    ));
    return pdf;
  }

  Future<pw.Document> _generateGenericLabel(ShippingLabel label) async {
    final pdf = pw.Document();
    pdf.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      build: (context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('送り状', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 20),
          pw.Text('追跡番号：${label.trackingNumber}', style: pw.TextStyle(fontSize: 16)),
          pw.Text('宅配便会社：${label.carrier.displayName}', style: pw.TextStyle(fontSize: 16)),
          pw.SizedBox(height: 20),
          pw.Text('送付者', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          pw.Text(label.senderName),
          pw.Text('〒${label.senderZip}'),
          pw.Text(label.senderAddress),
          pw.Text('TEL:${label.senderPhone}'),
          pw.SizedBox(height: 20),
          pw.Text('宛先', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          pw.Text(label.recipientName),
          if (label.recipientCompany != null) pw.Text(label.recipientCompany!),
          pw.Text('〒${label.recipientZip}'),
          pw.Text(label.recipientAddress),
          pw.Text('TEL:${label.recipientPhone}'),
          pw.SizedBox(height: 20),
          pw.Text('内容品：${label.contents ?? ''}'),
          pw.Text('個数：${label.quantity ?? 0}個'),
          pw.Text('重量：${label.weight ?? 0}g'),
          if (label.serviceType != null) pw.Text('サービス：${label.serviceType}'),
          if (label.codAmount != null) pw.Text('代引金額：${label.codAmount}円'),
        ],
      ),
    ));
    return pdf;
  }
}
