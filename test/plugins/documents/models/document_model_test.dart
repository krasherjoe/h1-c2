import 'package:flutter_test/flutter_test.dart';
import 'package:h_1_core/plugins/documents/models/document_model.dart';

void main() {
  group('DocumentType', () {
    test('labelが正しい', () {
      expect(DocumentType.estimation.label, '見積');
      expect(DocumentType.order.label, '受注');
      expect(DocumentType.delivery.label, '納品');
      expect(DocumentType.invoice.label, '請求');
      expect(DocumentType.receipt.label, '領収');
    });
  });

  group('documentTypeFromString', () {
    test('正しい文字列から変換', () {
      expect(documentTypeFromString('invoice'), DocumentType.invoice);
      expect(documentTypeFromString('receipt'), DocumentType.receipt);
      expect(documentTypeFromString('estimation'), DocumentType.estimation);
      expect(documentTypeFromString('order'), DocumentType.order);
      expect(documentTypeFromString('delivery'), DocumentType.delivery);
    });

    test('不明な文字列はnull', () {
      expect(documentTypeFromString('unknown'), isNull);
      expect(documentTypeFromString(''), isNull);
    });
  });
}
