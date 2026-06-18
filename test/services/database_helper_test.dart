import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:h_1_core/services/database_helper.dart';
import 'package:h_1_core/services/database/database_schema_core.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    DatabaseHelper.testDatabase =
        await DatabaseHelper.createFreshDatabase(inMemoryDatabasePath);
  });

  tearDown(() async {
    await DatabaseHelper.testDatabase?.close();
    DatabaseHelper.testDatabase = null;
  });

  group('DatabaseHelper', () {
    test('init creates core tables', () async {
      final helper = DatabaseHelper();
      final db = await helper.database;
      final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' ORDER BY name",
      );
      final tableNames = tables.map((t) => t['name'] as String).toList();
      expect(tableNames, contains('activity_logs'));
      expect(tableNames, contains('hash_chain'));
      expect(tableNames, contains('electronic_bookkeeping'));
      expect(tableNames, contains('sync_log'));
      expect(tableNames, contains('pdf_output_history'));
      expect(tableNames, contains('email_send_history'));
    });

    test('hash_chain table has correct columns', () async {
      final helper = DatabaseHelper();
      final db = await helper.database;
      final columns = await db.rawQuery('PRAGMA table_info(hash_chain)');
      final colNames = columns.map((c) => c['name'] as String).toList();
      expect(colNames, contains('id'));
      expect(colNames, contains('document_type'));
      expect(colNames, contains('document_id'));
      expect(colNames, contains('content_hash'));
      expect(colNames, contains('previous_hash'));
      expect(colNames, contains('created_at'));
    });

    test('electronic_bookkeeping table has correct columns', () async {
      final helper = DatabaseHelper();
      final db = await helper.database;
      final columns =
          await db.rawQuery('PRAGMA table_info(electronic_bookkeeping)');
      final colNames = columns.map((c) => c['name'] as String).toList();
      expect(colNames, contains('id'));
      expect(colNames, contains('document_type'));
      expect(colNames, contains('document_id'));
      expect(colNames, contains('pdf_json'));
      expect(colNames, contains('content_hash'));
      expect(colNames, contains('previous_hash'));
      expect(colNames, contains('created_at'));
    });

    test('database version is set correctly', () async {
      final helper = DatabaseHelper();
      final db = await helper.database;
      expect(await db.getVersion(), 7);
    });

    test('database path is valid', () async {
      final helper = DatabaseHelper();
      final db = await helper.database;
      expect(db.path, isNotEmpty);
    });
  });
}
