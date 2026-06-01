import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../../../services/database_helper.dart';
import '../models/purchase_model.dart';

class PurchaseRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  Future<Database> get _db => _dbHelper.database;

  Future<List<PurchaseModel>> fetchAll({PurchaseType? filterType, String query = ''}) async {
    final db = await _db;
    final conditions = <String>[];
    final args = <dynamic>[];

    if (filterType != null) {
      conditions.add('p.purchase_type = ?');
      args.add(filterType.name);
    }
    if (query.isNotEmpty) {
      conditions.add('(p.document_number LIKE ? OR p.supplier_name LIKE ?)');
      args.addAll(['%$query%', '%$query%']);
    }
    conditions.add('p.status IS NOT NULL');

    final where = conditions.isNotEmpty ? 'WHERE ${conditions.join(' AND ')}' : '';
    final maps = await db.rawQuery('''
      SELECT p.* FROM purchases p
      $where
      ORDER BY p.date DESC
    ''', args);

    final purchases = <PurchaseModel>[];
    for (final map in maps) {
      final items = await _fetchItems(db, map['id'] as String);
      purchases.add(PurchaseModel.fromMap(map, items: items));
    }
    return purchases;
  }

  Future<PurchaseModel?> fetchById(String id) async {
    final db = await _db;
    final maps = await db.query('purchases', where: 'id = ?', whereArgs: [id], limit: 1);
    if (maps.isEmpty) return null;
    final items = await _fetchItems(db, id);
    return PurchaseModel.fromMap(maps.first, items: items);
  }

  Future<List<PurchaseItem>> _fetchItems(Database db, String purchaseId) async {
    final maps = await db.query(
      'purchase_items',
      where: 'purchase_id = ?',
      whereArgs: [purchaseId],
    );
    return maps.map((m) => PurchaseItem.fromMap(m)).toList();
  }

  Future<void> save(PurchaseModel purchase) async {
    final db = await _db;
    await db.transaction((txn) async {
      await txn.insert(
        'purchases',
        purchase.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await txn.delete('purchase_items', where: 'purchase_id = ?', whereArgs: [purchase.id]);
      for (final item in purchase.items) {
        await txn.insert(
          'purchase_items',
          item.toMap(purchase.id),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  Future<void> delete(String id) async {
    final db = await _db;
    await db.transaction((txn) async {
      await txn.delete('purchase_items', where: 'purchase_id = ?', whereArgs: [id]);
      await txn.delete('purchases', where: 'id = ?', whereArgs: [id]);
    });
  }

  Future<String> generateDocumentNumber(PurchaseType type) async {
    final db = await _db;
    final prefix = switch (type) {
      PurchaseType.order => 'PO',
      PurchaseType.receipt => 'PR',
      PurchaseType.return_ => 'RT',
      PurchaseType.payment => 'PY',
    };
    final today = DateTime.now();
    final yymm = '${today.year % 100}${today.month.toString().padLeft(2, '0')}';
    final results = await db.rawQuery(
      "SELECT COUNT(*) as cnt FROM purchases WHERE document_number LIKE ?",
      ['$prefix$yymm%'],
    );
    final count = (results.first['cnt'] as int? ?? 0) + 1;
    return '$prefix$yymm-${count.toString().padLeft(4, '0')}';
  }

  String generateId() => const Uuid().v4();
}
