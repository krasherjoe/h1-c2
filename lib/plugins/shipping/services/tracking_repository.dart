import 'package:sqflite/sqflite.dart';
import '../models/tracking_model.dart';
import '../models/shipping_label_model.dart';
import '../models/shipping_address_model.dart';
import '../../../services/database_helper.dart';

/// 追跡リポジトリ
class TrackingRepository {
  Future<List<Tracking>> getAll() async {
    final db = await DatabaseHelper().database;
    final maps = await db.query('trackings');
    return maps.map((map) => Tracking.fromMap(map)).toList();
  }

  Future<Tracking?> getById(String id) async {
    final db = await DatabaseHelper().database;
    final maps = await db.query(
      'trackings',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isEmpty) return null;
    return Tracking.fromMap(maps.first);
  }

  Future<void> save(Tracking tracking) async {
    final db = await DatabaseHelper().database;
    await db.insert(
      'trackings',
      tracking.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> delete(String id) async {
    final db = await DatabaseHelper().database;
    await db.delete('trackings', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Tracking>> getByEntity(String entityType, String entityId) async {
    final db = await DatabaseHelper().database;
    final maps = await db.query(
      'trackings',
      where: 'entity_type = ? AND entity_id = ?',
      whereArgs: [entityType, entityId],
    );
    return maps.map((map) => Tracking.fromMap(map)).toList();
  }

  Future<Tracking?> getByLabelId(String labelId) async {
    final db = await DatabaseHelper().database;
    final maps = await db.query(
      'trackings',
      where: 'label_id = ?',
      whereArgs: [labelId],
    );
    if (maps.isEmpty) return null;
    return Tracking.fromMap(maps.first);
  }
}

/// 送り状リポジトリ
class ShippingLabelRepository {
  Future<List<ShippingLabel>> getAll() async {
    final db = await DatabaseHelper().database;
    final maps = await db.query('shipping_labels');
    return maps.map((map) => ShippingLabel.fromMap(map as Map<String, dynamic>)).toList();
  }

  Future<ShippingLabel?> getById(String id) async {
    final db = await DatabaseHelper().database;
    final maps = await db.query(
      'shipping_labels',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isEmpty) return null;
    return ShippingLabel.fromMap(maps.first as Map<String, dynamic>);
  }

  Future<void> save(ShippingLabel label) async {
    final db = await DatabaseHelper().database;
    await db.insert(
      'shipping_labels',
      label.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> delete(String id) async {
    final db = await DatabaseHelper().database;
    await db.delete('shipping_labels', where: 'id = ?', whereArgs: [id]);
  }
}

/// 送付先リポジトリ
class ShippingAddressRepository {
  Future<List<ShippingAddress>> getAll() async {
    final db = await DatabaseHelper().database;
    final maps = await db.query('shipping_addresses');
    return maps.map((map) => ShippingAddress.fromMap(map as Map<String, dynamic>)).toList();
  }

  Future<ShippingAddress?> getById(String id) async {
    final db = await DatabaseHelper().database;
    final maps = await db.query(
      'shipping_addresses',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isEmpty) return null;
    return ShippingAddress.fromMap(maps.first as Map<String, dynamic>);
  }

  Future<void> save(ShippingAddress address) async {
    final db = await DatabaseHelper().database;
    await db.insert(
      'shipping_addresses',
      address.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> delete(String id) async {
    final db = await DatabaseHelper().database;
    await db.delete('shipping_addresses', where: 'id = ?', whereArgs: [id]);
  }

  Future<ShippingAddress?> getDefault() async {
    final db = await DatabaseHelper().database;
    final maps = await db.query(
      'shipping_addresses',
      where: 'is_default = ?',
      whereArgs: [1],
    );
    if (maps.isEmpty) return null;
    return ShippingAddress.fromMap(maps.first);
  }

  Future<void> setDefault(String id) async {
    final db = await DatabaseHelper().database;
    await db.update('shipping_addresses', {'is_default': 0});
    await db.update('shipping_addresses', {'is_default': 1}, where: 'id = ?', whereArgs: [id]);
  }
}
