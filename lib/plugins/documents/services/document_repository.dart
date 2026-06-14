import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../../../services/database_helper.dart';
import '../../../services/hash_utils.dart';
import '../../../services/hash_chain_verify_result.dart';
import '../models/document_model.dart';
import '../models/document_edit_log.dart';

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
    conditions.add('d.is_current IS NOT NULL');
    conditions.add('d.is_current = 1');

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
      final existing = await txn.query(
        'documents',
        columns: ['id', 'is_locked', 'content_hash', 'version'],
        where: 'id = ?',
        whereArgs: [document.id],
        limit: 1,
      );

      if (existing.isNotEmpty && (existing.first['is_locked'] as int?) == 1) {
        throw Exception('ロック済み伝票は変更できません');
      }

      int newVersion = 1;
      String? previousHash;
      if (existing.isNotEmpty) {
        newVersion = ((existing.first['version'] as int?) ?? 1) + 1;
        previousHash = existing.first['content_hash'] as String?;
      }

      final contentHash = HashUtils.calculateDocumentHash(
        id: document.id,
        documentType: document.documentType.name,
        customerId: document.customerId,
        customerName: document.customerName,
        documentNumber: document.documentNumber,
        date: document.date.toIso8601String().substring(0, 10),
        total: document.total,
        status: document.status,
        subject: document.subject,
        includeTax: document.includeTax,
        taxRate: document.taxRate,
        items: document.items.map((i) => <String, dynamic>{
          'productId': i.productId,
          'productName': i.productName,
          'quantity': i.quantity,
          'unitPrice': i.unitPrice,
          'discountAmount': i.discountAmount,
          'discountRate': i.discountRate,
        }).toList(),
        isLocked: document.isLocked,
        version: newVersion,
        previousHash: previousHash,
      );

      final docMap = document.toMap();
      docMap['version'] = newVersion;
      docMap['previous_hash'] = previousHash ?? '';
      docMap['content_hash'] = contentHash;

      if (existing.isNotEmpty) {
        await txn.update(
          'documents',
          {'is_current': 0},
          where: 'id = ?',
          whereArgs: [document.id],
        );
      }

      await txn.insert(
        'documents',
        docMap,
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
      final existing = await txn.query(
        'documents',
        columns: ['is_locked'],
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      if (existing.isNotEmpty && (existing.first['is_locked'] as int?) == 1) {
        throw Exception('ロック済み伝票は削除できません');
      }
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

  Future<HashChainVerifyResult> verifyAllLocked() async {
    final db = await _db;
    final rows = await db.query(
      'documents',
      where: 'is_locked = 1 AND content_hash IS NOT NULL',
      orderBy: 'date DESC',
    );
    final broken = <String>[];
    for (final row in rows) {
      final storedHash = row['content_hash'] as String?;
      if (storedHash == null) continue;
      final doc = DocumentModel.fromMap(row);
      final items = await _fetchItems(db, doc.id);

      final recomputed = HashUtils.calculateDocumentHash(
        id: doc.id,
        documentType: doc.documentType.name,
        customerId: doc.customerId,
        customerName: doc.customerName,
        documentNumber: doc.documentNumber,
        date: doc.date.toIso8601String().substring(0, 10),
        total: doc.total,
        status: doc.status,
        subject: doc.subject,
        includeTax: doc.includeTax,
        taxRate: doc.taxRate,
        items: items.map((i) => <String, dynamic>{
          'productId': i.productId,
          'productName': i.productName,
          'quantity': i.quantity,
          'unitPrice': i.unitPrice,
          'discountAmount': i.discountAmount,
          'discountRate': i.discountRate,
        }).toList(),
        isLocked: doc.isLocked,
        version: doc.version,
        previousHash: doc.previousHash,
      );

      if (recomputed != storedHash) {
        broken.add(doc.id);
      }
    }
    return HashChainVerifyResult(
      checked: rows.length,
      brokenIds: broken,
      verifiedAt: DateTime.now(),
    );
  }

  Future<void> addEditLog(String docId, String action) async {
    final db = await _db;
    await db.insert('document_edit_logs', {
      'document_id': docId,
      'action': action,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<List<DocumentEditLog>> getEditLogs(String docId) async {
    final db = await _db;
    final maps = await db.query('document_edit_logs',
      where: 'document_id = ?', whereArgs: [docId],
      orderBy: 'created_at DESC', limit: 5);
    return maps.map(DocumentEditLog.fromMap).toList();
  }
}
