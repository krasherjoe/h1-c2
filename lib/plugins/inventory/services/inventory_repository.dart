import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../../../services/database_helper.dart';
import '../models/stock_transaction_model.dart';

class InventoryRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  Future<Database> get _db => _dbHelper.database;

  Future<List<StockTransaction>> fetchAll({String productId = '', int limit = 200}) async {
    final db = await _db;
    final conditions = <String>[];
    final args = <dynamic>[];
    if (productId.isNotEmpty) {
      conditions.add('product_id = ?');
      args.add(productId);
    }
    final where = conditions.isNotEmpty ? 'WHERE ${conditions.join(' AND ')}' : '';
    final maps = await db.rawQuery('''
      SELECT * FROM stock_transactions
      $where
      ORDER BY created_at DESC
      LIMIT ?
    ''', [...args, limit]);
    return maps.map((m) => StockTransaction.fromMap(m)).toList();
  }

  Future<void> save(StockTransaction transaction) async {
    final db = await _db;
    await db.insert(
      'stock_transactions',
      transaction.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int> getStockQuantity(String productId) async {
    final db = await _db;
    final result = await db.rawQuery('''
      SELECT COALESCE(SUM(quantity), 0) as total
      FROM stock_transactions
      WHERE product_id = ?
    ''', [productId]);
    return (result.first['total'] as int?) ?? 0;
  }

  Future<Map<String, int>> getAllStockQuantities() async {
    final db = await _db;
    final result = await db.rawQuery('''
      SELECT product_id, product_name, COALESCE(SUM(quantity), 0) as total
      FROM stock_transactions
      GROUP BY product_id, product_name
      HAVING total != 0
      ORDER BY product_name ASC
    ''');
    final map = <String, int>{};
    for (final row in result) {
      map[row['product_id'] as String] = (row['total'] as int?) ?? 0;
    }
    return map;
  }

  String generateId() => const Uuid().v4();
}
