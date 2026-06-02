import 'package:sqflite/sqflite.dart';
import '../models/price_entry.dart';
import 'price_list_repository.dart';

abstract class PriceListCommand {
  Future<void> execute(Database db);
  Future<void> undo(Database db);
  String get description;
}

class MoveNodeCommand implements PriceListCommand {
  final String nodeId;
  final String? oldParentId;
  final String? newParentId;

  MoveNodeCommand(this.nodeId, this.oldParentId, this.newParentId);

  @override
  Future<void> execute(Database db) async {
    final now = DateTime.now().toIso8601String();
    await db.update(
      'price_entries',
      {'parent_id': newParentId, 'updated_at': now},
      where: 'id = ?',
      whereArgs: [nodeId],
    );
  }

  @override
  Future<void> undo(Database db) async {
    final now = DateTime.now().toIso8601String();
    await db.update(
      'price_entries',
      {'parent_id': oldParentId, 'updated_at': now},
      where: 'id = ?',
      whereArgs: [nodeId],
    );
  }

  @override
  String get description => '移動';
}

class RenameNodeCommand implements PriceListCommand {
  final String nodeId;
  final String oldName;
  final String newName;

  RenameNodeCommand(this.nodeId, this.oldName, this.newName);

  @override
  Future<void> execute(Database db) async {
    final now = DateTime.now().toIso8601String();
    await db.update(
      'price_entries',
      {'name': newName, 'updated_at': now},
      where: 'id = ?',
      whereArgs: [nodeId],
    );
  }

  @override
  Future<void> undo(Database db) async {
    final now = DateTime.now().toIso8601String();
    await db.update(
      'price_entries',
      {'name': oldName, 'updated_at': now},
      where: 'id = ?',
      whereArgs: [nodeId],
    );
  }

  @override
  String get description => '名前変更';
}

class EditPriceCommand implements PriceListCommand {
  final String nodeId;
  final int? oldPrice;
  final int? newPrice;

  EditPriceCommand(this.nodeId, this.oldPrice, this.newPrice);

  @override
  Future<void> execute(Database db) async {
    final now = DateTime.now().toIso8601String();
    await db.update(
      'price_entries',
      {'unit_price': newPrice, 'updated_at': now},
      where: 'id = ?',
      whereArgs: [nodeId],
    );
  }

  @override
  Future<void> undo(Database db) async {
    final now = DateTime.now().toIso8601String();
    await db.update(
      'price_entries',
      {'unit_price': oldPrice, 'updated_at': now},
      where: 'id = ?',
      whereArgs: [nodeId],
    );
  }

  @override
  String get description => '価格変更';
}

class DeleteNodeCommand implements PriceListCommand {
  final PriceEntry node;
  final List<PriceEntry> children;

  DeleteNodeCommand(this.node, this.children);

  @override
  Future<void> execute(Database db) async {
    await db.delete('price_entries', where: 'id = ?', whereArgs: [node.id]);
    for (final child in children) {
      await db.delete('price_entries', where: 'id = ?', whereArgs: [child.id]);
    }
  }

  @override
  Future<void> undo(Database db) async {
    await db.insert('price_entries', node.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
    for (final child in children) {
      await db.insert('price_entries', child.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }

  @override
  String get description => '削除';
}

class CreateNodeCommand implements PriceListCommand {
  final PriceEntry entry;

  CreateNodeCommand(this.entry);

  @override
  Future<void> execute(Database db) async {
    await db.insert('price_entries', entry.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<void> undo(Database db) async {
    await db.delete('price_entries', where: 'id = ?', whereArgs: [entry.id]);
  }

  @override
  String get description => '作成';
}

class CopyNodeCommand implements PriceListCommand {
  final String sourceId;
  final String targetParentId;
  final List<String> createdIds;

  CopyNodeCommand(this.sourceId, this.targetParentId, this.createdIds);

  @override
  Future<void> execute(Database db) async {
    final repo = PriceListRepository();
    await repo.copySubtree(sourceId, targetParentId);
  }

  @override
  Future<void> undo(Database db) async {
    for (final id in createdIds) {
      await db.delete('price_entries', where: 'id = ?', whereArgs: [id]);
    }
  }

  @override
  String get description => 'コピー';
}

class UndoStack {
  final List<PriceListCommand> _history = [];
  final List<PriceListCommand> _redoStack = [];
  static const maxHistory = 50;

  void push(PriceListCommand cmd) {
    _history.add(cmd);
    if (_history.length > maxHistory) _history.removeAt(0);
    _redoStack.clear();
  }

  Future<void> undo(Database db) async {
    if (_history.isEmpty) return;
    final cmd = _history.removeLast();
    await cmd.undo(db);
    _redoStack.add(cmd);
  }

  Future<void> redo(Database db) async {
    if (_redoStack.isEmpty) return;
    final cmd = _redoStack.removeLast();
    await cmd.execute(db);
    _history.add(cmd);
  }

  bool get canUndo => _history.isNotEmpty;
  bool get canRedo => _redoStack.isNotEmpty;
  int get undoCount => _history.length;
  int get redoCount => _redoStack.length;
  String get lastDescription =>
      _history.isNotEmpty ? _history.last.description : '';
}
