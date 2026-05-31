import 'package:sqflite/sqflite.dart';

Future<void> createCoreSchema(Database db) async {
  await db.execute('''
    CREATE TABLE customers (
      id TEXT PRIMARY KEY,
      display_name TEXT NOT NULL,
      formal_name TEXT NOT NULL,
      title TEXT DEFAULT '様',
      department TEXT,
      address TEXT,
      tel TEXT,
      email TEXT,
      head_char1 TEXT,
      head_char2 TEXT,
      closing_day INTEGER,
      payment_day INTEGER,
      rank TEXT DEFAULT 'none',
      credit_limit INTEGER DEFAULT 0,
      credit_note TEXT,
      lat REAL,
      lng REAL,
      is_locked INTEGER DEFAULT 0,
      is_hidden INTEGER DEFAULT 0,
      updated_at TEXT NOT NULL
    )
  ''');

  await db.execute('''
    CREATE TABLE product_categories (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL UNIQUE,
      description TEXT,
      parent_id TEXT,
      is_active INTEGER DEFAULT 1,
      created_at TEXT NOT NULL
    )
  ''');
  await db.execute(
    'CREATE INDEX idx_product_categories_name ON product_categories(name)',
  );

  await db.execute('''
    CREATE TABLE products (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      default_unit_price INTEGER,
      default_unit_price_is_tax_inclusive INTEGER DEFAULT 0,
      wholesale_price INTEGER DEFAULT 0,
      barcode TEXT,
      model_number TEXT,
      manufacturer TEXT,
      category TEXT,
      category_id TEXT,
      stock_quantity INTEGER,
      supplier_id TEXT,
      supplier_name TEXT,
      is_locked INTEGER DEFAULT 0,
      is_hidden INTEGER DEFAULT 0,
      description TEXT,
      tags TEXT,
      updated_at TEXT NOT NULL,
      FOREIGN KEY(category_id) REFERENCES product_categories(id)
    )
  ''');
  await db.execute('CREATE INDEX idx_products_name ON products(name)');
  await db.execute('CREATE INDEX idx_products_barcode ON products(barcode)');
  await db.execute(
    'CREATE INDEX idx_products_category_id ON products(category_id)',
  );

  await db.execute('''
    CREATE TABLE product_option_groups (
      id TEXT PRIMARY KEY,
      product_id TEXT NOT NULL,
      name TEXT NOT NULL,
      price_mode TEXT DEFAULT 'add',
      sort_order INTEGER DEFAULT 0,
      FOREIGN KEY(product_id) REFERENCES products(id)
    )
  ''');
  await db.execute('''
    CREATE TABLE product_option_values (
      id TEXT PRIMARY KEY,
      group_id TEXT NOT NULL,
      value TEXT NOT NULL,
      price_modifier INTEGER DEFAULT 0,
      sort_order INTEGER DEFAULT 0,
      FOREIGN KEY(group_id) REFERENCES product_option_groups(id)
    )
  ''');
  await db.execute('''
    CREATE TABLE product_variant_options (
      variant_id TEXT NOT NULL,
      option_value_id TEXT NOT NULL,
      PRIMARY KEY(variant_id, option_value_id),
      FOREIGN KEY(variant_id) REFERENCES products(id),
      FOREIGN KEY(option_value_id) REFERENCES product_option_values(id)
    )
  ''');
  await db.execute('''
    CREATE TABLE customer_product_prices (
      customer_id TEXT NOT NULL,
      product_id TEXT NOT NULL,
      price INTEGER NOT NULL,
      PRIMARY KEY(customer_id, product_id),
      FOREIGN KEY(customer_id) REFERENCES customers(id),
      FOREIGN KEY(product_id) REFERENCES products(id)
    )
  ''');
  await db.execute(
    'CREATE INDEX idx_variant_options_variant ON product_variant_options(variant_id)',
  );
  await db.execute(
    'CREATE INDEX idx_customer_prices_customer ON customer_product_prices(customer_id)',
  );
  await db.execute(
    'CREATE INDEX idx_option_groups_product ON product_option_groups(product_id)',
  );
  await db.execute(
    'CREATE INDEX idx_option_values_group ON product_option_values(group_id)',
  );

  await db.execute('''
    CREATE TABLE invoices (
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
      'CREATE INDEX idx_invoices_date ON invoices(date)');
  await db.execute(
      'CREATE INDEX idx_invoices_customer ON invoices(customer_id)');
  await db.execute(
      'CREATE INDEX idx_invoices_status ON invoices(order_status)');
  await db.execute(
      'CREATE INDEX idx_invoices_doc_type ON invoices(document_type)');

  await db.execute('''
    CREATE TABLE invoice_items (
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
    'CREATE INDEX idx_invoice_items_invoice ON invoice_items(invoice_id)',
  );

  await db.execute('''
    CREATE TABLE payment_schedules (
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
    'CREATE INDEX idx_payment_schedules_invoice ON payment_schedules(invoice_id)',
  );
  await db.execute(
    'CREATE INDEX idx_payment_schedules_status ON payment_schedules(status)',
  );

  await db.execute('''
    CREATE TABLE suppliers (
      id TEXT PRIMARY KEY,
      display_name TEXT NOT NULL,
      formal_name TEXT NOT NULL,
      title TEXT DEFAULT '様',
      department TEXT,
      address TEXT,
      tel TEXT,
      email TEXT,
      contact_person TEXT,
      payment_terms TEXT,
      bank_account TEXT,
      closing_day INTEGER,
      payment_site_days INTEGER DEFAULT 30,
      notes TEXT,
      is_locked INTEGER DEFAULT 0,
      is_hidden INTEGER DEFAULT 0,
      head_char1 TEXT,
      head_char2 TEXT,
      updated_at TEXT NOT NULL
    )
  ''');
  await db.execute(
    'CREATE INDEX idx_suppliers_display_name ON suppliers(display_name)',
  );

  await db.execute('''
    CREATE TABLE company_info (
      id INTEGER PRIMARY KEY,
      name TEXT NOT NULL,
      zip_code TEXT,
      address TEXT,
      address2 TEXT,
      tel TEXT,
      fax TEXT,
      email TEXT,
      url TEXT,
      default_tax_rate REAL DEFAULT 0.10,
      seal_path TEXT,
      seal_offset_x REAL DEFAULT 10.0,
      seal_offset_y REAL DEFAULT 50.0,
      seal_rotation REAL DEFAULT 0.0,
      tax_display_mode TEXT DEFAULT 'normal',
      registration_number TEXT,
      bank_accounts TEXT,
      default_bank_account_index INTEGER DEFAULT 0,
      fiscal_year_start INTEGER DEFAULT 4,
      is_exempt_taxpayer INTEGER DEFAULT 0
    )
  ''');

  await db.execute('''
    CREATE TABLE activity_logs (
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
    'CREATE INDEX idx_activity_logs_target ON activity_logs(target_type, target_id)',
  );
  await db.execute(
    'CREATE INDEX idx_activity_logs_timestamp ON activity_logs(timestamp)',
  );

  await db.execute('''
    CREATE TABLE hash_chain (
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
    'CREATE INDEX idx_hash_chain_document ON hash_chain(document_type, document_id)',
  );
}
