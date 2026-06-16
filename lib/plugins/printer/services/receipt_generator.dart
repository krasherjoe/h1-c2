import '../../documents/models/document_model.dart';

class ReceiptGenerator {
  static const _lineWidth = 32;

  static List<String> generate(DocumentModel doc) {
    final lines = <String>[];
    final company = doc.customerName;

    lines.addAll([
      '',
      '    ${doc.documentType.label}',
      '=' * _lineWidth,
      ' ${doc.date.year}/${doc.date.month}/${doc.date.day}',
      ' ${doc.documentNumber}',
      ' ${doc.customerName}',
      '-' * _lineWidth,
    ]);

    for (final item in doc.items) {
      final name = item.productName.length > 18 ? '${item.productName.substring(0, 18)}..' : item.productName;
      final qty = item.quantity.toStringAsFixed(item.quantity == item.quantity.roundToDouble() ? 0 : 1);
      final price = '¥${item.unitPrice}';
      final subtotal = '¥${item.subtotal}';
      lines.add(' $name');
      lines.add('  ${qty}x$price  $subtotal');
    }

    lines.addAll([
      '-' * _lineWidth,
      ' 小計:   ¥${doc.subtotal}',
      if (doc.discountAmount > 0) ' 値引き: -¥${doc.discountAmount}',
      ' 消費税:  ¥${doc.tax}',
      '=' * _lineWidth,
      ' 合計:   ¥${doc.total}',
      '=' * _lineWidth,
      '',
      ' ご利用ありがとうございます',
      '',
      ' 署名: _________________',
      '',
      '',
    ]);
    return lines;
  }
}
