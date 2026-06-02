import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../../../services/database_helper.dart';
import '../models/supplier.dart';

class SupplierRepository {
  Future<List<Supplier>> getAll({bool includeHidden = false}) async {
    final db = await DatabaseHelper().database;
    final where = includeHidden ? null : 'is_hidden = 0';
    final maps = await db.query(
      'suppliers',
      where: where,
      orderBy: 'display_name COLLATE NOCASE',
    );
    return maps.map((m) => Supplier.fromMap(m)).toList();
  }

  Future<Supplier?> getById(String id) async {
    final db = await DatabaseHelper().database;
    final maps = await db.query(
      'suppliers',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return Supplier.fromMap(maps.first);
  }

  Future<List<Supplier>> search(String query) async {
    final db = await DatabaseHelper().database;
    final maps = await db.query(
      'suppliers',
      where: '(display_name LIKE ? OR formal_name LIKE ?) AND is_hidden = 0',
      whereArgs: ['%$query%', '%$query%'],
      orderBy: 'display_name COLLATE NOCASE',
    );
    return maps.map((m) => Supplier.fromMap(m)).toList();
  }

  Future<void> save(Supplier supplier) async {
    final db = await DatabaseHelper().database;
    await db.insert(
      'suppliers',
      supplier.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> delete(String id) async {
    final db = await DatabaseHelper().database;
    await db.delete('suppliers', where: 'id = ?', whereArgs: [id]);
  }

  String generateId() => const Uuid().v4();
}
