import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:h_1_core/services/database_helper.dart';
import 'package:h_1_core/services/sales_queue_repository.dart';
import 'package:h_1_core/models/sales_queue_model.dart';

void main() {
  late SalesQueueRepository repository;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    DatabaseHelper.testDatabase =
        await DatabaseHelper.createFreshDatabase(inMemoryDatabasePath);
    // sales_queue テーブルはv12マイグレーションで作成されるため、
    // 新規DB作成時は手動で作成する
    final db = DatabaseHelper.testDatabase!;
    await db.execute('''
      CREATE TABLE IF NOT EXISTS sales_queue (
        id TEXT PRIMARY KEY,
        project_id TEXT NOT NULL,
        document_id TEXT NOT NULL,
        delivery_date TEXT NOT NULL,
        total_amount INTEGER NOT NULL,
        customer_id TEXT,
        customer_name TEXT,
        status TEXT NOT NULL DEFAULT 'pending',
        created_at TEXT NOT NULL,
        processed_at TEXT,
        invoice_id TEXT,
        error_message TEXT
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_sales_queue_project ON sales_queue(project_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_sales_queue_status ON sales_queue(status)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_sales_queue_delivery_date ON sales_queue(delivery_date)',
    );
    repository = SalesQueueRepository();
  });

  tearDown(() async {
    await DatabaseHelper.testDatabase?.close();
    DatabaseHelper.testDatabase = null;
  });

  group('SalesQueueRepository.createEntry', () {
    test('エントリが正しく作成されること', () async {
      await repository.createEntry(
        projectId: 'project-1',
        documentId: 'doc-1',
        documentType: 'delivery',
        triggeredAt: DateTime(2026, 6, 23),
      );

      final entries = await repository.getPendingEntries();
      expect(entries.length, 1);
      expect(entries[0].projectId, 'project-1');
      expect(entries[0].documentId, 'doc-1');
      expect(entries[0].status, QueueStatus.pending);
      expect(entries[0].totalAmount, 0); // createEntry sets 0, updated later
    });

    test('複数エントリが作成できること', () async {
      await repository.createEntry(
        projectId: 'project-1',
        documentId: 'doc-1',
        documentType: 'delivery',
        triggeredAt: DateTime(2026, 6, 23),
      );
      await repository.createEntry(
        projectId: 'project-2',
        documentId: 'doc-2',
        documentType: 'delivery',
        triggeredAt: DateTime(2026, 6, 24),
      );

      final entries = await repository.getPendingEntries();
      expect(entries.length, 2);
    });
  });

  group('SalesQueueRepository.addEntry', () {
    test('エントリが正しく作成されること', () async {
      await repository.addEntry(
        projectId: 'project-1',
        documentId: 'doc-1',
        deliveryDate: DateTime(2026, 6, 23),
        totalAmount: 50000,
        customerId: 'cust-1',
        customerName: 'テスト株式会社',
      );

      final entries = await repository.getPendingEntries();
      expect(entries.length, 1);
      expect(entries[0].projectId, 'project-1');
      expect(entries[0].documentId, 'doc-1');
      expect(entries[0].totalAmount, 50000);
      expect(entries[0].customerId, 'cust-1');
      expect(entries[0].customerName, 'テスト株式会社');
      expect(entries[0].status, QueueStatus.pending);
    });
  });

  group('SalesQueueRepository.getPendingEntries', () {
    test('pendingエントリのみ取得できること', () async {
      // Create a pending entry
      await repository.createEntry(
        projectId: 'project-1',
        documentId: 'doc-1',
        documentType: 'delivery',
        triggeredAt: DateTime(2026, 6, 23),
      );

      // Create another and complete it
      await repository.createEntry(
        projectId: 'project-2',
        documentId: 'doc-2',
        documentType: 'delivery',
        triggeredAt: DateTime(2026, 6, 24),
      );
      final entries = await repository.getPendingEntries();
      await repository.updateStatus(entries[1].id, QueueStatus.completed);

      // Now only 1 pending should remain
      final pending = await repository.getPendingEntries();
      expect(pending.length, 1);
      expect(pending[0].projectId, 'project-1');
    });

    test('pendingエントリがない場合は空リスト', () async {
      final entries = await repository.getPendingEntries();
      expect(entries, isEmpty);
    });
  });

  group('SalesQueueRepository.updateStatus', () {
    test('ステータスが正しく更新されること', () async {
      await repository.createEntry(
        projectId: 'project-1',
        documentId: 'doc-1',
        documentType: 'delivery',
        triggeredAt: DateTime(2026, 6, 23),
      );

      final entries = await repository.getPendingEntries();
      expect(entries.length, 1);
      expect(entries[0].status, QueueStatus.pending);

      await repository.updateStatus(entries[0].id, QueueStatus.completed);

      final pending = await repository.getPendingEntries();
      expect(pending, isEmpty);

      // Verify using raw query
      final db = await DatabaseHelper().database;
      final result = await db.query(
        'sales_queue',
        where: 'id = ?',
        whereArgs: [entries[0].id],
      );
      expect(result.length, 1);
      expect(result[0]['status'], 'completed');
      expect(result[0]['processed_at'], isNotNull);
    });

    test('invoiceIdを指定してステータス更新できること', () async {
      await repository.createEntry(
        projectId: 'project-1',
        documentId: 'doc-1',
        documentType: 'delivery',
        triggeredAt: DateTime(2026, 6, 23),
      );

      final entries = await repository.getPendingEntries();
      await repository.updateStatus(
        entries[0].id,
        QueueStatus.completed,
        invoiceId: 'inv-001',
      );

      final db = await DatabaseHelper().database;
      final result = await db.query(
        'sales_queue',
        where: 'id = ?',
        whereArgs: [entries[0].id],
      );
      expect(result[0]['invoice_id'], 'inv-001');
    });

    test('errorMessageを指定してfailedにできること', () async {
      await repository.createEntry(
        projectId: 'project-1',
        documentId: 'doc-1',
        documentType: 'delivery',
        triggeredAt: DateTime(2026, 6, 23),
      );

      final entries = await repository.getPendingEntries();
      await repository.updateStatus(
        entries[0].id,
        QueueStatus.failed,
        errorMessage: 'API error',
      );

      final db = await DatabaseHelper().database;
      final result = await db.query(
        'sales_queue',
        where: 'id = ?',
        whereArgs: [entries[0].id],
      );
      expect(result[0]['status'], 'failed');
      expect(result[0]['error_message'], 'API error');
    });
  });
}
