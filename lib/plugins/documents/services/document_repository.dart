import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../../../services/database_helper.dart';
import '../models/document_model.dart';

class DocumentRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  Future<Database> get _db => _dbHelper.database;

  Future<List<DocumentModel>> fetchAll({DocumentType? filterType, String query = '', String? statusFilter, DateTime? dateFrom, DateTime? dateTo}) async {
    final db = await _db;
    final conditions = <String>[];
    final args = <dynamic>[];

    if (filterType != null) {
      conditions.add('d.document_type = ?');
      args.add(filterType.name);
    }
    if (query.isNotEmpty) {
      conditions.add('(d.document_number LIKE ? OR d.customer_name LIKE ?)');
      args.addAll(['%$query%', '%$query%']);
    }
    if (statusFilter != null && statusFilter.isNotEmpty) {
      conditions.add('d.status = ?');
      args.add(statusFilter);
    }
    if (dateFrom != null) {
      conditions.add('d.date >= ?');
      args.add(dateFrom.toIso8601String().substring(0, 10));
    }
    if (dateTo != null) {
      conditions.add('d.date <= ?');
      args.add(dateTo.toIso8601String().substring(0, 10));
    }
    conditions.add('d.status IS NOT NULL');

    final where = conditions.isNotEmpty ? 'WHERE ${conditions.join(' AND ')}' : '';
    final maps = await db.rawQuery('''
      SELECT d.* FROM documents d
      $where
      ORDER BY d.date DESC
    ''', args);

    final documents = <DocumentModel>[];
    for (final map in maps) {
      final items = await _fetchItems(db, map['id'] as String);
      documents.add(DocumentModel.fromMap(map, items: items));
    }
    return documents;
  }

  Future<DocumentModel?> fetchById(String id) async {
    final db = await _db;
    final maps = await db.query('documents', where: 'id = ?', whereArgs: [id], limit: 1);
    if (maps.isEmpty) return null;
    final items = await _fetchItems(db, id);
    return DocumentModel.fromMap(maps.first, items: items);
  }

  Future<List<DocumentItem>> _fetchItems(Database db, String documentId) async {
    final maps = await db.query(
      'document_items',
      where: 'document_id = ?',
      whereArgs: [documentId],
    );
    return maps.map((m) => DocumentItem.fromMap(m)).toList();
  }

  Future<void> save(DocumentModel document) async {
    final db = await _db;
    await db.transaction((txn) async {
      await txn.insert(
        'documents',
        document.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      for (final item in document.items) {
        await txn.insert(
          'document_items',
          item.toMap(document.id),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  Future<void> delete(String id) async {
    final db = await _db;
    await db.transaction((txn) async {
      await txn.delete('document_items', where: 'document_id = ?', whereArgs: [id]);
      await txn.delete('documents', where: 'id = ?', whereArgs: [id]);
    });
  }

  Future<String> generateDocumentNumber(DocumentType type) async {
    final db = await _db;
    final prefix = switch (type) {
      DocumentType.estimation => 'MG',
      DocumentType.order => 'JU',
      DocumentType.delivery => 'NH',
      DocumentType.invoice => 'SK',
      DocumentType.receipt => 'RY',
    };
    final today = DateTime.now();
    final yymm = '${today.year % 100}${today.month.toString().padLeft(2, '0')}';
    final results = await db.rawQuery(
      "SELECT COUNT(*) as cnt FROM documents WHERE document_number LIKE ?",
      ['$prefix$yymm%'],
    );
    final count = (results.first['cnt'] as int? ?? 0) + 1;
    return '$prefix$yymm-${count.toString().padLeft(4, '0')}';
  }

  String generateId() => const Uuid().v4();
}
