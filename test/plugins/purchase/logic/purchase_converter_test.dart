import 'package:flutter_test/flutter_test.dart';
import 'package:h_1_core/plugins/purchase/models/purchase_model.dart';

PurchaseType? nextPurchaseType(PurchaseType current) {
  return switch (current) {
    PurchaseType.order => PurchaseType.receipt,
    PurchaseType.receipt => PurchaseType.payment,
    PurchaseType.return_ => null,
    PurchaseType.payment => null,
  };
}

void main() {
  group('nextPurchaseType', () {
    test('発注→入荷', () {
      expect(nextPurchaseType(PurchaseType.order), PurchaseType.receipt);
    });

    test('入荷→支払', () {
      expect(nextPurchaseType(PurchaseType.receipt), PurchaseType.payment);
    });

    test('返品→null（変換不可）', () {
      expect(nextPurchaseType(PurchaseType.return_), isNull);
    });

    test('支払→null（変換不可）', () {
      expect(nextPurchaseType(PurchaseType.payment), isNull);
    });
  });
}
