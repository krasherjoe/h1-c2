import 'package:flutter_test/flutter_test.dart';
import 'package:crypto/crypto.dart' as crypto;
import 'dart:convert';
import 'package:h_1_core/services/hash_utils.dart';

void main() {
  group('calculateSha256', () {
    test('空文字列のハッシュ', () {
      final hash = HashUtils.calculateSha256('');
      final expected = crypto.sha256.convert(utf8.encode('')).toString();
      expect(hash, expected);
    });

    test('同一入力は同一ハッシュ', () {
      final a = HashUtils.calculateSha256('hello');
      final b = HashUtils.calculateSha256('hello');
      expect(a, b);
    });

    test('異なる入力は異なるハッシュ', () {
      final a = HashUtils.calculateSha256('hello');
      final b = HashUtils.calculateSha256('world');
      expect(a, isNot(b));
    });
  });

  group('calculateDocumentHash', () {
    test('基本ドキュメントのハッシュが一貫している', () {
      final hash1 = HashUtils.calculateDocumentHash(
        id: 'doc1',
        documentType: 'invoice',
        customerId: 'cust1',
        customerName: '顧客A',
        documentNumber: 'INV-001',
        date: '2026-06-16',
        total: 10000,
        status: 'draft',
        includeTax: true,
        taxRate: 0.1,
      );
      final hash2 = HashUtils.calculateDocumentHash(
        id: 'doc1',
        documentType: 'invoice',
        customerId: 'cust1',
        customerName: '顧客A',
        documentNumber: 'INV-001',
        date: '2026-06-16',
        total: 10000,
        status: 'draft',
        includeTax: true,
        taxRate: 0.1,
      );
      expect(hash1, hash2);
    });

    test('異なる金額は異なるハッシュ', () {
      final hash1 = HashUtils.calculateDocumentHash(
        id: 'doc1', documentType: 'invoice', customerId: 'c1',
        customerName: '顧客A', documentNumber: 'INV-001', date: '2026-06-16',
        total: 10000, status: 'draft', includeTax: true, taxRate: 0.1,
      );
      final hash2 = HashUtils.calculateDocumentHash(
        id: 'doc1', documentType: 'invoice', customerId: 'c1',
        customerName: '顧客A', documentNumber: 'INV-001', date: '2026-06-16',
        total: 20000, status: 'draft', includeTax: true, taxRate: 0.1,
      );
      expect(hash1, isNot(hash2));
    });

    test('itemを含むハッシュ', () {
      final hash = HashUtils.calculateDocumentHash(
        id: 'doc1', documentType: 'invoice', customerId: 'c1',
        customerName: '顧客A', documentNumber: 'INV-001', date: '2026-06-16',
        total: 10000, status: 'draft', includeTax: true, taxRate: 0.1,
        items: [
          {'productId': 'p1', 'productName': '商品A', 'maker': '', 'productCode': '', 'quantity': '1', 'unitPrice': '10000', 'discountAmount': '', 'discountRate': '', 'notes': ''},
        ],
      );
      expect(hash.length, 64);
    });

    test('previousHashを含むチェーン', () {
      final prev = HashUtils.calculateSha256('prev_data');
      final hash = HashUtils.calculateDocumentHash(
        id: 'doc1', documentType: 'invoice', customerId: 'c1',
        customerName: '顧客A', documentNumber: 'INV-001', date: '2026-06-16',
        total: 10000, status: 'draft', includeTax: true, taxRate: 0.1,
        previousHash: prev,
      );
      expect(hash.length, 64);
    });
  });

  group('verifyHashChain', () {
    test('正常なチェーンはtrue', () {
      const input = 'test_data';
      final hash = HashUtils.calculateSha256(input);
      final result = HashUtils.verifyHashChain(
        currentHash: hash,
        currentInput: input,
      );
      expect(result, true);
    });

    test('改ざんされたハッシュはfalse', () {
      const input = 'test_data';
      final result = HashUtils.verifyHashChain(
        currentHash: 'invalid_hash',
        currentInput: input,
      );
      expect(result, false);
    });

    test('previousHash一致でtrue', () {
      const input = 'v2_data';
      final hash = HashUtils.calculateSha256(input);
      const prev = 'prev_hash_value';
      final result = HashUtils.verifyHashChain(
        currentHash: hash,
        currentInput: input,
        actualPreviousHash: prev,
        expectedPreviousHash: prev,
      );
      expect(result, true);
    });

    test('previousHash不一致でfalse', () {
      const input = 'v2_data';
      final hash = HashUtils.calculateSha256(input);
      final result = HashUtils.verifyHashChain(
        currentHash: hash,
        currentInput: input,
        actualPreviousHash: 'actual_prev',
        expectedPreviousHash: 'expected_prev',
      );
      expect(result, false);
    });
  });

  group('verifyCustomerIntegrity', () {
    test('正しいデータでtrue', () {
      final hash = HashUtils.calculateCustomerHash(
        id: 'c1', displayName: '顧客A', formalName: '株式会社A',
        title: 1, email: 'test@example.com',
      );
      final ok = HashUtils.verifyCustomerIntegrity(
        contentHash: hash,
        id: 'c1', displayName: '顧客A', formalName: '株式会社A',
        title: 1, email: 'test@example.com',
      );
      expect(ok, true);
    });

    test('データ改ざんでfalse', () {
      final hash = HashUtils.calculateCustomerHash(
        id: 'c1', displayName: '顧客A', formalName: '株式会社A',
        title: 1,
      );
      final ok = HashUtils.verifyCustomerIntegrity(
        contentHash: hash,
        id: 'c1', displayName: '改ざんされた名前', formalName: '株式会社A',
        title: 1,
      );
      expect(ok, false);
    });
  });

  group('verifyProductIntegrity', () {
    test('正しいデータでtrue', () {
      final hash = HashUtils.calculateProductHash(
        id: 'p1', name: '商品A', defaultUnitPrice: 1000, wholesalePrice: 800,
      );
      final ok = HashUtils.verifyProductIntegrity(
        contentHash: hash,
        id: 'p1', name: '商品A', defaultUnitPrice: 1000, wholesalePrice: 800,
      );
      expect(ok, true);
    });

    test('価格改ざんでfalse', () {
      final hash = HashUtils.calculateProductHash(
        id: 'p1', name: '商品A', defaultUnitPrice: 1000, wholesalePrice: 800,
      );
      final ok = HashUtils.verifyProductIntegrity(
        contentHash: hash,
        id: 'p1', name: '商品A', defaultUnitPrice: 2000, wholesalePrice: 800,
      );
      expect(ok, false);
    });
  });

  group('calculateCustomerHash', () {
    test('email2/email3はハッシュ計算対象外', () {
      final hash = HashUtils.calculateCustomerHash(
        id: 'c1', displayName: '顧客A', formalName: '株式会社A',
        title: 1, email: 'main@example.com',
      );
      expect(hash.length, 64);
    });
  });

  group('calculateProductHash', () {
    test('バーコードを含むハッシュ', () {
      final hash = HashUtils.calculateProductHash(
        id: 'p1', name: '商品A', defaultUnitPrice: 1000, wholesalePrice: 800,
        barcode: '4901234567890',
      );
      expect(hash.length, 64);
    });
  });
}
