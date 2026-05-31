import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'database_helper.dart';

class LegacyMigrator {
  static const String _legacyDbName = '販売アシスト 1 号.db';
  static const String _coreDbName = 'h1_core.db';

  static Future<bool> hasLegacyDatabase() async {
    try {
      final legacyPath = await _getLegacyDbPath();
      if (legacyPath == null) return false;
      return await File(legacyPath).exists();
    } catch (e) {
      debugPrint('[Migrator] レガシーDB確認エラー: $e');
      return false;
    }
  }

  static Future<String?> _getLegacyDbPath() async {
    try {
      if (Platform.isAndroid) {
        final dir = Directory('/storage/emulated/0/Documents/販売アシスト 1 号');
        final path = p.join(dir.path, _legacyDbName);
        if (await File(path).exists()) return path;
      }
      final dir = await getApplicationDocumentsDirectory();
      final path = p.join(dir.path, _legacyDbName);
      if (await File(path).exists()) return path;
      return null;
    } catch (e) {
      debugPrint('[Migrator] レガシーDBパス取得エラー: $e');
      return null;
    }
  }

  static Future<MigrateResult> migrate() async {
    final legacyPath = await _getLegacyDbPath();
    if (legacyPath == null) {
      return MigrateResult(success: false, message: 'レガシーデータベースが見つかりません');
    }

    try {
      final legacyDb = await openDatabase(legacyPath, readOnly: true);
      final coreDb = await DatabaseHelper().database;

      int customers = 0, products = 0, invoices = 0;

      try {
        customers = await _migrateTable(legacyDb, coreDb, 'customers', 'id');
        products = await _migrateTable(legacyDb, coreDb, 'products', 'id');
        invoices = await _migrateTable(legacyDb, coreDb, 'invoices', 'id');
        await _migrateTable(legacyDb, coreDb, 'invoice_items', 'id');
        await _migrateTable(legacyDb, coreDb, 'product_categories', 'id');
        await _migrateTable(legacyDb, coreDb, 'suppliers', 'id');
        await _migrateTable(legacyDb, coreDb, 'company_info', 'id');
        await _migrateTable(legacyDb, coreDb, 'payment_schedules', 'id');
      } finally {
        await legacyDb.close();
      }

      return MigrateResult(
        success: true,
        message: '移行完了: 顧客$customers件, 商品$products件, 請求書$invoices件',
      );
    } catch (e) {
      return MigrateResult(success: false, message: '移行エラー: $e');
    }
  }

  static Future<int> _migrateTable(Database src, Database dst, String table, String idColumn) async {
    try {
      final rows = await src.query(table);
      if (rows.isEmpty) return 0;

      int count = 0;
      for (final row in rows) {
        try {
          await dst.insert(table, row, conflictAlgorithm: ConflictAlgorithm.ignore);
          count++;
        } catch (e) {
          debugPrint('[Migrator] $table: 行スキップ ($e)');
        }
      }
      return count;
    } catch (e) {
      debugPrint('[Migrator] $table 移行エラー: $e');
      return 0;
    }
  }
}

class MigrateResult {
  final bool success;
  final String message;
  const MigrateResult({required this.success, required this.message});
}
