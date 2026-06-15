import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:crypto/crypto.dart';
import '../models/invoice_models.dart';
import '../models/customer_model.dart';
import '../models/receipt_model.dart';
import '../models/payment_schedule_model.dart' show PaymentStatus;
import 'database_helper.dart';
import 'activity_log_repository.dart';
import 'hash_chain_verify_result.dart';

class InvoiceRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final ActivityLogRepository _logRepo = ActivityLogRepository();

  Future<void> saveInvoice(Invoice invoice) async {
    try {
      final db = await _dbHelper.database;

      final existing = await db.query(
        'invoices',
        columns: ['id', 'is_locked', 'meta_hash', 'content_hash'],
        where: 'id = ?',
        whereArgs: [invoice.id],
        limit: 1,
      );
      if (existing.isNotEmpty) {
        final existingIsLocked =
            (existing.first['is_locked'] as int? ?? 0) == 1;
        if (existingIsLocked) {
          throw Exception(
            'ハッシュチェーン保護: ロック済み伝票 ${invoice.id} は変更できません。'
            '\n複写または新規IDで保存してください。',
          );
        }
      }

      final Invoice toSave = invoice.isDraft
          ? invoice
          : invoice.copyWith(isLocked: true);

      await db.transaction((txn) async {
        int newVersion = 1;
        String? oldContentHash;
        final existingCurrent = await txn.query(
          'invoices',
          where: 'id = ? AND is_current = 1',
          whereArgs: [invoice.id],
          limit: 1,
        );
        if (existingCurrent.isNotEmpty) {
          newVersion =
              ((existingCurrent.first['version'] as num?)?.toInt() ?? 1) + 1;
          oldContentHash = existingCurrent.first['content_hash'] as String?;
          await txn.update(
            'invoices',
            {'is_current': 0, 'valid_to': DateTime.now().toIso8601String()},
            where: 'id = ? AND is_current = 1',
            whereArgs: [invoice.id],
          );
        }

        final Invoice savingWithContact = toSave.copyWith(
          version: newVersion,
          previousHash: oldContentHash,
          isSynced: false,
          updatedAt: DateTime.now(),
        );

        final conflictCheck = await txn.query(
          'invoices',
          where: 'id = ? AND version = ?',
          whereArgs: [invoice.id, newVersion],
          limit: 1,
        );
        if (conflictCheck.isEmpty) {
          await txn.insert('invoices', savingWithContact.toMap());
        }

        if (existingCurrent.isNotEmpty) {
          await txn.update(
            'invoices',
            {'next_version_id': invoice.id},
            where: 'id = ? AND version = ? AND is_current = 0',
            whereArgs: [invoice.id, newVersion - 1],
          );
        }

        await txn.delete(
          'invoice_items',
          where: 'invoice_id = ?',
          whereArgs: [invoice.id],
        );

        for (var item in invoice.items) {
          await txn.insert('invoice_items', item.toMap(invoice.id));
        }
      });

      await _logRepo.logAction(
        action: "SAVE_INVOICE",
        targetType: "INVOICE",
        targetId: invoice.id,
        details:
            "種別: ${invoice.documentTypeName}, 取引先: ${invoice.customerNameForDisplay}, 合計: ￥${invoice.totalAmount}",
      );
    } catch (e) {
      debugPrint('[InvoiceRepo] saveInvoice error: $e');
      rethrow;
    }
  }

  Future<void> updateInvoice(Invoice invoice) async {
    await saveInvoice(invoice);
  }

  Future<List<Invoice>> getAllInvoices(
    List<Customer> customers, {
    DocumentType? documentTypeFilter,
    bool excludeCanceled = false,
  }) async {
    try {
      final db = await _dbHelper.database;
      var where = 'is_current = 1';
      final whereArgs = <dynamic>[];
      if (documentTypeFilter != null) {
        where += ' AND document_type = ?';
        whereArgs.add(documentTypeFilter.name);
      }
      if (excludeCanceled) {
        where += " AND NOT EXISTS (SELECT 1 FROM invoices red WHERE red.source_document_id = invoices.id AND red.total_amount < 0)";
      }
      final List<Map<String, dynamic>> invoiceMaps = await db.query(
        'invoices',
        where: where,
        whereArgs: whereArgs,
        orderBy: 'date DESC',
      );

      List<Invoice> invoices = [];

      for (var iMap in invoiceMaps) {
        Customer customer;
        try {
          customer = customers.firstWhere((c) => c.id == iMap['customer_id']);
        } catch (e) {
          var rows = await db.query(
            'customers',
            where: 'id = ? AND is_current = 1',
            whereArgs: [iMap['customer_id']],
            limit: 1,
          );
          if (rows.isEmpty) {
            rows = await db.query(
              'customers',
              where: 'id = ?',
              whereArgs: [iMap['customer_id']],
              limit: 1,
            );
          }
          if (rows.isNotEmpty) {
            customer = Customer.fromMap(rows.first);
          } else {
            final snapshot = iMap['customer_formal_name'] as String?;
            final cid = iMap['customer_id'] as String? ?? 'unknown';
            customer = Customer(
              id: cid,
              displayName: snapshot ?? "不明",
              formalName: snapshot ?? "不明",
            );
          }
        }

        final List<Map<String, dynamic>> itemMaps = await db.query(
          'invoice_items',
          where: 'invoice_id = ?',
          whereArgs: [iMap['id']],
        );

        final items = List.generate(
          itemMaps.length,
          (i) => InvoiceItem.fromMap(itemMaps[i]),
        );

        DocumentType docType = DocumentType.invoice;
        final docTypeRaw = iMap['document_type'];
        if (docTypeRaw is String) {
          docType = DocumentType.values.firstWhere(
            (e) => e.name == docTypeRaw,
            orElse: () => DocumentType.invoice,
          );
        }

        OrderStatus orderStatus = OrderStatus.draft;
        final statusRaw = iMap['order_status'];
        if (statusRaw is String) {
          try {
            orderStatus = OrderStatus.values.firstWhere(
              (e) => e.name == statusRaw,
              orElse: () => OrderStatus.draft,
            );
          } catch (_) {}
        }

        PaymentStatus paymentStatus = PaymentStatus.unpaid;
        final psRaw = iMap['payment_status'];
        if (psRaw is String) {
          try {
            paymentStatus = PaymentStatus.values.firstWhere(
              (e) => e.name == psRaw,
              orElse: () => PaymentStatus.unpaid,
            );
          } catch (_) {}
        }

        invoices.add(
          Invoice(
            id: iMap['id'],
            customer: customer,
            date:
                DateTime.tryParse(iMap['date'] as String? ?? '') ??
                DateTime.now(),
            items: items,
            notes: iMap['notes'],
            filePath: iMap['file_path'],
            taxRate: iMap['tax_rate'] ?? 0.10,
            documentType: docType,
            orderStatus: orderStatus,
            promisedDate: iMap['promised_date'] != null
                ? DateTime.fromMillisecondsSinceEpoch(iMap['promised_date'] as int)
                : null,
            fulfilledDate: iMap['fulfilled_date'] != null
                ? DateTime.fromMillisecondsSinceEpoch(iMap['fulfilled_date'] as int)
                : null,
            sourceDocumentId: iMap['source_document_id'],
            linkedDeliveryId: iMap['linked_delivery_id'],
            linkedInvoiceId: iMap['linked_invoice_id'],
            customerFormalNameSnapshot: iMap['customer_formal_name'],
            odooId: iMap['odoo_id'],
            isSynced: iMap['is_synced'] == 1,
            updatedAt:
                DateTime.tryParse(iMap['updated_at'] as String? ?? '') ??
                DateTime.now(),
            latitude: iMap['latitude'],
            longitude: iMap['longitude'],
            terminalId: iMap['terminal_id'] ?? "T1",
            isDraft: (iMap['is_draft'] ?? 0) == 1,
            subject: iMap['subject'],
            isLocked: (iMap['is_locked'] ?? 0) == 1,
            contactVersionId: iMap['contact_version_id'],
            contactEmailSnapshot: iMap['contact_email_snapshot'],
            contactTelSnapshot: iMap['contact_tel_snapshot'],
            contactAddressSnapshot: iMap['contact_address_snapshot'],
            companySnapshot: iMap['company_snapshot'],
            companySealHash: iMap['company_seal_hash'],
            metaJson: iMap['meta_json'],
            metaHash: iMap['meta_hash'],
            totalDiscountAmount: iMap['total_discount_amount'],
            totalDiscountRate: iMap['total_discount_rate'],
            isReceiptIssued: (iMap['is_receipt_issued'] ?? 0) == 1,
            receiptIssuedAt: iMap['receipt_issued_at'] != null
                ? DateTime.tryParse(iMap['receipt_issued_at'])
                : null,
            paymentStatus: paymentStatus,
            receivedAmount: iMap['received_amount'] as int? ?? 0,
            priceAdjustmentType: iMap['price_adjustment_type'] as String?,
            priceAdjustmentUnit: iMap['price_adjustment_unit'] as int?,
            bankAccount: iMap['bank_account'] as String?,
            projectId: iMap['project_id'] as String?,
            includeTax: (iMap['include_tax'] ?? 1) == 1,
            isTaxInclusiveMode: (iMap['is_tax_inclusive_mode'] ?? 0) == 1,
            isTestDocument: (iMap['is_test_document'] ?? 0) == 1,
            printedAt: iMap['printed_at'] as String?,
            emailSentAt: iMap['email_sent_at'] as String?,
            version: (iMap['version'] as num?)?.toInt() ?? 1,
            isCurrent: (iMap['is_current'] ?? 1) == 1,
            previousHash: iMap['previous_hash'] as String?,
          ),
        );
      }
      return invoices;
    } catch (e) {
      debugPrint('[InvoiceRepo] getAllInvoices error: $e');
      rethrow;
    }
  }

  Future<Invoice?> getInvoiceById(String id, List<Customer> customers) async {
    try {
      final invoices = await getAllInvoices(customers);
      return invoices.where((i) => i.id == id).firstOrNull;
    } catch (e) {
      debugPrint('[InvoiceRepo] getInvoiceById error: $e');
      rethrow;
    }
  }

  Future<void> deleteInvoice(String id) async {
    try {
      final db = await _dbHelper.database;

      final lockCheck = await db.query(
        'invoices',
        columns: ['is_locked'],
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      if (lockCheck.isNotEmpty &&
          (lockCheck.first['is_locked'] as int? ?? 0) == 1) {
        throw Exception(
          'ハッシュチェーン保護: ロック済み伝票 $id は削除できません。'
          '\n訂正が必要な場合は赤伝（訂正伝票）を作成してください。',
        );
      }

      await db.transaction((txn) async {
        final List<Map<String, dynamic>> items = await txn.query(
          'invoice_items',
          where: 'invoice_id = ?',
          whereArgs: [id],
        );

        for (var item in items) {
          final pid = item['product_id'] as String?;
          if (pid == null) continue;
          await txn.execute(
            'UPDATE products SET stock_quantity = stock_quantity + ? WHERE id = ?',
            [item['quantity'], pid],
          );
        }

        final List<Map<String, dynamic>> maps = await txn.query(
          'invoices',
          columns: ['file_path'],
          where: 'id = ?',
          whereArgs: [id],
        );

        if (maps.isNotEmpty && maps.first['file_path'] != null) {
          final file = File(maps.first['file_path']);
          if (await file.exists()) {
            await file.delete();
          }
        }

        await txn.delete(
          'invoice_items',
          where: 'invoice_id = ?',
          whereArgs: [id],
        );
        await txn.delete('invoices', where: 'id = ?', whereArgs: [id]);
      });
    } catch (e) {
      debugPrint('[InvoiceRepo] deleteInvoice error: $e');
      rethrow;
    }
  }

  Future<List<Invoice>> searchInvoices(
    List<Customer> customers, {
    String? query,
    DocumentType? documentTypeFilter,
  }) async {
    try {
      final db = await _dbHelper.database;
      var where = 'is_current = 1';
      final whereArgs = <dynamic>[];

      if (query != null && query.isNotEmpty) {
        where += ' AND (subject LIKE ? OR id LIKE ?)';
        whereArgs.add('%$query%');
        whereArgs.add('%$query%');
      }
      if (documentTypeFilter != null) {
        where += ' AND document_type = ?';
        whereArgs.add(documentTypeFilter.name);
      }

      final List<Map<String, dynamic>> invoiceMaps = await db.query(
        'invoices',
        where: where,
        whereArgs: whereArgs,
        orderBy: 'date DESC',
        limit: 50,
      );

      if (invoiceMaps.isEmpty) return [];
      return (await getAllInvoices(customers))
          .where((i) => invoiceMaps.any((m) => m['id'] == i.id))
          .toList();
    } catch (e) {
      debugPrint('[InvoiceRepo] searchInvoices error: $e');
      rethrow;
    }
  }

  Future<int> getInvoiceCountByCustomer(String customerId) async {
    try {
      final db = await _dbHelper.database;
      final result = await db.rawQuery(
        'SELECT COUNT(*) as count FROM invoices WHERE customer_id = ? AND is_current = 1',
        [customerId],
      );
      return (result.first['count'] as int? ?? 0);
    } catch (e) {
      debugPrint('[InvoiceRepo] getInvoiceCountByCustomer error: $e');
      rethrow;
    }
  }

  Future<void> addReceipt(Receipt receipt) async {
    try {
      final db = await _dbHelper.database;

      await db.insert('receipts', receipt.toMap());

      final result = await db.rawQuery(
        'SELECT SUM(amount) as total FROM receipts WHERE invoice_id = ?',
        [receipt.invoiceId],
      );
      final totalReceived = (result.first['total'] as num?)?.toInt() ?? 0;

      final invoiceResult = await db.query(
        'invoices',
        columns: ['total_amount'],
        where: 'id = ?',
        whereArgs: [receipt.invoiceId],
        limit: 1,
      );
      if (invoiceResult.isEmpty) return;
      final totalAmount = invoiceResult.first['total_amount'] as int? ?? 0;

      final String newStatus;
      if (totalReceived >= totalAmount) {
        newStatus = PaymentStatus.paid.name;
      } else if (totalReceived > 0) {
        newStatus = PaymentStatus.partial.name;
      } else {
        newStatus = PaymentStatus.unpaid.name;
      }

      await db.update(
        'invoices',
        {
          'payment_status': newStatus,
          'received_amount': totalReceived,
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [receipt.invoiceId],
      );

      await _logRepo.logAction(
        action: 'ADD_RECEIPT',
        targetType: 'INVOICE',
        targetId: receipt.invoiceId,
        details:
            '入金額: \u00a5$totalReceived / 請求額: \u00a5$totalAmount, ステータス: $newStatus',
      );
    } catch (e) {
      debugPrint('[InvoiceRepo] addReceipt error: $e');
      rethrow;
    }
  }

  Future<void> updatePaymentStatus(String invoiceId) async {
    try {
      final db = await _dbHelper.database;

      final receiptResult = await db.rawQuery(
        'SELECT SUM(amount) as total FROM receipts WHERE invoice_id = ?',
        [invoiceId],
      );
      final totalReceived =
          (receiptResult.first['total'] as num?)?.toInt() ?? 0;

      final invoiceResult = await db.query(
        'invoices',
        columns: ['total_amount'],
        where: 'id = ?',
        whereArgs: [invoiceId],
        limit: 1,
      );
      if (invoiceResult.isEmpty) return;
      final totalAmount = invoiceResult.first['total_amount'] as int? ?? 0;

      final String newStatus;
      if (totalReceived >= totalAmount) {
        newStatus = PaymentStatus.paid.name;
      } else if (totalReceived > 0) {
        newStatus = PaymentStatus.partial.name;
      } else {
        newStatus = PaymentStatus.unpaid.name;
      }

      await db.update(
        'invoices',
        {
          'payment_status': newStatus,
          'received_amount': totalReceived,
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [invoiceId],
      );
    } catch (e) {
      debugPrint('[InvoiceRepo] updatePaymentStatus error: $e');
      rethrow;
    }
  }

  Future<Map<String, int>> getMonthlySales(int year) async {
    try {
      final db = await _dbHelper.database;
      final String yearStr = year.toString();
      final List<Map<String, dynamic>> results = await db.rawQuery(
        '''
        SELECT strftime('%m', date) as month, SUM(total_amount) as total
        FROM invoices
        WHERE strftime('%Y', date) = ? AND document_type = 'invoice' AND is_current = 1 AND is_draft = 0
        AND (source_document_id IS NULL OR total_amount >= 0)
        GROUP BY month
        ORDER BY month ASC
      ''',
        [yearStr],
      );

      Map<String, int> monthlyTotal = {};
      for (var r in results) {
        monthlyTotal[r['month']] = (r['total'] as num).toInt();
      }
      return monthlyTotal;
    } catch (e) {
      debugPrint('[InvoiceRepo] getMonthlySales error: $e');
      rethrow;
    }
  }

  Future<int> getYearlyTotal(int year) async {
    try {
      final db = await _dbHelper.database;
      final List<Map<String, dynamic>> results = await db.rawQuery(
        '''
        SELECT SUM(total_amount) as total
        FROM invoices
        WHERE strftime('%Y', date) = ? AND document_type = 'invoice' AND is_current = 1 AND is_draft = 0
        AND (source_document_id IS NULL OR total_amount >= 0)
      ''',
        [year.toString()],
      );

      if (results.isEmpty || results.first['total'] == null) return 0;
      return (results.first['total'] as num).toInt();
    } catch (e) {
      debugPrint('[InvoiceRepo] getYearlyTotal error: $e');
      rethrow;
    }
  }

  Future<int> getTotalUnpaidAmount() async {
    try {
      final db = await _dbHelper.database;
      final results = await db.rawQuery('''
        SELECT COALESCE(SUM(total_amount - received_amount), 0) as total
        FROM invoices
        WHERE document_type = 'invoice' AND is_current = 1 AND is_draft = 0
        AND (source_document_id IS NULL OR total_amount >= 0)
        AND (payment_status = 'unpaid' OR payment_status = 'partial')
      ''');
      return (results.first['total'] as num).toInt();
    } catch (e) {
      debugPrint('[InvoiceRepo] getTotalUnpaidAmount error: $e');
      rethrow;
    }
  }

  Future<Map<String, int>> getUnpaidAmountByCustomer() async {
    try {
      final db = await _dbHelper.database;
      final results = await db.rawQuery('''
        SELECT customer_id, SUM(total_amount - received_amount) as unpaid
        FROM invoices
        WHERE document_type = 'invoice' AND is_current = 1 AND is_draft = 0
        AND (source_document_id IS NULL OR total_amount >= 0)
        AND (payment_status = 'unpaid' OR payment_status = 'partial')
        GROUP BY customer_id
        ORDER BY unpaid DESC
      ''');
      Map<String, int> map = {};
      for (var r in results) {
        map[r['customer_id'] as String? ?? ''] = (r['unpaid'] as num).toInt();
      }
      return map;
    } catch (e) {
      debugPrint('[InvoiceRepo] getUnpaidAmountByCustomer error: $e');
      rethrow;
    }
  }

  Future<bool> hasRedInvoice(String sourceDocumentId) async {
    try {
      final db = await _dbHelper.database;
      final rows = await db.query(
        'invoices',
        where: 'source_document_id = ?',
        whereArgs: [sourceDocumentId],
      );
      if (rows.isEmpty) return false;
      return rows.any((r) {
        final total = r['total_amount'];
        if (total is int) return total < 0;
        if (total is num) return total < 0;
        return false;
      });
    } catch (e) {
      debugPrint('[InvoiceRepo] hasRedInvoice error: $e');
      rethrow;
    }
  }

  Future<void> dispose() async {}

  /// 全ロック済み伝票のハッシュチェーン整合性を検証する
  Future<HashChainVerifyResult> verifyAllLocked() async {
    try {
      final db = await _dbHelper.database;
      final rows = await db.query(
        'invoices',
        columns: ['id', 'meta_json', 'meta_hash'],
        where: 'is_locked = 1 AND meta_hash IS NOT NULL',
        orderBy: 'updated_at DESC',
      );
      final broken = <String>[];
      for (final row in rows) {
        final storedHash = row['meta_hash'] as String?;
        final metaJson = row['meta_json'] as String?;
        if (storedHash == null || metaJson == null) continue;
        final recomputed = sha256.convert(utf8.encode(metaJson)).toString();
        if (recomputed != storedHash) {
          broken.add(row['id'] as String? ?? '');
        }
      }
      return HashChainVerifyResult(
        checked: rows.length,
        brokenIds: broken,
        verifiedAt: DateTime.now(),
      );
    } catch (e) {
      debugPrint('[InvoiceRepo] verifyAllLocked error: $e');
      rethrow;
    }
  }

  Future<bool> isYoungestIssuedInvoice(String invoiceId) async => true;

  Future<bool> revertFormalIssue(String invoiceId) async => true;

  Future<Invoice?> getReceiptBySourceDocumentId(String sourceId) async => null;

  Future<void> cleanupOrphanedPdfs() async {}
}
