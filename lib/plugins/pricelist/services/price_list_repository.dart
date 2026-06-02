import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../../../services/database_helper.dart';
import '../models/price_entry.dart';

class PriceListRepository {
  Future<List<PriceEntry>> getRoots(String year) async {
    final db = await DatabaseHelper().database;
    final maps = await db.query(
      'price_entries',
      where: 'year = ? AND parent_id IS NULL',
      whereArgs: [year],
      orderBy: 'sort_order, name',
    );
    return maps.map((m) => PriceEntry.fromMap(m)).toList();
  }

  Future<List<PriceEntry>> getChildren(String parentId) async {
    final db = await DatabaseHelper().database;
    final maps = await db.query(
      'price_entries',
      where: 'parent_id = ?',
      whereArgs: [parentId],
      orderBy: 'sort_order, name',
    );
    return maps.map((m) => PriceEntry.fromMap(m)).toList();
  }

  Future<List<PriceEntry>> getPath(String id) async {
    final db = await DatabaseHelper().database;
    final path = <PriceEntry>[];
    var currentId = id;
    while (true) {
      final maps = await db.query(
        'price_entries',
        where: 'id = ?',
        whereArgs: [currentId],
        limit: 1,
      );
      if (maps.isEmpty) break;
      final entry = PriceEntry.fromMap(maps.first);
      path.insert(0, entry);
      if (entry.parentId == null) break;
      currentId = entry.parentId!;
    }
    return path;
  }

  Future<List<PriceEntry>> search(String year, String query) async {
    final db = await DatabaseHelper().database;
    final maps = await db.query(
      'price_entries',
      where: 'year = ? AND name LIKE ?',
      whereArgs: [year, '%$query%'],
      orderBy: 'sort_order, name',
    );
    return maps.map((m) => PriceEntry.fromMap(m)).toList();
  }

  Future<void> save(PriceEntry entry) async {
    final db = await DatabaseHelper().database;
    await db.insert(
      'price_entries',
      entry.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> delete(String id) async {
    final db = await DatabaseHelper().database;
    final children = await getChildren(id);
    for (final child in children) {
      await delete(child.id);
    }
    await db.delete('price_entries', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> moveNode(String id, String newParentId) async {
    final db = await DatabaseHelper().database;
    final now = DateTime.now().toIso8601String();
    await db.update(
      'price_entries',
      {'parent_id': newParentId, 'updated_at': now},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<PriceEntry>> copySubtree(
    String sourceId,
    String targetParentId, {
    String? newYear,
  }) async {
    final db = await DatabaseHelper().database;
    final sourceMaps = await db.query(
      'price_entries',
      where: 'id = ?',
      whereArgs: [sourceId],
    );
    if (sourceMaps.isEmpty) return [];
    final source = PriceEntry.fromMap(sourceMaps.first);

    final idMap = <String, String>{};
    final created = <PriceEntry>[];

    final newId = const Uuid().v4();
    idMap[source.id] = newId;
    final now = DateTime.now().toIso8601String();
    final copied = source.copyWith(
      id: newId,
      parentId: targetParentId,
      year: newYear ?? source.year,
      createdAt: DateTime.parse(now),
      updatedAt: DateTime.parse(now),
    );
    await db.insert('price_entries', copied.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
    created.add(copied);

    await _copyChildren(db, source.id, newId, idMap, created,
        newYear: newYear);
    return created;
  }

  Future<void> _copyChildren(
    Database db,
    String sourceParentId,
    String newParentId,
    Map<String, String> idMap,
    List<PriceEntry> created, {
    String? newYear,
  }) async {
    final childMaps = await db.query(
      'price_entries',
      where: 'parent_id = ?',
      whereArgs: [sourceParentId],
      orderBy: 'sort_order, name',
    );
    for (final m in childMaps) {
      final child = PriceEntry.fromMap(m);
      final newId = const Uuid().v4();
      idMap[child.id] = newId;
      final now = DateTime.now().toIso8601String();
      final copied = child.copyWith(
        id: newId,
        parentId: newParentId,
        year: newYear ?? child.year,
        createdAt: DateTime.parse(now),
        updatedAt: DateTime.parse(now),
      );
      await db.insert('price_entries', copied.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace);
      created.add(copied);
      await _copyChildren(db, child.id, newId, idMap, created,
          newYear: newYear);
    }
  }

  Future<void> copyYear(String sourceYear, String targetYear) async {
    final roots = await getRoots(sourceYear);
    for (final root in roots) {
      await copySubtree(root.id, '', newYear: targetYear);
    }
  }

  Future<List<String>> getYears() async {
    final db = await DatabaseHelper().database;
    final maps = await db.rawQuery(
      'SELECT DISTINCT year FROM price_entries ORDER BY year DESC',
    );
    return maps.map((m) => m['year'] as String).toList();
  }

  Future<List<PriceEntry>> searchByCustomer(
    String year,
    String customerName,
  ) async {
    final db = await DatabaseHelper().database;
    final maps = await db.query(
      'price_entries',
      where: 'year = ? AND name LIKE ? AND unit_price IS NULL',
      whereArgs: [year, '%$customerName%'],
      orderBy: 'sort_order, name',
    );
    return maps.map((m) => PriceEntry.fromMap(m)).toList();
  }
}
