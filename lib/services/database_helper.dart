import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;

import 'company_service.dart';
import 'database/database_schema_core.dart';
import 'database/database_utils.dart';
import 'history_db_service.dart';

export 'database/database_utils.dart';
export 'database/database_schema_core.dart';

class DatabaseHelper {
  static const _databaseVersion = 18;
  static int get databaseVersion => _databaseVersion;
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;
  static Future<Database>? _databaseFuture;
  static Database? testDatabase;

  factory DatabaseHelper() => _instance;

  DatabaseHelper._internal();

  Future<Database> get database async {
    if (testDatabase != null) return testDatabase!;
    if (kIsWeb) {
      throw UnsupportedError('WebではDatabaseは使用できません');
    }
    if (_database != null) return _database!;
    _databaseFuture ??= _initDatabase();
    _database = await _databaseFuture!;
    return _database!;
  }

  static Future<Database> createFreshDatabase(String dbPath) async {
    return openDatabase(
      dbPath,
      version: _databaseVersion,
      onCreate: createAllTables,
      onUpgrade: upgradeDatabase,
    );
  }

  static Future<void> closeAndReset() async {
    final db = _database;
    _database = null;
    _databaseFuture = null;
    if (db != null && db.isOpen) {
      try {
        await db.close();
      } catch (e) {
        debugPrint('[DBHelper] close error: $e');
      }
    }
    await HistoryDbService.closeAndReset();
  }

  Future<String> getDatabasePath() async {
    return CompanyService.getCurrentDbPath();
  }

  Future<String> _getDatabaseDirectory() async {
    final dir = await CompanyService.getCompanyDirectory();
    return dir.path;
  }

  /// 内部ストレージから外部ストレージへDBを移行
  static Future<void> _migrateToExternalStorage(String externalDbPath) async {
    try {
      final ef = File(externalDbPath);
      if (await ef.exists()) {
        if (await ef.length() > 0) return;
      }
      final appDir = await getApplicationDocumentsDirectory();
      final internalDir = Directory(p.join(appDir.path, '販売アシスト1号core'));
      if (!await internalDir.exists()) return;
      final name = p.basenameWithoutExtension(externalDbPath);
      final internalFile = File(p.join(internalDir.path, '$name.db'));
      if (!await internalFile.exists()) return;
      if (await internalFile.length() == 0) return;
      await ef.parent.create(recursive: true);
      await internalFile.copy(externalDbPath);
      debugPrint('[DB] 内部→外部ストレージ移行完了: $name.db');
    } catch (e) {
      debugPrint('[DB] 外部ストレージ移行失敗: $e');
    }
  }

  Future<Database> _initDatabase() async {
    final dbPath = await CompanyService.getCurrentDbPath();
    debugPrint('[DB] データベースパス: $dbPath');
    await _migrateToExternalStorage(dbPath);
    final dir = Directory(p.dirname(dbPath));
    if (!await dir.exists()) await dir.create(recursive: true);
    Database db;
    try {
      db = await openDatabase(
        dbPath,
        version: _databaseVersion,
        onCreate: createAllTables,
        onUpgrade: upgradeDatabase,
      );
    } catch (e) {
      debugPrint('[DB] openDatabase失敗、app-privateにフォールバック: $e');
      final appDir = await getApplicationDocumentsDirectory();
      final fallbackPath = p.join(appDir.path, '販売アシスト1号core', p.basename(dbPath));
      await Directory(p.dirname(fallbackPath)).create(recursive: true);
      db = await openDatabase(
        fallbackPath,
        version: _databaseVersion,
        onCreate: createAllTables,
        onUpgrade: upgradeDatabase,
      );
    }
    await HistoryDbService.initialize(db);
    return db;
  }
}

Future<void> createAllTables(Database db, int version) async {
  await createCoreSchema(db);
}

Future<void> upgradeDatabase(Database db, int oldVersion, int newVersion) async {
  for (var v = oldVersion + 1; v <= newVersion; v++) {
    await _migrateToVersion(db, v);
  }
}

Future<void> _migrateToVersion(Database db, int version) async {
  switch (version) {
    case 2:
      break;
    case 3:
      await safeAddColumn(db, 'projects', 'contract_months INTEGER');
      break;
    case 4:
      await db.execute('''
        CREATE TABLE IF NOT EXISTS sync_log (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          entity_type TEXT NOT NULL,
          entity_id TEXT NOT NULL,
          action TEXT NOT NULL,
          data TEXT NOT NULL,
          device_id TEXT NOT NULL,
          parent_id TEXT,
          synced_at TEXT,
          created_at TEXT NOT NULL
        )
      ''');
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_sync_log_entity ON sync_log(entity_type, entity_id)',
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_sync_log_unsent ON sync_log(synced_at) WHERE synced_at IS NULL',
      );
      break;
    case 5:
      await safeAddColumn(db, 'company_info', 'closing_day INTEGER DEFAULT 20');
      break;
    case 6:
      // 電子帳簿保存法対応 - PDF生成JSONのハッシュチェーンテーブル
      await db.execute('''
        CREATE TABLE IF NOT EXISTS electronic_bookkeeping (
          id TEXT PRIMARY KEY,
          document_type TEXT NOT NULL,
          document_id TEXT NOT NULL,
          pdf_json TEXT NOT NULL,
          content_hash TEXT NOT NULL,
          previous_hash TEXT,
          version INTEGER NOT NULL DEFAULT 1,
          created_at TEXT NOT NULL
        )
      ''');
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_eb_document ON electronic_bookkeeping(document_type, document_id)',
      );
      break;
    case 7:
      // PDF出力履歴テーブル
      await db.execute('''
        CREATE TABLE IF NOT EXISTS pdf_output_history (
          id TEXT PRIMARY KEY,
          document_type TEXT NOT NULL,
          document_id TEXT NOT NULL,
          document_number TEXT NOT NULL,
          customer_name TEXT,
          file_path TEXT,
          content_hash TEXT NOT NULL,
          output_at TEXT NOT NULL
        )
      ''');
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_pdf_history_document ON pdf_output_history(document_type, document_id)',
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_pdf_history_output_at ON pdf_output_history(output_at)',
      );
      // メール送信履歴テーブル
      await db.execute('''
        CREATE TABLE IF NOT EXISTS email_send_history (
          id TEXT PRIMARY KEY,
          document_type TEXT,
          document_id TEXT,
          document_number TEXT,
          recipient_email TEXT NOT NULL,
          recipient_name TEXT,
          subject TEXT NOT NULL,
          status TEXT NOT NULL DEFAULT 'sent',
          sent_at TEXT NOT NULL
        )
      ''');
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_email_history_document ON email_send_history(document_type, document_id)',
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_email_history_sent_at ON email_send_history(sent_at)',
      );
      break;
    case 8:
      await safeAddColumn(db, 'projects', 'start_date TEXT');
      await safeAddColumn(db, 'projects', 'end_date TEXT');
      break;
    case 9:
      // バックアップ操作追跡テーブル
      await db.execute('''
        CREATE TABLE IF NOT EXISTS backup_operations (
          id TEXT PRIMARY KEY,
          operation_type TEXT NOT NULL,
          backup_type TEXT NOT NULL,
          status TEXT NOT NULL DEFAULT 'pending',
          file_path TEXT,
          file_size INTEGER,
          started_at TEXT,
          completed_at TEXT,
          error_message TEXT,
          metadata TEXT,
          created_at TEXT NOT NULL
        )
      ''');
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_backup_operations_status ON backup_operations(status)',
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_backup_operations_type ON backup_operations(operation_type)',
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_backup_operations_created ON backup_operations(created_at)',
      );
      break;
    case 10:
      // 請求テンプレートテーブル
      await db.execute('''
        CREATE TABLE IF NOT EXISTS billing_templates (
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          description TEXT,
          workflow_steps TEXT,
          closing_date_type TEXT NOT NULL DEFAULT 'monthly',
          closing_day INTEGER,
          closing_month_type TEXT NOT NULL DEFAULT 'everyMonth',
          payment_term TEXT NOT NULL DEFAULT 'endOfMonth',
          payment_days INTEGER,
          invoice_timing TEXT NOT NULL DEFAULT 'onClosingDate',
          auto_generate_invoice INTEGER NOT NULL DEFAULT 0,
          auto_send_email INTEGER NOT NULL DEFAULT 0,
          attach_ar_report INTEGER NOT NULL DEFAULT 0,
          email_bcc TEXT,
          email_reply_to TEXT,
          include_delivery_details INTEGER NOT NULL DEFAULT 1,
          group_by_project INTEGER NOT NULL DEFAULT 1,
          invoice_notes TEXT,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL,
          is_default INTEGER NOT NULL DEFAULT 0
        )
      ''');
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_billing_templates_default ON billing_templates(is_default)',
      );
      // projectsテーブルにbilling_template_idカラム追加
      await safeAddColumn(db, 'projects', 'billing_template_id TEXT');
      break;
    case 11:
      // projectsテーブルにワークフロー進捗フィールド追加
      await safeAddColumn(db, 'projects', 'current_workflow_step TEXT');
      await safeAddColumn(db, 'projects', 'workflow_started_at TEXT');
      await safeAddColumn(db, 'projects', 'workflow_completed_at TEXT');
      break;
    case 12:
      // 売上処理キューテーブル
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
      break;
    case 13:
      // 会計伝票テーブル
      await db.execute('''
        CREATE TABLE IF NOT EXISTS accounting_vouchers (
          id TEXT PRIMARY KEY,
          type TEXT NOT NULL,
          voucher_number TEXT NOT NULL,
          date TEXT NOT NULL,
          amount INTEGER NOT NULL,
          customer_id TEXT,
          customer_name TEXT,
          account_id TEXT,
          account_name TEXT,
          description TEXT,
          reference TEXT,
          status TEXT NOT NULL DEFAULT 'draft',
          created_at TEXT NOT NULL,
          updated_at TEXT
        )
      ''');
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_accounting_vouchers_type ON accounting_vouchers(type)',
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_accounting_vouchers_date ON accounting_vouchers(date)',
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_accounting_vouchers_status ON accounting_vouchers(status)',
      );
      break;
    case 14:
      // JAN/MOOV標準対応 - productsテーブルにカラム追加
      await safeAddColumn(db, 'products', 'product_name_kana TEXT');
      await safeAddColumn(db, 'products', 'classification_code TEXT');
      await safeAddColumn(db, 'products', 'division_code TEXT');
      await safeAddColumn(db, 'products', 'manufacturer_code TEXT');
      break;
    case 15:
      // 配送管理 - テーブル作成（初回のみ）
      if (!await tableExists(db, 'trackings')) {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS trackings (
            id TEXT PRIMARY KEY,
            tracking_number TEXT NOT NULL,
            carrier TEXT NOT NULL,
            direction TEXT NOT NULL,
            status TEXT NOT NULL,
            shipped_at TEXT,
            delivered_at TEXT,
            tracking_updated_at TEXT,
            notes TEXT,
            entity_type TEXT,
            entity_id TEXT,
            entity_name TEXT,
            label_id TEXT
          )
        ''');
        await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_trackings_entity ON trackings(entity_type, entity_id)',
        );
        await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_trackings_status ON trackings(status)',
        );
        await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_trackings_label ON trackings(label_id)',
        );
      } else {
        // 既存テーブルがある場合はカラム追加
        await safeAddColumn(db, 'trackings', 'label_id TEXT');
        await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_trackings_label ON trackings(label_id)',
        );
      }
      // 他の配送管理テーブルも作成
      if (!await tableExists(db, 'tracking_events')) {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS tracking_events (
            id TEXT PRIMARY KEY,
            tracking_id TEXT NOT NULL,
            status TEXT NOT NULL,
            location TEXT NOT NULL,
            timestamp TEXT NOT NULL,
            description TEXT
          )
        ''');
        await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_tracking_events_tracking ON tracking_events(tracking_id)',
        );
        await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_tracking_events_timestamp ON tracking_events(timestamp)',
        );
      }
      if (!await tableExists(db, 'shipping_labels')) {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS shipping_labels (
            id TEXT PRIMARY KEY,
            carrier TEXT NOT NULL,
            label_type TEXT NOT NULL,
            tracking_number TEXT NOT NULL,
            sender_name TEXT NOT NULL,
            sender_zip TEXT NOT NULL,
            sender_address TEXT NOT NULL,
            sender_phone TEXT NOT NULL,
            recipient_name TEXT NOT NULL,
            recipient_zip TEXT NOT NULL,
            recipient_address TEXT NOT NULL,
            recipient_phone TEXT NOT NULL,
            recipient_company TEXT,
            contents TEXT,
            quantity INTEGER,
            weight INTEGER,
            service_type TEXT,
            cod_amount TEXT,
            created_at TEXT NOT NULL,
            printed_at TEXT,
            entity_type TEXT,
            entity_id TEXT
          )
        ''');
        await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_shipping_labels_entity ON shipping_labels(entity_type, entity_id)',
        );
        await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_shipping_labels_tracking ON shipping_labels(tracking_number)',
        );
      }
      if (!await tableExists(db, 'shipping_addresses')) {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS shipping_addresses (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            company TEXT,
            zip TEXT NOT NULL,
            address TEXT NOT NULL,
            phone TEXT NOT NULL,
            is_default INTEGER NOT NULL DEFAULT 0
          )
        ''');
        await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_shipping_addresses_default ON shipping_addresses(is_default)',
        );
      }
      break;
    case 16:
      // マルチユーザー対応: users テーブル作成 + 全テーブルに created_by/updated_by 追加
      await db.execute('''
        CREATE TABLE IF NOT EXISTS users (
          id TEXT PRIMARY KEY,
          email TEXT UNIQUE NOT NULL,
          display_name TEXT,
          role TEXT DEFAULT 'member',
          photo_url TEXT,
          is_active INTEGER DEFAULT 1,
          created_at TEXT,
          last_login_at TEXT
        )
      ''');
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_users_email ON users(email)',
      );
      
      // 全テーブルに created_by / updated_by カラムを追加
      final tables = [
        'customers', 'documents', 'document_items', 'products',
        'projects', 'purchases', 'purchase_items', 'suppliers',
        'journal_entries', 'cash_transactions', 'accounting_vouchers',
        'payment_schedules', 'payments', 'warehouses', 'stock_transactions',
        'daily_reports', 'time_logs', 'cases', 'memorandums',
        'accounts', 'audit_logs',
      ];
      for (final table in tables) {
        await safeAddColumn(db, table, 'created_by TEXT');
        await safeAddColumn(db, table, 'updated_by TEXT');
      }
      
      // 既存レコードの created_by を 'system' で埋める
      for (final table in tables) {
        await db.rawUpdate(
          "UPDATE $table SET created_by = 'system' WHERE created_by IS NULL",
        );
      }
      break;
    case 17:
      await db.execute('''
        CREATE TABLE IF NOT EXISTS user_permissions (
          user_id TEXT,
          feature TEXT,
          allowed INTEGER NOT NULL DEFAULT 0,
          PRIMARY KEY (user_id, feature),
          FOREIGN KEY (user_id) REFERENCES users(id)
        )
      ''');
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_user_perms_user ON user_permissions(user_id)',
      );
      break;
    case 18:
      await db.execute('''
        CREATE TABLE IF NOT EXISTS sync_queue (
          id TEXT PRIMARY KEY,
          table_name TEXT NOT NULL,
          record_id TEXT NOT NULL,
          action TEXT NOT NULL,
          data TEXT,
          created_at TEXT,
          synced_at TEXT,
          status TEXT DEFAULT 'pending'
        )
      ''');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_sync_queue_status ON sync_queue(status)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_sync_queue_table ON sync_queue(table_name)');
      break;
    default:
      break;
  }
}
