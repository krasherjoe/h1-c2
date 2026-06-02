import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../models/product_category_model.dart';
import 'database_helper.dart';

class ProductCategoryRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  Future<Database> get _db async => _dbHelper.database;

  Future<List<ProductCategory>> getAll() async {
    final db = await _db;
    final maps = await db.query('product_categories', orderBy: 'name');
    return maps.map((m) => ProductCategory.fromMap(m)).toList();
  }

  Future<List<ProductCategory>> getRoots() async {
    final db = await _db;
    final maps = await db.query(
      'product_categories',
      where: 'parent_id IS NULL',
      orderBy: 'name',
    );
    return maps.map((m) => ProductCategory.fromMap(m)).toList();
  }

  Future<List<ProductCategory>> getChildren(String parentId) async {
    final db = await _db;
    final maps = await db.query(
      'product_categories',
      where: 'parent_id = ?',
      whereArgs: [parentId],
      orderBy: 'name',
    );
    return maps.map((m) => ProductCategory.fromMap(m)).toList();
  }

  Future<List<ProductCategory>> getPath(String id) async {
    final db = await _db;
    final path = <ProductCategory>[];
    var currentId = id;
    while (true) {
      final maps = await db.query(
        'product_categories',
        where: 'id = ?',
        whereArgs: [currentId],
        limit: 1,
      );
      if (maps.isEmpty) break;
      final cat = ProductCategory.fromMap(maps.first);
      path.insert(0, cat);
      if (cat.parentId == null) break;
      currentId = cat.parentId!;
    }
    return path;
  }

  Future<List<ProductCategory>> getTree() async {
    return getRoots();
  }

  Future<void> save(ProductCategory category) async {
    final db = await _db;
    await db.insert(
      'product_categories',
      category.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> delete(String id) async {
    final db = await _db;
    final maps = await db.query(
      'product_categories',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (maps.isEmpty) return;
    final cat = ProductCategory.fromMap(maps.first);
    await db.update(
      'product_categories',
      {'parent_id': cat.parentId},
      where: 'parent_id = ?',
      whereArgs: [id],
    );
    await db.delete('product_categories', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> moveNode(String id, String newParentId) async {
    final db = await _db;
    await db.update(
      'product_categories',
      {'parent_id': newParentId},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> getProductCount(String categoryId) async {
    final db = await _db;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as cnt FROM products WHERE category_id = ?',
      [categoryId],
    );
    return (result.first['cnt'] ?? 0) as int;
  }

  Future<List<ProductCategory>> getAllCategories({bool includeInactive = false}) async {
    final all = await getAll();
    if (includeInactive) return all;
    return all.where((c) => c.isActive).toList();
  }

  Future<String> getOrCreateCategoryId(String name) async {
    final db = await _db;
    final maps = await db.query(
      'product_categories',
      where: 'name = ?',
      whereArgs: [name],
      limit: 1,
    );
    if (maps.isNotEmpty) return maps.first['id'] as String;
    final id = const Uuid().v4();
    final cat = ProductCategory(
      id: id,
      name: name,
    );
    await db.insert('product_categories', cat.toMap());
    return id;
  }

  Future<Map<String, int>> getAllProductCounts() async {
    final db = await _db;
    final result = await db.rawQuery(
      'SELECT category_id, COUNT(*) as cnt FROM products WHERE category_id IS NOT NULL GROUP BY category_id',
    );
    final map = <String, int>{};
    for (final row in result) {
      final id = row['category_id'] as String?;
      if (id != null) {
        map[id] = (row['cnt'] ?? 0) as int;
      }
    }
    return map;
  }
}
