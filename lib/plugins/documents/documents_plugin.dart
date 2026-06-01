import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import '../../plugin_system/plugin_interface.dart';
import '../../plugin_system/plugin_context.dart';
import '../../plugin_system/plugin_permission.dart';
import '../../plugin_system/menu_item.dart';
import '../../explorer/h1_explorer.dart';
import 'explorer/document_explorer_config.dart';

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
    debugPrint('[DocumentsPlugin] Initialized');
  }

  @override
  Future<void> dispose() async {
    debugPrint('[DocumentsPlugin] Disposed');
  }

  @override
  List<MenuItem> getMenuItems() => [
    const MenuItem(
      id: 'DOC',
      title: '伝票管理',
      route: '/documents',
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
  }
}
