import 'package:flutter_test/flutter_test.dart';
import 'package:h_1_core/plugins/documents/models/document_model.dart';

DocumentModel _baseModel({
  List<DocumentItem> items = const [],
  int? totalDiscountAmount,
  double? totalDiscountRate,
  String? priceAdjustmentType,
  int? priceAdjustmentUnit,
  bool attachArReport = false,
}) {
  return DocumentModel(
    id: 'test-id',
    documentType: DocumentType.invoice,
    customerId: 'cust-1',
    customerName: 'テスト株式会社',
    documentNumber: 'INV-001',
    date: DateTime(2026, 6, 23),
    total: 10000,
    status: 'confirmed',
    items: items,
    totalDiscountAmount: totalDiscountAmount,
    totalDiscountRate: totalDiscountRate,
    priceAdjustmentType: priceAdjustmentType,
    priceAdjustmentUnit: priceAdjustmentUnit,
    attachArReport: attachArReport,
  );
}

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

  group('DocumentModel.attachArReport', () {
    test('デフォルト値がfalseであること', () {
      final doc = DocumentModel(
        id: 'id',
        documentType: DocumentType.invoice,
        customerId: 'c1',
        customerName: 'n',
        documentNumber: '001',
        date: DateTime.now(),
      );
      expect(doc.attachArReport, false);
    });

    test('toMapでattach_ar_reportが1/0で保存される', () {
      final docFalse = _baseModel(attachArReport: false);
      final docTrue = _baseModel(attachArReport: true);

      expect(docFalse.toMap()['attach_ar_report'], 0);
      expect(docTrue.toMap()['attach_ar_report'], 1);
    });

    test('fromMapでattach_ar_reportが正しく復元される', () {
      final mapWithTrue = <String, dynamic>{
        'id': 'id',
        'document_type': 'invoice',
        'customer_id': 'c1',
        'customer_name': 'n',
        'document_number': '001',
        'date': '2026-06-23',
        'total': 0,
        'status': 'draft',
        'include_tax': 0,
        'tax_rate': 0.1,
        'is_locked': 0,
        'version': 1,
        'is_current': 1,
        'attach_ar_report': 1,
      };
      final mapWithFalse = <String, dynamic>{...mapWithTrue, 'attach_ar_report': 0};

      expect(DocumentModel.fromMap(mapWithTrue).attachArReport, true);
      expect(DocumentModel.fromMap(mapWithFalse).attachArReport, false);
    });

    test('fromMapでattach_ar_reportがnullの場合はfalse', () {
      final map = <String, dynamic>{
        'id': 'id',
        'document_type': 'invoice',
        'customer_id': 'c1',
        'customer_name': 'n',
        'document_number': '001',
        'date': '2026-06-23',
        'total': 0,
        'status': 'draft',
        'include_tax': 0,
        'tax_rate': 0.1,
        'is_locked': 0,
        'version': 1,
        'is_current': 1,
      };
      expect(DocumentModel.fromMap(map).attachArReport, false);
    });
  });

  group('DocumentModel.priceAdjustmentDiscount', () {
    test('priceAdjustmentType/Unitがnull時は0を返す', () {
      final doc = _baseModel(
        items: [DocumentItem(id: 'i1', productId: 'p1', productName: '商品', quantity: 10, unitPrice: 1000)],
      );
      expect(doc.priceAdjustmentDiscount, 0);
    });

    test('round_downで正しく端数切捨てされる', () {
      // subtotal = 10 * 1000 = 10000, unit=100
      // 10000 ~/ 100 * 100 = 10000 → discount = 0
      // Let's use 10 * 1234 = 12340
      final doc = _baseModel(
        items: [DocumentItem(id: 'i1', productId: 'p1', productName: '商品', quantity: 10, unitPrice: 1234)],
        priceAdjustmentType: 'round_down',
        priceAdjustmentUnit: 100,
      );
      // subtotal = 12340, _regularDiscount = 0, base = 12340
      // adjustedTotal = (12340 ~/ 100) * 100 = 12300
      // discount = 12340 - 12300 = 40
      expect(doc.priceAdjustmentDiscount, 40);
    });

    test('round_upで正しく端数切上げされる', () {
      final doc = _baseModel(
        items: [DocumentItem(id: 'i1', productId: 'p1', productName: '商品', quantity: 10, unitPrice: 1234)],
        priceAdjustmentType: 'round_up',
        priceAdjustmentUnit: 100,
      );
      // subtotal = 12340, base = 12340
      // adjustedTotal = ((12340 + 100 - 1) ~/ 100) * 100 = (12439 ~/ 100) * 100 = 12400
      // discount = 12340 - 12400 = -60
      expect(doc.priceAdjustmentDiscount, -60);
    });

    test('round_nearestで正しく端数四捨五入される', () {
      final doc = _baseModel(
        items: [DocumentItem(id: 'i1', productId: 'p1', productName: '商品', quantity: 10, unitPrice: 1234)],
        priceAdjustmentType: 'round_nearest',
        priceAdjustmentUnit: 100,
      );
      // subtotal = 12340, base = 12340
      // adjustedTotal = ((12340 + 50) ~/ 100) * 100 = (12390 ~/ 100) * 100 = 12300
      // discount = 12340 - 12300 = 40
      expect(doc.priceAdjustmentDiscount, 40);
    });

    test('round_nearestで50端は切り上げ', () {
      final doc = _baseModel(
        items: [DocumentItem(id: 'i1', productId: 'p1', productName: '商品', quantity: 10, unitPrice: 1250)],
        priceAdjustmentType: 'round_nearest',
        priceAdjustmentUnit: 100,
      );
      // subtotal = 12500, base = 12500
      // adjustedTotal = ((12500 + 50) ~/ 100) * 100 = (12550 ~/ 100) * 100 = 12500
      // discount = 12500 - 12500 = 0
      expect(doc.priceAdjustmentDiscount, 0);
    });

    test('manualで正しく値が返される', () {
      final doc = _baseModel(
        items: [DocumentItem(id: 'i1', productId: 'p1', productName: '商品', quantity: 10, unitPrice: 1000)],
        priceAdjustmentType: 'manual',
        priceAdjustmentUnit: 123,
      );
      expect(doc.priceAdjustmentDiscount, 123);
    });

    test('regularDiscountとpriceAdjustmentが合算される', () {
      // item-level discount あり
      final doc = _baseModel(
        items: [
          DocumentItem(
            id: 'i1', productId: 'p1', productName: '商品',
            quantity: 10, unitPrice: 1000,
            discountAmount: 500, // subtotal = 10000 - 500 = 9500
          ),
        ],
        priceAdjustmentType: 'round_down',
        priceAdjustmentUnit: 100,
      );
      // subtotal = 9500 (because discountAmount reduces subtotal in DocumentItem)
      // No, wait: DocumentItem.subtotal = base - discountAmount = 10000 - 500 = 9500
      // So doc.subtotal = 9500
      // _regularDiscount: items.fold: item discountAmount=500 > 0 so return sum+500 = 500
      // base = subtotal - _regularDiscount = 9500 - 500 = 9000
      // adjustedTotal = (9000 ~/ 100) * 100 = 9000
      // priceAdjustmentDiscount = 9000 - 9000 = 0
      // discountAmount = _regularDiscount + priceAdjustmentDiscount = 500 + 0 = 500
      expect(doc.priceAdjustmentDiscount, 0);
      expect(doc.discountAmount, 500);
    });
  });
}
