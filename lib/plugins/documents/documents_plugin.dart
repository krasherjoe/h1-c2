import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import '../../plugin_system/plugin_interface.dart';
import '../../plugin_system/plugin_context.dart';
import '../../plugin_system/plugin_permission.dart';
import '../../plugin_system/screen_definition.dart';
import '../../plugins/explorer/h1_explorer.dart';
import 'explorer/document_explorer_config.dart';
import '../../services/debug_console.dart';

const _kDocTable = '''
  CREATE TABLE IF NOT EXISTS documents (
    id TEXT PRIMARY KEY,
    document_type TEXT NOT NULL,
    customer_id TEXT,
    customer_name TEXT,
    document_number TEXT,
    date TEXT NOT NULL,
    total INTEGER DEFAULT 0,
    status TEXT DEFAULT 'draft',
    linked_document_id TEXT,
    project_id TEXT,
    subject TEXT
  )
''';

const _kDocItemsTable = '''
  CREATE TABLE IF NOT EXISTS document_items (
    id TEXT PRIMARY KEY,
    document_id TEXT NOT NULL,
    product_id TEXT,
    product_name TEXT,
    quantity REAL DEFAULT 1,
    unit_price INTEGER DEFAULT 0,
    tax_rate REAL DEFAULT 0.1,
    FOREIGN KEY (document_id) REFERENCES documents(id) ON DELETE CASCADE
  )
''';

const _kMissingTables = [_kDocTable, _kDocItemsTable];

class DocumentsPlugin extends H1Plugin {
  @override
  String get id => 'com.h1.plugin.documents';

  @override
  String get name => '伝票管理';

  @override
  String get version => '1.0.0';

  @override
  String get description => '見積・受注・納品・請求・領収の一元管理';

  @override
  List<String> get dependencies => ['com.h1.core'];

  @override
  List<PluginPermission> get requiredPermissions => [
    PluginPermission.readDatabase,
    PluginPermission.writeDatabase,
  ];

  @override
  Future<void> initialize(PluginContext context) async {
    await _recoverFromConversion(context.database);
    DebugConsole.register('documents.stats', (_) async {
      final db = context.database;
      final cnt = await db.rawQuery('SELECT document_type, COUNT(*) as c FROM documents GROUP BY document_type');
      final lines = cnt.map((r) => '  ${r['document_type']}: ${r['c']}件').join('\n');
      final total = cnt.fold(0, (s, r) => s + (r['c'] as int? ?? 0));
      return '伝票統計:\n$lines\n  合計: $total件';
    });
    debugPrint('[DocumentsPlugin] Initialized');
  }

  Future<void> _recoverFromConversion(Database db) async {
    try {
      final hasInvoices = (await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='invoices'",
      )).isNotEmpty;
      if (!hasInvoices) return;

      final invoicesCount = await db.rawQuery('SELECT COUNT(*) AS c FROM invoices');
      if ((invoicesCount.first['c'] as int? ?? 0) == 0) return;

      final docsCount = await db.rawQuery('SELECT COUNT(*) AS c FROM documents');
      if ((docsCount.first['c'] as int? ?? 0) > 0) return;

      final rows = await db.rawQuery('SELECT * FROM invoices');
      for (final row in rows) {
        final id = row['id'] as String? ?? '';
        if (id.isEmpty) continue;
        final type = row['document_type'] as String? ?? 'invoice';
        final prefix = switch (type) {
          'estimation' => 'MG', 'order' => 'JU', 'delivery' => 'NH',
          'invoice' => 'SK', 'receipt' => 'RY', _ => 'XX',
        };
        final cnt = (await db.rawQuery(
          "SELECT COUNT(*) as c FROM documents WHERE document_number LIKE ?",
          ['$prefix${DateTime.now().year % 100}%'],
        )).first['c'] as int? ?? 0;

        await db.insert('documents', {
          'id': id,
          'document_type': type,
          'customer_id': row['customer_id'],
          'customer_name': row['customer_formal_name'] ?? row['customer_id'] ?? '',
          'document_number': '$prefix${DateTime.now().year % 100}${DateTime.now().month.toString().padLeft(2, '0')}-${(cnt + 1).toString().padLeft(4, '0')}',
          'date': row['date'] ?? DateTime.now().toIso8601String().substring(0, 10),
          'total': (row['total_amount'] as num?)?.toInt() ?? 0,
          'status': row['order_status'] as String? ?? 'draft',
          'linked_document_id': row['source_document_id'] as String?,
          'subject': row['subject'] as String?,
        });

        final items = await db.rawQuery(
          'SELECT * FROM invoice_items WHERE invoice_id = ?', [id],
        );
        for (final item in items) {
          await db.insert('document_items', {
            'id': item['id'],
            'document_id': id,
            'product_id': item['product_id'],
            'product_name': item['description'] ?? '',
            'quantity': item['quantity'] ?? 1,
            'unit_price': item['unit_price'] ?? 0,
            'tax_rate': item['tax_rate'] ?? 0.1,
          });
        }
      }
      debugPrint('[DocumentsPlugin] invoices→documents 復元完了: ${rows.length}件');
    } catch (e) {
      debugPrint('[DocumentsPlugin] 復元失敗: $e');
    }
  }

  @override
  Future<void> migrate(Database db, int fromVersion, int toVersion) async {
    for (final sql in _kMissingTables) {
      try { await db.execute(sql); } catch (_) {}
    }
    try {
      await db.execute(
        'ALTER TABLE documents ADD COLUMN project_id TEXT',
      );
    } catch (_) {}
    try {
      await db.execute(
        'ALTER TABLE documents ADD COLUMN subject TEXT',
      );
    } catch (_) {}
    try {
      await db.execute(
        "ALTER TABLE documents ADD COLUMN include_tax INTEGER DEFAULT 0",
      );
    } catch (_) {}
    try {
      await db.execute(
        "ALTER TABLE documents ADD COLUMN tax_rate REAL DEFAULT 0.10",
      );
    } catch (_) {}
    try {
      await db.execute(
        "ALTER TABLE documents ADD COLUMN total_discount_amount INTEGER",
      );
    } catch (_) {}
    try {
      await db.execute(
        "ALTER TABLE documents ADD COLUMN total_discount_rate REAL",
      );
    } catch (_) {}
    try {
      await db.execute(
        "ALTER TABLE documents ADD COLUMN price_adjustment_type TEXT",
      );
    } catch (_) {}
    try {
      await db.execute(
        "ALTER TABLE documents ADD COLUMN price_adjustment_unit INTEGER",
      );
    } catch (_) {}
    try {
      await db.execute(
        "ALTER TABLE documents ADD COLUMN is_locked INTEGER DEFAULT 0",
      );
    } catch (_) {}
    try {
      await db.execute(
        "ALTER TABLE documents ADD COLUMN content_hash TEXT",
      );
    } catch (_) {}
    try {
      await db.execute(
        "ALTER TABLE document_items ADD COLUMN discount_amount INTEGER",
      );
    } catch (_) {}
    try {
      await db.execute(
        "ALTER TABLE document_items ADD COLUMN discount_rate REAL",
      );
    } catch (_) {}
  }

  @override
  Future<void> dispose() async {
    debugPrint('[DocumentsPlugin] Disposed');
  }

  @override
  List<ScreenDefinition> get screens => [
    ScreenDefinition(
      id: 'DOC',
      title: '伝票管理',
      route: '/documents',
      builder: (_) => H1Explorer(config: DocumentExplorerConfig()),
      category: '販売',
      icon: Icons.folder_open,
      description: '見積・納品・請求・領収',
    ),
  ];

  @override
  Map<String, WidgetBuilder> getRoutes() => {
    '/documents': (_) => H1Explorer(
      config: DocumentExplorerConfig(),
    ),
  };

  @override
  Future<void> createTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS invoices (
        id TEXT NOT NULL,
        customer_id TEXT NOT NULL,
        date TEXT NOT NULL,
        notes TEXT,
        subject TEXT,
        total_amount INTEGER,
        tax_rate REAL DEFAULT 0.10,
        document_type TEXT DEFAULT 'invoice',
        order_status TEXT DEFAULT 'draft',
        promised_date INTEGER,
        fulfilled_date INTEGER,
        source_document_id TEXT,
        linked_delivery_id TEXT,
        linked_invoice_id TEXT,
        customer_formal_name TEXT,
        is_synced INTEGER DEFAULT 0,
        updated_at TEXT NOT NULL,
        latitude REAL,
        longitude REAL,
        terminal_id TEXT DEFAULT 'T1',
        is_draft INTEGER DEFAULT 0,
        is_locked INTEGER DEFAULT 0,
        total_discount_amount INTEGER DEFAULT 0,
        total_discount_rate REAL DEFAULT 0,
        include_tax INTEGER DEFAULT 1,
        is_tax_inclusive_mode INTEGER DEFAULT 0,
        payment_status TEXT DEFAULT 'unpaid',
        received_amount INTEGER DEFAULT 0,
        project_id TEXT,
        is_test_document INTEGER DEFAULT 0,
        printed_at TEXT,
        email_sent_at TEXT,
        email_sent_to TEXT,
        is_receipt_issued INTEGER DEFAULT 0,
        receipt_issued_at TEXT,
        meta_json TEXT,
        PRIMARY KEY (id),
        FOREIGN KEY (customer_id) REFERENCES customers (id) ON DELETE CASCADE
      )
    ''');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_invoices_date ON invoices(date)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_invoices_customer ON invoices(customer_id)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_invoices_status ON invoices(order_status)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_invoices_doc_type ON invoices(document_type)');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS invoice_items (
        id TEXT PRIMARY KEY,
        invoice_id TEXT NOT NULL,
        product_id TEXT,
        description TEXT NOT NULL,
        quantity INTEGER NOT NULL,
        unit_price INTEGER NOT NULL,
        discount_amount INTEGER DEFAULT 0,
        discount_rate REAL DEFAULT 0,
        FOREIGN KEY (invoice_id) REFERENCES invoices (id) ON DELETE CASCADE
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_invoice_items_invoice ON invoice_items(invoice_id)',
    );

    await db.execute('''
      CREATE TABLE IF NOT EXISTS payment_schedules (
        id TEXT PRIMARY KEY,
        invoice_id TEXT NOT NULL,
        due_date TEXT NOT NULL,
        amount INTEGER NOT NULL,
        paid_amount INTEGER DEFAULT 0,
        status TEXT DEFAULT 'pending',
        paid_at TEXT,
        notes TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY(invoice_id) REFERENCES invoices(id) ON DELETE CASCADE
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_payment_schedules_invoice ON payment_schedules(invoice_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_payment_schedules_status ON payment_schedules(status)',
    );

    await db.execute(_kDocTable);
    await db.execute(_kDocItemsTable);
  }
}
