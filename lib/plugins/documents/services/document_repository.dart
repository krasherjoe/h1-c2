import 'package:flutter/foundation.dart' show debugPrint;
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import 'dart:convert';
import '../../../services/database_helper.dart';
import '../../../services/hash_utils.dart';
import '../../../services/hash_chain_verify_result.dart';
import '../../../services/history_db_service.dart';
import '../../../services/fiscal_year_service.dart';
import '../../../services/company_repository.dart';
import '../../../services/project_repository.dart';
import '../../../services/sales_queue_repository.dart';
import '../models/document_model.dart';
import '../models/document_edit_log.dart';

class DocumentRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final _projectRepo = ProjectRepository();
  final _salesQueueRepo = SalesQueueRepository();

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
    conditions.add('d.deleted_at IS NULL');
    conditions.add('d.status IS NOT NULL');
    conditions.add('d.is_current IS NOT NULL');
    conditions.add('d.is_current = 1');

    final where = conditions.isNotEmpty ? 'WHERE ${conditions.join(' AND ')}' : '';
    final maps = await db.rawQuery('''
      SELECT d.* FROM documents d
      $where
      ORDER BY d.date DESC, d.rowid DESC
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
    final maps = await db.query('documents',
      where: 'id = ? AND deleted_at IS NULL', whereArgs: [id], limit: 1);
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
    if (document.isConfirmed && !document.isRedInvoice) {
      final company = await CompanyRepository().getCompanyInfo();
      if (company != null && FiscalYearService.isLocked(document.date, company.fiscalYearStart, company.closingDay)) {
        throw Exception('前年度の確定伝票は編集できません');
      }
    }
    final db = await _db;
    bool isUpdate = false;
    Map<String, dynamic>? savedSnapshot;
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

      isUpdate = existing.isNotEmpty;
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
          'maker': i.maker,
          'productCode': i.productCode,
          'quantity': i.quantity,
          'unitPrice': i.unitPrice,
          'discountAmount': i.discountAmount,
          'discountRate': i.discountRate,
          'notes': i.notes,
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

      final itemMaps = <Map<String, dynamic>>[];
      for (final item in document.items) {
        final im = item.toMap(document.id);
        itemMaps.add(im);
        await txn.insert(
          'document_items',
          im,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      savedSnapshot = Map<String, dynamic>.from(docMap);
      savedSnapshot!['_items'] = itemMaps;
    });

    // ワークフロー開始フック（案件に紐づく納品書の場合）
    if (document.projectId != null && 
        document.documentType == DocumentType.delivery && 
        document.status == 'confirmed') {
      try {
        // 売上処理キューに追加
        await _salesQueueRepo.addEntry(
          projectId: document.projectId!,
          documentId: document.id,
          deliveryDate: document.date,
          totalAmount: document.total,
          customerId: document.customerId,
          customerName: document.customerName,
        );
        debugPrint('[DocRepo] Sales queue entry added for project: ${document.projectId}');
      } catch (e) {
        debugPrint('[DocRepo] Sales queue add error: $e');
        // キュー追加失敗は伝票保存には影響しない
      }
    }

    if (savedSnapshot != null) {
      await HistoryDbService().recordChange(
        tableName: 'documents',
        rowId: document.id,
        action: isUpdate ? 'UPDATE' : 'INSERT',
        row: savedSnapshot!,
      );
    }
  }

  Future<void> delete(String id) async {
    final db = await _db;
    Map<String, dynamic>? snapshot;
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
      if (existing.isEmpty) return;

      final docRows = await txn.query('documents', where: 'id = ?', whereArgs: [id], limit: 1);
      if (docRows.isEmpty) return;
      final itemRows = await txn.query('document_items', where: 'document_id = ?', whereArgs: [id]);
      final snap = Map<String, dynamic>.from(docRows.first);
      snap['_items'] = itemRows;
      snapshot = snap;

      await txn.update(
        'documents',
        {'deleted_at': DateTime.now().toIso8601String()},
        where: 'id = ?',
        whereArgs: [id],
      );
    });

    if (snapshot != null) {
      await HistoryDbService().recordChange(
        tableName: 'documents',
        rowId: id,
        action: 'DELETE',
        row: snapshot!,
      );
    }
  }

  /// ソフトデリートから30日以上経過したレコードを完全削除
  Future<int> purgeSoftDeleted() async {
    final db = await _db;
    final cutoff = DateTime.now().subtract(const Duration(days: 30)).toIso8601String();
    final targets = await db.query('documents',
      columns: ['id'],
      where: 'deleted_at IS NOT NULL AND deleted_at < ?',
      whereArgs: [cutoff],
    );
    if (targets.isEmpty) return 0;
    final ids = targets.map((r) => r['id'] as String).toList();
    await db.transaction((txn) async {
      for (final id in ids) {
        await txn.delete('document_items', where: 'document_id = ?', whereArgs: [id]);
        await txn.delete('documents', where: 'id = ?', whereArgs: [id]);
      }
    });
    debugPrint('[DocRepo] パージ完了: ${ids.length}件');
    return ids.length;
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
      "SELECT COUNT(*) as cnt FROM documents WHERE document_number LIKE ? AND deleted_at IS NULL",
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

  Future<void> addReceipt(String documentId, int amount) async {
    final db = await _db;
    Map<String, dynamic>? docMap;
    await db.transaction((txn) async {
      final rows = await txn.query(
        'documents',
        where: 'id = ? AND deleted_at IS NULL',
        whereArgs: [documentId],
        limit: 1,
      );
      if (rows.isEmpty) throw Exception('伝票が見つかりません');
      final docType = rows.first['document_type'] as String? ?? '';
      if (docType != 'invoice' && docType != 'receipt') {
        throw Exception('入金記録は請求書または領収書のみ可能です');
      }
      final total = rows.first['total'] as int? ?? 0;
      final currentReceived = (rows.first['received_amount'] as int?) ?? 0;
      final newReceived = currentReceived + amount;
      final paymentStatus = newReceived >= total ? 'paid' : (newReceived > 0 ? 'partial' : 'unpaid');
      await txn.update(
        'documents',
        {'received_amount': newReceived, 'payment_status': paymentStatus},
        where: 'id = ?',
        whereArgs: [documentId],
      );
      docMap = {'total': total, 'received_amount': newReceived, 'payment_status': paymentStatus};
    });
    if (docMap != null) {
      docMap!['_action'] = 'addReceipt';
      docMap!['_receipt_amount'] = amount;
      await HistoryDbService().recordChange(
        tableName: 'documents',
        rowId: documentId,
        action: 'RECEIPT',
        row: docMap!,
      );
    }
  }

  Future<void> updatePaymentStatus(String documentId) async {
    final db = await _db;
    final rows = await db.query(
      'documents',
      columns: ['total', 'received_amount'],
      where: 'id = ?',
      whereArgs: [documentId],
      limit: 1,
    );
    if (rows.isEmpty) return;
    final total = rows.first['total'] as int? ?? 0;
    final received = (rows.first['received_amount'] as int?) ?? 0;
    String paymentStatus;
    if (received >= total) {
      paymentStatus = 'paid';
    } else if (received > 0) {
      paymentStatus = 'partial';
    } else {
      paymentStatus = 'unpaid';
    }
    await db.update(
      'documents',
      {'payment_status': paymentStatus},
      where: 'id = ?',
      whereArgs: [documentId],
    );
  }

  Future<List<DocumentModel>> getUnpaidDocuments() async {
    final db = await _db;
    final maps = await db.rawQuery('''
      SELECT d.* FROM documents d
      WHERE d.deleted_at IS NULL
        AND d.is_current = 1
        AND d.document_type = 'invoice'
        AND d.status = 'confirmed'
        AND (d.payment_status IS NULL OR d.payment_status IN ('unpaid', 'partial'))
      ORDER BY d.date DESC
    ''');
    final docs = <DocumentModel>[];
    for (final map in maps) {
      final items = await _fetchItems(db, map['id'] as String);
      docs.add(DocumentModel.fromMap(map, items: items));
    }
    return docs;
  }

  Future<int> getTotalUnpaidAmount() async {
    final db = await _db;
    final result = await db.rawQuery('''
      SELECT COALESCE(SUM(d.total - COALESCE(d.received_amount, 0)), 0) AS total
      FROM documents d
      WHERE d.deleted_at IS NULL
        AND d.is_current = 1
        AND d.document_type = 'invoice'
        AND d.status = 'confirmed'
        AND (d.payment_status IS NULL OR d.payment_status IN ('unpaid', 'partial'))
    ''');
    return (result.first['total'] as num?)?.toInt() ?? 0;
  }

  Future<Map<String, int>> getUnpaidAmountByCustomer() async {
    final db = await _db;
    final result = await db.rawQuery('''
      SELECT d.customer_name,
             SUM(d.total - COALESCE(d.received_amount, 0)) AS unpaid
      FROM documents d
      WHERE d.deleted_at IS NULL
        AND d.is_current = 1
        AND d.document_type = 'invoice'
        AND d.status = 'confirmed'
        AND (d.payment_status IS NULL OR d.payment_status IN ('unpaid', 'partial'))
      GROUP BY d.customer_name
      ORDER BY unpaid DESC
    ''');
    return {for (final r in result) (r['customer_name'] as String? ?? '不明'): (r['unpaid'] as num?)?.toInt() ?? 0};
  }

  Future<Map<String, int>> getMonthlyInvoiceTotals({int months = 12}) async {
    final db = await _db;
    final result = await db.rawQuery('''
      SELECT substr(d.date, 1, 7) AS month,
             SUM(d.total) AS total
      FROM documents d
      WHERE d.deleted_at IS NULL
        AND d.is_current = 1
        AND d.document_type IN ('invoice', 'receipt')
        AND d.status = 'confirmed'
      GROUP BY month
      ORDER BY month DESC
      LIMIT ?
    ''', [months]);
    return {for (final r in result) (r['month'] as String? ?? ''): (r['total'] as num?)?.toInt() ?? 0};
  }

  Future<void> addEditLog(String docId, String action, {String details = ''}) async {
    final db = await _db;
    await db.insert('document_edit_logs', {
      'document_id': docId,
      'action': action,
      'details': details,
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

  /// PDF生成JSONを電子帳簿保存法テーブルに保存（ハッシュチェーン付き）
  Future<void> saveElectronicBookkeeping({
    required String documentType,
    required String documentId,
    required Map<String, dynamic> pdfJson,
  }) async {
    final db = await _db;
    await db.transaction((txn) async {
      // 前回のバージョンのハッシュを取得
      String previousHash = '';
      int currentVersion = 0;
      final existing = await txn.query(
        'electronic_bookkeeping',
        columns: ['content_hash', 'version'],
        where: 'document_type = ? AND document_id = ?',
        whereArgs: [documentType, documentId],
        orderBy: 'version DESC',
        limit: 1,
      );
      if (existing.isNotEmpty) {
        previousHash = (existing.first['content_hash'] as String?) ?? '';
        currentVersion = (existing.first['version'] as int?) ?? 0;
      }

      final newVersion = currentVersion + 1;
      final pdfJsonString = jsonEncode(pdfJson);
      
      // PDF JSONのハッシュを計算
      final contentHash = HashUtils.calculateSha256(
        '$pdfJsonString|$previousHash',
      );

      // 電子帳簿保存法テーブルに保存
      final id = '${documentType}_${documentId}_v$newVersion';
      await txn.insert(
        'electronic_bookkeeping',
        {
          'id': id,
          'document_type': documentType,
          'document_id': documentId,
          'pdf_json': pdfJsonString,
          'content_hash': contentHash,
          'previous_hash': previousHash,
          'version': newVersion,
          'created_at': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
  }

  /// PDF生成JSONのハッシュチェーンを検証する
  Future<HashChainVerifyResult> verifyElectronicBookkeeping({
    String? documentType,
    String? documentId,
  }) async {
    final db = await _db;
    final conditions = <String>[];
    final args = <dynamic>[];
    
    if (documentType != null) {
      conditions.add('document_type = ?');
      args.add(documentType);
    }
    if (documentId != null) {
      conditions.add('document_id = ?');
      args.add(documentId);
    }
    
    final where = conditions.isNotEmpty ? 'WHERE ${conditions.join(' AND ')}' : '';
    final rows = await db.query(
      'electronic_bookkeeping',
      where: where.isNotEmpty ? where : null,
      whereArgs: args.isNotEmpty ? args : null,
      orderBy: 'created_at DESC',
      limit: 100,
    );
    
    final broken = <String>[];
    for (final row in rows) {
      final storedHash = row['content_hash'] as String?;
      if (storedHash == null) continue;
      
      final pdfJsonString = row['pdf_json'] as String?;
      final previousHash = row['previous_hash'] as String? ?? '';
      
      if (pdfJsonString == null) {
        broken.add(row['id'] as String);
        continue;
      }
      
      // ハッシュを再計算
      final recomputed = HashUtils.calculateSha256(
        '$pdfJsonString|$previousHash',
      );
      
      if (recomputed != storedHash) {
        broken.add(row['id'] as String);
        continue;
      }
      
      // 前バージョンのハッシュを検証
      final version = row['version'] as int? ?? 1;
      if (version > 1 && previousHash.isNotEmpty) {
        final prevRows = await db.query(
          'electronic_bookkeeping',
          columns: ['content_hash'],
          where: 'document_type = ? AND document_id = ? AND version = ?',
          whereArgs: [row['document_type'], row['document_id'], version - 1],
          limit: 1,
        );
        if (prevRows.isNotEmpty) {
          final prevContentHash = prevRows.first['content_hash'] as String?;
          if (prevContentHash != null && previousHash != prevContentHash) {
            broken.add(row['id'] as String);
          }
        }
      }
    }
    
    return HashChainVerifyResult(
      checked: rows.length,
      brokenIds: broken,
      verifiedAt: DateTime.now(),
    );
  }

  /// 電子帳簿保存法テーブルからPDF生成JSONを取得する
  Future<Map<String, dynamic>?> getElectronicBookkeepingPdfJson({
    required String documentType,
    required String documentId,
    int? version,
  }) async {
    final db = await _db;
    final where = version != null
        ? 'document_type = ? AND document_id = ? AND version = ?'
        : 'document_type = ? AND document_id = ?';
    final whereArgs = version != null
        ? [documentType, documentId, version]
        : [documentType, documentId];
    
    final maps = await db.query(
      'electronic_bookkeeping',
      where: where,
      whereArgs: whereArgs,
      orderBy: 'version DESC',
      limit: 1,
    );
    
    if (maps.isEmpty) return null;
    final pdfJsonString = maps.first['pdf_json'] as String?;
    if (pdfJsonString == null) return null;
    return jsonDecode(pdfJsonString) as Map<String, dynamic>;
  }

  /// 取消伝票（赤伝）を作成する
  Future<DocumentModel> createCreditNote(DocumentModel original) async {
    if (!original.isConfirmed || original.isLocked == false) {
      throw Exception('確定済みの伝票のみ赤伝を発行できます');
    }
    if (original.isRedInvoice) {
      throw Exception('赤伝に対する赤伝は発行できません');
    }
    final newId = const Uuid().v4();
    final docNumber = await generateDocumentNumber(original.documentType);
    final creditNote = original.toCreditNote(
      newId: newId,
      newDocumentNumber: docNumber,
      originalSubject: '取消: ${original.documentNumber} ${original.customerName}',
    );
    await save(creditNote);
    await addEditLog(original.id, '赤伝発行',
      details: '取消伝票 #$docNumber を発行');
    return creditNote;
  }
}
