import 'package:uuid/uuid.dart';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import '../database_helper.dart';
import 'otsukue_api_client.dart';
import '../../models/sync_record.dart';

class SyncManager {
  static final SyncManager _instance = SyncManager._internal();
  factory SyncManager() => _instance;
  SyncManager._internal();

  OtsukueApiClient? _client;
  bool _isSyncing = false;
  bool get isSyncing => _isSyncing;

  void configure({required String baseUrl, String? authToken}) {
    _client = OtsukueApiClient(baseUrl: baseUrl);
    if (authToken != null) _client!.setAuthToken(authToken);
  }

  /// テーブル変更をsync_queueに追加
  Future<void> queueChange({
    required String tableName,
    required String recordId,
    required String action,
    String? data,
  }) async {
    final db = await DatabaseHelper().database;
    await db.insert('sync_queue', {
      'id': const Uuid().v4(),
      'table_name': tableName,
      'record_id': recordId,
      'action': action,
      'data': data,
      'created_at': DateTime.now().toIso8601String(),
      'status': 'pending',
    });
  }

  /// 同期実行
  Future<SyncResult?> sync() async {
    if (_client == null || _isSyncing) return null;
    _isSyncing = true;

    try {
      final db = await DatabaseHelper().database;
      final pending = await db.query(
        'sync_queue',
        where: 'status = ?',
        whereArgs: ['pending'],
        orderBy: 'created_at ASC',
        limit: 100,
      );

      if (pending.isEmpty) return const SyncResult(synced: 0, failed: 0);

      final records = pending.map((r) => SyncRecord.fromMap(r)).toList();
      final result = await _client!.pushChanges(records);

      final now = DateTime.now().toIso8601String();
      for (final record in records) {
        await db.update(
          'sync_queue',
          {
            'status': result.failed > 0 ? 'failed' : 'synced',
            'synced_at': now,
          },
          where: 'id = ?',
          whereArgs: [record.id],
        );
      }

      _log('同期完了: synced=${result.synced}, failed=${result.failed}');
      return result;
    } catch (e) {
      _log('同期エラー: $e');
      return null;
    } finally {
      _isSyncing = false;
    }
  }

  /// お局様から変更を取得して適用
  Future<int> pullAndApply() async {
    if (_client == null) return 0;

    try {
      final db = await DatabaseHelper().database;
      final meta = await db.query('db_meta', where: "key = 'last_sync_at'");
      final lastSync = meta.isNotEmpty
          ? DateTime.parse(meta.first['value'] as String)
          : DateTime.now().subtract(const Duration(days: 7));

      final changes = await _client!.pullChanges(lastSync);
      if (changes.isEmpty) return 0;

      int applied = 0;
      for (final _ in changes) {
        // TODO: テーブル別にデータを適用
        applied++;
      }

      await db.insert('db_meta', {
        'key': 'last_sync_at',
        'value': DateTime.now().toIso8601String(),
      }, conflictAlgorithm: ConflictAlgorithm.replace);

      _log('プル完了: $applied 件適用');
      return applied;
    } catch (e) {
      _log('プルエラー: $e');
      return 0;
    }
  }

  void _log(String msg) {
    debugPrint('[SyncManager] $msg');
  }
}
