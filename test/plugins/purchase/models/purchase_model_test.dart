import 'package:flutter_test/flutter_test.dart';
import 'package:h_1_core/plugins/purchase/models/purchase_model.dart';

void main() {
  group('PurchaseType', () {
    test('labelが正しい', () {
      expect(PurchaseType.order.label, '発注');
      expect(PurchaseType.receipt.label, '入荷');
      expect(PurchaseType.return_.label, '返品');
      expect(PurchaseType.payment.label, '支払');
    });
  });

  group('purchaseTypeFromString', () {
    test('正しい文字列から変換', () {
      expect(purchaseTypeFromString('order'), PurchaseType.order);
      expect(purchaseTypeFromString('receipt'), PurchaseType.receipt);
      expect(purchaseTypeFromString('return_'), PurchaseType.return_);
      expect(purchaseTypeFromString('payment'), PurchaseType.payment);
    });

    test('不明な文字列はnull', () {
      expect(purchaseTypeFromString('unknown'), isNull);
      expect(purchaseTypeFromString(''), isNull);
    });
  });

  group('PurchaseItem', () {
    test('subtotal計算', () {
      final item = PurchaseItem(
        id: 'i1', productId: 'p1', productName: '商品A',
        quantity: 3, unitPrice: 500,
      );
      expect(item.subtotal, 1500);
    });

    test('toMap/fromMap roundtrip', () {
      final item = PurchaseItem(
        id: 'i1', productId: 'p1', productName: '商品A',
        quantity: 2.5, unitPrice: 1000, taxRate: 0.1,
      );
      final map = item.toMap('purchase1');
      final restored = PurchaseItem.fromMap(map);
      expect(restored.id, item.id);
      expect(restored.productId, item.productId);
      expect(restored.productName, item.productName);
      expect(restored.quantity, item.quantity);
      expect(restored.unitPrice, item.unitPrice);
      expect(restored.taxRate, item.taxRate);
    });

    test('copyWith', () {
      final item = PurchaseItem(
        id: 'i1', productId: 'p1', productName: '商品A',
        quantity: 1, unitPrice: 500,
      );
      final copied = item.copyWith(quantity: 5);
      expect(copied.id, 'i1');
      expect(copied.quantity, 5);
      expect(copied.unitPrice, 500);
    });
  });

  group('PurchaseModel', () {
    final now = DateTime(2026, 6, 16);
    final model = PurchaseModel(
      id: 'p1', purchaseType: PurchaseType.order,
      supplierId: 's1', supplierName: '山田建材',
      documentNumber: 'PO-001', date: now,
      total: 50000, status: 'draft',
      items: [
        PurchaseItem(id: 'i1', productId: 'pr1', productName: '鉄筋材', quantity: 10, unitPrice: 5000),
      ],
    );

    test('titleはdocumentNumber', () {
      expect(model.title, 'PO-001');
    });

    test('titleは空なら(新規)', () {
      final empty = PurchaseModel(id: 'p2', purchaseType: PurchaseType.order, date: now);
      expect(empty.title, '(新規)');
    });

    test('subtitleはsupplierName', () {
      expect(model.subtitle, '山田建材');
    });

    test('badgeはpurchaseType.label', () {
      expect(model.badge, '発注');
    });

    test('isDraft/isConfirmed', () {
      expect(model.isDraft, true);
      expect(model.isConfirmed, false);
      final confirmed = model.copyWith(status: 'confirmed');
      expect(confirmed.isDraft, false);
      expect(confirmed.isConfirmed, true);
    });

    test('toMap/fromMap roundtrip', () {
      final map = model.toMap();
      final restored = PurchaseModel.fromMap(map, items: model.items);
      expect(restored.id, model.id);
      expect(restored.purchaseType, model.purchaseType);
      expect(restored.supplierName, model.supplierName);
      expect(restored.documentNumber, model.documentNumber);
      expect(restored.total, model.total);
      expect(restored.status, model.status);
      expect(restored.items.length, model.items.length);
    });

    test('copyWith', () {
      final copied = model.copyWith(total: 60000, status: 'confirmed');
      expect(copied.total, 60000);
      expect(copied.status, 'confirmed');
      expect(copied.documentNumber, 'PO-001');
    });
  });
}
