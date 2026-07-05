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

  // 配送管理 - 追跡番号
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

  // 配送管理 - 追跡履歴
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

  // 配送管理 - 送り状
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

  // 配送管理 - 送付先
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

  // ユーザーテーブル（マルチユーザー対応）
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
}
