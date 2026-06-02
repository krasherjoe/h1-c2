import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../../../services/database_helper.dart';
import '../models/supplier_product.dart';

class SupplierProductService {
  static const _tableName = 'supplier_products';

  Future<Database> get _db => DatabaseHelper().database;

  Future<void> createTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $_tableName (
        id TEXT PRIMARY KEY,
        supplier_id TEXT NOT NULL,
        name TEXT NOT NULL,
        variant TEXT,
        jan_code TEXT,
        wholesale_price INTEGER DEFAULT 0,
        retail_price INTEGER DEFAULT 0,
        order_unit TEXT,
        manufacturer TEXT,
        sub_category TEXT,
        category_path TEXT,
        created_at TEXT NOT NULL,
        FOREIGN KEY(supplier_id) REFERENCES suppliers(id)
      )
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_sp_supplier ON $_tableName(supplier_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_sp_name ON $_tableName(name)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_sp_jan ON $_tableName(jan_code)');
  }

  Future<List<SupplierProduct>> getBySupplier(String supplierId) async {
    final db = await _db;
    final maps = await db.query(
      _tableName,
      where: 'supplier_id = ?',
      whereArgs: [supplierId],
      orderBy: 'name ASC',
    );
    return maps.map((m) => SupplierProduct.fromMap(m)).toList();
  }

  Future<List<SupplierProduct>> search(String supplierId, String query) async {
    final db = await _db;
    final maps = await db.query(
      _tableName,
      where: 'supplier_id = ? AND (name LIKE ? OR jan_code LIKE ?)',
      whereArgs: [supplierId, '%$query%', '%$query%'],
      orderBy: 'name ASC',
    );
    return maps.map((m) => SupplierProduct.fromMap(m)).toList();
  }

  Future<void> save(SupplierProduct product) async {
    final db = await _db;
    await db.insert(
      _tableName,
      product.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> delete(String id) async {
    final db = await _db;
    await db.delete(_tableName, where: 'id = ?', whereArgs: [id]);
  }

  Future<List<String>> getSubCategories(String supplierId) async {
    final db = await _db;
    final maps = await db.rawQuery(
      'SELECT DISTINCT sub_category FROM $_tableName WHERE supplier_id = ? AND sub_category IS NOT NULL AND sub_category != \'\' ORDER BY sub_category',
      [supplierId],
    );
    return maps.map((m) => m['sub_category'] as String).toList();
  }

  Future<List<Map<String, dynamic>>> getPriceHistory(String productId) async {
    return [];
  }

  String generateId() => const Uuid().v4();
}
