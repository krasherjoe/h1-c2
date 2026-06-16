import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:h_1_core/services/database_helper.dart';
import 'package:h_1_core/plugins/cases/services/case_repository.dart';

void main() {
  late DatabaseHelper dbHelper;

  setUpAll(() {
    sqfliteFfiInit();
  });

  setUp(() async {
    dbHelper = DatabaseHelper();
    DatabaseHelper.testDatabase = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    final db = DatabaseHelper.testDatabase!;

    await db.execute('''
      CREATE TABLE IF NOT EXISTS cases (
        id TEXT PRIMARY KEY, type TEXT NOT NULL, status INTEGER DEFAULT 0,
        priority INTEGER DEFAULT 0, reference_type TEXT, reference_id TEXT,
        title TEXT NOT NULL, amount INTEGER, description TEXT,
        assignee TEXT, due_date TEXT,
        created_at TEXT NOT NULL, escalated_at TEXT, resolved_at TEXT, notes TEXT
      )''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS invoices (
        id TEXT NOT NULL, customer_id TEXT NOT NULL, date TEXT NOT NULL,
        notes TEXT, subject TEXT, total_amount INTEGER, tax_rate REAL DEFAULT 0.10,
        document_type TEXT DEFAULT 'invoice', order_status TEXT DEFAULT 'draft',
        promised_date INTEGER, fulfilled_date INTEGER, source_document_id TEXT,
        linked_delivery_id TEXT, linked_invoice_id TEXT,
        customer_formal_name TEXT, is_synced INTEGER DEFAULT 0,
        updated_at TEXT NOT NULL, latitude REAL, longitude REAL,
        terminal_id TEXT DEFAULT 'T1', is_draft INTEGER DEFAULT 0,
        is_locked INTEGER DEFAULT 0, total_discount_amount INTEGER DEFAULT 0,
        total_discount_rate REAL DEFAULT 0, include_tax INTEGER DEFAULT 1,
        is_tax_inclusive_mode INTEGER DEFAULT 0, payment_status TEXT DEFAULT 'unpaid',
        received_amount INTEGER DEFAULT 0, project_id TEXT,
        is_test_document INTEGER DEFAULT 0, printed_at TEXT, email_sent_at TEXT,
        email_sent_to TEXT, is_receipt_issued INTEGER DEFAULT 0,
        receipt_issued_at TEXT, meta_json TEXT,
        PRIMARY KEY (id)
      )''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS invoice_items (
        id TEXT PRIMARY KEY, invoice_id TEXT NOT NULL,
        product_id TEXT, product_name TEXT NOT NULL, quantity REAL NOT NULL,
        unit_price INTEGER NOT NULL, tax_rate REAL DEFAULT 0.10, discount_amount INTEGER DEFAULT 0,
        discount_rate REAL DEFAULT 0, notes TEXT, sort_order INTEGER DEFAULT 0,
        FOREIGN KEY (invoice_id) REFERENCES invoices(id) ON DELETE CASCADE
      )''');
  });

  tearDown(() async {
    await DatabaseHelper.testDatabase?.close();
    DatabaseHelper.testDatabase = null;
  });

  group('CaseRepository.autoCreateFromOverdueInvoices', () {
    test('延滞請求書から案件が作成される', () async {
      final db = DatabaseHelper.testDatabase!;
      final now = DateTime.now();
      // 30日以上経過した未払い請求書
      await db.insert('invoices', {
        'id': 'inv1', 'customer_id': 'c1', 'date': now.subtract(const Duration(days: 40)).toIso8601String().substring(0, 10),
        'customer_formal_name': 'テスト株式会社', 'subject': '工事費', 'total_amount': 100000,
        'payment_status': 'unpaid', 'received_amount': 0, 'is_draft': 0,
        'updated_at': now.toIso8601String(),
      });
      // 新しい請求書（延滞ではない）
      await db.insert('invoices', {
        'id': 'inv2', 'customer_id': 'c1', 'date': now.subtract(const Duration(days: 5)).toIso8601String().substring(0, 10),
        'customer_formal_name': 'テスト株式会社', 'subject': '設計費', 'total_amount': 50000,
        'payment_status': 'unpaid', 'received_amount': 0, 'is_draft': 0,
        'updated_at': now.toIso8601String(),
      });
      // 既に支払済み
      await db.insert('invoices', {
        'id': 'inv3', 'customer_id': 'c2', 'date': now.subtract(const Duration(days: 60)).toIso8601String().substring(0, 10),
        'customer_formal_name': '株式会社B', 'subject': '材料費', 'total_amount': 200000,
        'payment_status': 'paid', 'received_amount': 200000, 'is_draft': 0,
        'updated_at': now.toIso8601String(),
      });
      // 下書き
      await db.insert('invoices', {
        'id': 'inv4', 'customer_id': 'c3', 'date': now.subtract(const Duration(days: 50)).toIso8601String().substring(0, 10),
        'customer_formal_name': '株式会社C', 'subject': 'その他', 'total_amount': 30000,
        'payment_status': 'unpaid', 'received_amount': 0, 'is_draft': 1,
        'updated_at': now.toIso8601String(),
      });

      final repo = CaseRepository();
      final created = await repo.autoCreateFromOverdueInvoices();

      // inv1（40日前, unpaid）のみ作成されるはず
      expect(created, 1);

      final cases = await db.query('cases');
      expect(cases.length, 1);
      expect(cases.first['reference_id'], 'inv1');
      expect(cases.first['type'], 'overdue');
      expect(cases.first['amount'], 100000);
    });

    test('既存案件がある場合は重複作成しない', () async {
      final db = DatabaseHelper.testDatabase!;
      final now = DateTime.now();
      await db.insert('invoices', {
        'id': 'inv1', 'customer_id': 'c1', 'date': now.subtract(const Duration(days: 40)).toIso8601String().substring(0, 10),
        'customer_formal_name': 'テスト株式会社', 'subject': '工事費', 'total_amount': 100000,
        'payment_status': 'unpaid', 'received_amount': 0, 'is_draft': 0,
        'updated_at': now.toIso8601String(),
      });
      await db.insert('cases', {
        'id': 'existing_case', 'type': 'overdue', 'status': 0, 'title': '既存案件',
        'reference_type': 'invoice', 'reference_id': 'inv1',
        'amount': 100000, 'created_at': now.toIso8601String(),
      });

      final repo = CaseRepository();
      final created = await repo.autoCreateFromOverdueInvoices();

      expect(created, 0);
      final cases = await db.query('cases');
      expect(cases.length, 1);
    });

    test('promised_dateが設定されている場合はそれを期限として使用', () async {
      final db = DatabaseHelper.testDatabase!;
      final now = DateTime.now();
      // promised_dateがない場合はdate+30日なのでまだ延滞ではない
      // promised_dateがある場合はそれを期限とする
      final pastDue = now.subtract(const Duration(days: 10));
      await db.insert('invoices', {
        'id': 'inv1', 'customer_id': 'c1', 'date': now.toIso8601String().substring(0, 10),
        'customer_formal_name': 'テスト株式会社', 'subject': '工事費', 'total_amount': 50000,
        'payment_status': 'unpaid', 'received_amount': 0, 'is_draft': 0,
        'promised_date': pastDue.millisecondsSinceEpoch,
        'updated_at': now.toIso8601String(),
      });

      final repo = CaseRepository();
      final created = await repo.autoCreateFromOverdueInvoices();

      expect(created, 1);
    });

    test('getOverdueInvoiceCount', () async {
      final db = DatabaseHelper.testDatabase!;
      final now = DateTime.now();
      await db.insert('invoices', {
        'id': 'inv1', 'customer_id': 'c1', 'date': now.subtract(const Duration(days: 40)).toIso8601String().substring(0, 10),
        'customer_formal_name': '顧客A', 'subject': '工事費', 'total_amount': 100000,
        'payment_status': 'unpaid', 'received_amount': 0, 'is_draft': 0,
        'updated_at': now.toIso8601String(),
      });
      await db.insert('invoices', {
        'id': 'inv2', 'customer_id': 'c1', 'date': now.subtract(const Duration(days: 35)).toIso8601String().substring(0, 10),
        'customer_formal_name': '顧客A', 'subject': '設計費', 'total_amount': 50000,
        'payment_status': 'partial', 'received_amount': 10000, 'is_draft': 0,
        'updated_at': now.toIso8601String(),
      });

      final repo = CaseRepository();
      final count = await repo.getOverdueInvoiceCount();

      expect(count, 2);
    });
  });
}
