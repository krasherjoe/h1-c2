import 'package:flutter_test/flutter_test.dart';
import 'package:h_1_core/models/sync_record.dart';
import 'package:h_1_core/services/api/otsukue_api_client.dart';

void main() {
  group('SyncRecord Model', () {
    test('toMap/fromMap roundtrip', () {
      final now = DateTime.now();
      final record = SyncRecord(
        id: 'test-id',
        tableName: 'customers',
        recordId: 'customer-123',
        action: 'insert',
        data: '{"name":"Test"}',
        createdAt: now,
        status: 'pending',
      );

      final map = record.toMap();
      final restored = SyncRecord.fromMap(map);

      expect(restored.id, record.id);
      expect(restored.tableName, record.tableName);
      expect(restored.recordId, record.recordId);
      expect(restored.action, record.action);
      expect(restored.data, record.data);
      expect(restored.status, record.status);
    });

    test('fromMap handles null data and syncedAt', () {
      final map = <String, dynamic>{
        'id': 'id',
        'table_name': 'products',
        'record_id': 'prod-1',
        'action': 'update',
        'data': null,
        'created_at': DateTime.now().toIso8601String(),
        'synced_at': null,
        'status': 'pending',
      };

      final record = SyncRecord.fromMap(map);

      expect(record.data, isNull);
      expect(record.syncedAt, isNull);
    });

    test('defaults are correct', () {
      final record = SyncRecord(
        id: 'id',
        tableName: 'documents',
        recordId: 'doc-1',
        action: 'delete',
        createdAt: DateTime.now(),
      );

      expect(record.status, 'pending');
      expect(record.data, isNull);
      expect(record.syncedAt, isNull);
    });
  });

  group('SyncResult', () {
    test('holds values correctly', () {
      const result = SyncResult(synced: 5, failed: 2, conflicts: ['id-1']);
      expect(result.synced, 5);
      expect(result.failed, 2);
      expect(result.conflicts, ['id-1']);
    });

    test('default conflicts is empty', () {
      const result = SyncResult(synced: 0, failed: 0);
      expect(result.conflicts, isEmpty);
    });
  });
}
