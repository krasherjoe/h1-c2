import 'package:sqflite/sqflite.dart';

Future<void> createCoreSchema(Database db) async {
  await db.execute('''
    CREATE TABLE IF NOT EXISTS activity_logs (
      id TEXT PRIMARY KEY,
      action TEXT NOT NULL,
      target_type TEXT NOT NULL,
      target_id TEXT,
      details TEXT,
      screen_id TEXT,
      timestamp TEXT NOT NULL
    )
  ''');
  await db.execute(
    'CREATE INDEX IF NOT EXISTS idx_activity_logs_target ON activity_logs(target_type, target_id)',
  );
  await db.execute(
    'CREATE INDEX IF NOT EXISTS idx_activity_logs_timestamp ON activity_logs(timestamp)',
  );

  await db.execute('''
    CREATE TABLE IF NOT EXISTS hash_chain (
      id TEXT PRIMARY KEY,
      document_type TEXT NOT NULL,
      document_id TEXT NOT NULL,
      content_hash TEXT NOT NULL,
      previous_hash TEXT,
      created_at TEXT NOT NULL,
      version INTEGER NOT NULL DEFAULT 1
    )
  ''');
  await db.execute(
    'CREATE INDEX IF NOT EXISTS idx_hash_chain_document ON hash_chain(document_type, document_id)',
  );

  // 電子帳簿保存法対応 - PDF生成JSONのハッシュチェーン
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

  // PDF出力履歴
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

  // メール送信履歴
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
}
