import 'package:sqflite/sqflite.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DataMigrationService {
  static const _conversionDoneKey = 'conversion_v1_to_v2_done';

  /// マイグレーションが必要かチェック（DBごと）
  static Future<bool> needsConversion(Database db) async {
    final tables = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name='documents'",
    );
    if (tables.isEmpty) return false;

    final cols = await db.rawQuery('PRAGMA table_info(documents)');
    final isNewSchema = cols.any((c) => c['name'] == 'document_number');
    if (isNewSchema) return false;

    final rows = await db.rawQuery('SELECT COUNT(*) AS c FROM documents');
    return (rows.first['c'] as int? ?? 0) > 0;
  }

  /// 指定パスのDBファイルが oldh1 形式（core へ変換可能）かを判定する。
  ///
  /// - oldh1 形式: `documents` テーブルが存在し `document_number` カラムを持たず、
  ///   1件以上のレコードがある（= [needsConversion] が true）
  /// - core 形式 / 非SQLite / 空DB などは false（変換しても意味がないため一覧から除外）
  static Future<bool> isOldh1Db(String path) async {
    Database? db;
    try {
      db = await openDatabase(path, readOnly: true);
      return await needsConversion(db);
    } catch (_) {
      // SQLiteとして開けない / テーブルが無い等は oldh1 ではない
      return false;
    } finally {
      try {
        await db?.close();
      } catch (_) {}
    }
  }

  /// 変換の中間スキーマ（invoices / invoice_items）を作成する。
  ///
  /// コピー直後の oldh1 DB には core の `invoices` テーブルが存在しないため、
  /// 挿入前に必ず用意する。存在する場合は何もしない（IF NOT EXISTS）。
  static Future<void> _ensureInvoiceTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS invoices (
        id TEXT PRIMARY KEY,
        customer_id TEXT,
        date TEXT,
        notes TEXT,
        subject TEXT,
        total_amount INTEGER,
        tax_rate REAL,
        document_type TEXT,
        order_status TEXT,
        source_document_id TEXT,
        customer_formal_name TEXT,
        updated_at TEXT,
        meta_json TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS invoice_items (
        id TEXT PRIMARY KEY,
        invoice_id TEXT,
        product_id TEXT,
        description TEXT,
        quantity REAL,
        unit_price INTEGER,
        tax_rate REAL
      )
    ''');
  }

  /// マイグレーションを実行（DBごと）
  static Future<void> runConversion(Database db) async {
    final hasOld = await needsConversion(db);
    if (!hasOld) return;

    // コピー直後の oldh1 DB には invoices/invoice_items が無いため先に作成する
    await _ensureInvoiceTables(db);

    final oldDocs = await db.rawQuery('SELECT * FROM documents');
    for (final row in oldDocs) {
      final id = row['id'] as String? ?? '';
      if (id.isEmpty) continue;

      final exists = await db.rawQuery(
        'SELECT id FROM invoices WHERE id = ?',
        [id],
      );
      if (exists.isNotEmpty) continue;

      await db.insert('invoices', {
        'id': id,
        'customer_id': row['customer_id'] ?? '',
        'date': row['date'] ?? '',
        'notes': row['notes'],
        'subject': row['subject'],
        'total_amount': row['total_amount'] ?? 0,
        'tax_rate': row['tax_rate'] ?? 0.10,
        'document_type': row['document_type'] ?? 'invoice',
        'order_status': row['order_status'] ?? row['status'] ?? 'draft',
        'source_document_id': row['source_document_id'],
        'customer_formal_name': row['customer_formal_name'],
        'updated_at': row['updated_at'] ?? DateTime.now().toIso8601String(),
        'meta_json': row['meta_json'],
      });

      final oldItems = await db.rawQuery(
        'SELECT * FROM document_items WHERE document_id = ?',
        [id],
      );
      for (final item in oldItems) {
        await db.insert('invoice_items', {
          'id': item['id'],
          'invoice_id': id,
          'product_id': item['product_id'],
          'description': item['description'] ?? '',
          'quantity': item['quantity'] ?? 1,
          'unit_price': item['unit_price'] ?? 0,
        });
      }
    }

    await db.execute('DROP TABLE IF EXISTS document_items');
    await db.execute('DROP TABLE IF EXISTS documents');
  }

  /// グローバルなマイグレーション完了フラグを取得（互換性のため残す）
  static Future<bool> isGloballyDone() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_conversionDoneKey) ?? false;
  }

  /// グローバルなマイグレーション完了フラグを設定（互換性のため残す）
  static Future<void> setGloballyDone() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_conversionDoneKey, true);
  }
}
