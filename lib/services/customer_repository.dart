import 'package:flutter/foundation.dart' show debugPrint;
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../models/customer_model.dart';
import '../services/database_helper.dart';
import '../services/activity_log_repository.dart';
import '../models/customer_contact.dart';
import 'hash_utils.dart';
import 'hash_chain_verify_result.dart';

class CustomerRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final ActivityLogRepository _logRepo = ActivityLogRepository();

  Future<List<Customer>> getAllCustomers({bool includeHidden = false}) async {
    try {
      final db = await _dbHelper.database;
      final filter = includeHidden
          ? 'WHERE c.is_current = 1 AND COALESCE(c.valid_to, \'9999-12-31\') > datetime(\'now\')'
          : 'WHERE c.is_current = 1 AND COALESCE(c.valid_to, \'9999-12-31\') > datetime(\'now\') AND COALESCE(mh.is_hidden, c.is_hidden, 0) = 0';
      List<Map<String, dynamic>> maps = await db.rawQuery('''
        SELECT c.*, cc.address AS contact_address, cc.tel AS contact_tel, cc.email AS contact_email,
               COALESCE(mh.is_hidden, c.is_hidden, 0) AS is_hidden
        FROM customers c
        LEFT JOIN customer_contacts cc ON cc.customer_id = c.id AND cc.is_active = 1
        LEFT JOIN master_hidden mh ON mh.master_type = 'customer' AND mh.master_id = c.id
        $filter
        ORDER BY ${includeHidden ? 'c.id DESC' : 'c.display_name ASC'}
      ''');
      return List.generate(maps.length, (i) => Customer.fromMap(maps[i]));
    } catch (e) {
      debugPrint('[CustomerRepo] getAllCustomers error: $e');
      rethrow;
    }
  }

  Future<List<Customer>> searchCustomers(
    String query, {
    bool includeHidden = false,
  }) async {
    try {
      final db = await _dbHelper.database;
      final where = includeHidden
          ? ''
          : "AND COALESCE(mh.is_hidden, c.is_hidden, 0) = 0";
      final List<Map<String, dynamic>> maps = await db.rawQuery(
        '''
        SELECT c.*, cc.address AS contact_address, cc.tel AS contact_tel, cc.email AS contact_email,
               COALESCE(mh.is_hidden, c.is_hidden, 0) AS is_hidden
        FROM customers c
        LEFT JOIN customer_contacts cc ON cc.customer_id = c.id AND cc.is_active = 1
        LEFT JOIN master_hidden mh ON mh.master_type = 'customer' AND mh.master_id = c.id
        WHERE c.is_current = 1
          AND COALESCE(c.valid_to, '9999-12-31') > datetime('now')
          AND (c.display_name LIKE ? OR c.formal_name LIKE ?) $where
        ORDER BY ${includeHidden ? 'c.id DESC' : 'c.display_name ASC'}
        LIMIT 50
      ''',
        ['%$query%', '%$query%'],
      );
      return List.generate(maps.length, (i) => Customer.fromMap(maps[i]));
    } catch (e) {
      debugPrint('[CustomerRepo] searchCustomers error: $e');
      rethrow;
    }
  }

  Future<Customer?> getById(String id) async {
    try {
      final db = await _dbHelper.database;
      final List<Map<String, dynamic>> currentMaps = await db.query(
        'customers',
        where: 'id = ? AND is_current = 1',
        whereArgs: [id],
        limit: 1,
      );
      if (currentMaps.isNotEmpty) {
        return Customer.fromMap(currentMaps.first);
      }
      final List<Map<String, dynamic>> maps = await db.query(
        'customers',
        where: 'id = ?',
        whereArgs: [id],
        orderBy: 'version DESC',
        limit: 1,
      );
      if (maps.isEmpty) return null;
      return Customer.fromMap(maps.first);
    } catch (e) {
      debugPrint('[CustomerRepo] getById error: $e');
      rethrow;
    }
  }

  Future<List<Customer>> getCustomerHistory(String customerId) async {
    try {
      final db = await _dbHelper.database;
      final maps = await db.query(
        'customers',
        where: 'id = ?',
        whereArgs: [customerId],
        orderBy: 'version DESC',
      );
      return List.generate(maps.length, (i) => Customer.fromMap(maps[i]));
    } catch (e) {
      debugPrint('[CustomerRepo] getCustomerHistory error: $e');
      rethrow;
    }
  }

  Future<bool> checkDuplicate({
    String? tel,
    String? email,
    String? name,
    String? excludeId,
  }) async {
    final db = await _dbHelper.database;
    return _checkDuplicateWith(db,
      tel: tel,
      email: email,
      name: name,
      excludeId: excludeId,
    );
  }

  Future<bool> checkDuplicateTxn(
    DatabaseExecutor txn, {
    String? tel,
    String? email,
    String? name,
    String? excludeId,
  }) async {
    return _checkDuplicateWith(txn,
      tel: tel,
      email: email,
      name: name,
      excludeId: excludeId,
    );
  }

  Future<bool> _checkDuplicateWith(
    DatabaseExecutor db, {
    String? tel,
    String? email,
    String? name,
    String? excludeId,
  }) async {
    try {
      if (tel != null && tel.isNotEmpty) {
        String where = 'tel = ? AND is_hidden = 0 AND is_current = 1';
        List<dynamic> whereArgs = [tel];
        if (excludeId != null) {
          where += ' AND id != ?';
          whereArgs.add(excludeId);
        }
        final result = await db.query(
          'customers',
          where: where,
          whereArgs: whereArgs,
        );
        if (result.isNotEmpty) return true;
      }

      if (email != null && email.isNotEmpty) {
        String where = 'email = ? AND is_hidden = 0 AND is_current = 1';
        List<dynamic> whereArgs = [email];
        if (excludeId != null) {
          where += ' AND id != ?';
          whereArgs.add(excludeId);
        }
        final result = await db.query(
          'customers',
          where: where,
          whereArgs: whereArgs,
        );
        if (result.isNotEmpty) return true;
      }

      if (name != null && name.isNotEmpty) {
        String where =
            '(display_name LIKE ? OR formal_name LIKE ?) AND is_hidden = 0 AND is_current = 1';
        List<dynamic> whereArgs = ['%$name%', '%$name%'];
        if (excludeId != null) {
          where += ' AND id != ?';
          whereArgs.add(excludeId);
        }
        final result = await db.query(
          'customers',
          where: where,
          whereArgs: whereArgs,
        );
        if (result.isNotEmpty) return true;
      }

      return false;
    } catch (e) {
      debugPrint('[CustomerRepo] checkDuplicate error: $e');
      rethrow;
    }
  }

  Future<void> _safeAddColumn(
    Database db,
    String table,
    String columnDefinition,
  ) async {
    try {
      final columns = await db.query(table, limit: 1);
      final columnName = columnDefinition.split(' ')[0];
      if (!columns.first.containsKey(columnName)) {
        await db.execute('ALTER TABLE $table ADD COLUMN $columnDefinition');
      }
    } catch (_) {}
  }

  Future<void> ensureCustomerColumns() async {
    try {
      final db = await _dbHelper.database;
      await _safeAddColumn(db, 'customers', 'contact_version_id INTEGER');
      await _safeAddColumn(db, 'customers', 'head_char1 TEXT');
      await _safeAddColumn(db, 'customers', 'head_char2 TEXT');
      await _safeAddColumn(db, 'customers', 'kana TEXT');
    } catch (e) {
      debugPrint('[CustomerRepo] ensureCustomerColumns error: $e');
      rethrow;
    }
  }

  Future<void> saveCustomer(
    Customer customer, {
    bool force = false,
    String? originalId,
  }) async {
    try {
      final db = await _dbHelper.database;

      await db.transaction((txn) async {
        if (!force) {
          final isDuplicate = await checkDuplicateTxn(txn,
            tel: customer.tel,
            email: customer.email,
            name: customer.displayName,
            excludeId: customer.id,
          );

          if (isDuplicate) {
            throw DuplicateCustomerException(customer);
          }
        }

        final existing = await txn.query(
          'customers',
          where: 'id = ? AND is_current = 1',
          whereArgs: [customer.id],
        );

        String previousHashValue = '';
        int currentVersion = 0;

        if (originalId != null && originalId != customer.id) {
          final originalRecord = await txn.query(
            'customers',
            where: 'id = ? AND is_current = 1',
            whereArgs: [originalId],
          );
          if (originalRecord.isNotEmpty) {
            previousHashValue =
                (originalRecord.first['content_hash'] as String?) ?? '';
            currentVersion =
                (originalRecord.first['version'] as int?) ?? 0;
          }
          await txn.update(
            'customers',
            {
              'next_version_id': customer.id,
              'is_current': 0,
              'valid_to': DateTime.now().toIso8601String(),
            },
            where: 'id = ?',
            whereArgs: [originalId],
          );
        } else if (existing.isNotEmpty) {
          previousHashValue =
              (existing.first['content_hash'] as String?) ?? '';
          currentVersion =
              (existing.first['version'] as int?) ?? 0;
          await txn.update(
            'customers',
            {'is_current': 0, 'valid_to': DateTime.now().toIso8601String()},
            where: 'id = ? AND is_current = 1',
            whereArgs: [customer.id],
          );
        }

        final newVersion = currentVersion + 1;
        final newValidFrom = DateTime.now();

        final contentHash = HashUtils.calculateCustomerHash(
          id: customer.id,
          displayName: customer.displayName,
          formalName: customer.formalName,
          title: customer.title,
          department: customer.department,
          address: customer.address,
          tel: customer.tel,
          email: customer.email,
          contactVersionId: customer.contactVersionId,
          odooId: customer.odooId,
          isLocked: customer.isLocked,
          isHidden: customer.isHidden,
          headChar1: customer.headChar1,
          headChar2: customer.headChar2,
          validFrom: newValidFrom,
          version: newVersion,
          isCurrentFlag: true,
          previousHash: previousHashValue,
        );

        final customerMap = customer.toMap();
        customerMap.remove('kana');
        customerMap['content_hash'] = contentHash;
        customerMap['previous_hash'] = previousHashValue;
        customerMap['is_current'] = 1;
        customerMap['version'] = newVersion;
        customerMap['valid_from'] = newValidFrom.toIso8601String();
        customerMap['valid_to'] = null;

        await txn.insert(
          'customers',
          customerMap,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        await _upsertActiveContact(txn, customer);
      });

      await _logRepo.logAction(
        action: "SAVE_CUSTOMER",
        targetType: "CUSTOMER",
        targetId: customer.id,
        details:
            "名称：${customer.formalName}, 敬称：${HonorificCode.toName(customer.title)} (version up)",
      );
    } catch (e) {
      debugPrint('[CustomerRepo] saveCustomer error: $e');
      rethrow;
    }
  }

  Future<void> deleteCustomer(String id) async {
    try {
      final db = await _dbHelper.database;
      await db.transaction((txn) async {
        final references = await _checkCustomerReferences(txn, id);
        if (references.isNotEmpty) {
          throw CustomerInUseException(id, references);
        }

        await txn.delete('customers', where: 'id = ?', whereArgs: [id]);
        await txn.delete('customer_contacts', where: 'customer_id = ?', whereArgs: [id]);
      });

      await _logRepo.logAction(
        action: "DELETE_CUSTOMER",
        targetType: "CUSTOMER",
        targetId: id,
        details: "顧客を完全削除しました",
      );
    } catch (e) {
      debugPrint('[CustomerRepo] deleteCustomer error: $e');
      rethrow;
    }
  }

  Future<List<String>> _checkCustomerReferences(DatabaseExecutor txn, String customerId) async {
    try {
      final references = <String>[];

      final invoices = await txn.query(
        'invoices',
        where: 'customer_id = ?',
        whereArgs: [customerId],
        limit: 1,
      );
      if (invoices.isNotEmpty) references.add('請求書');

      final quotations = await txn.query(
        'quotations',
        where: 'customer_id = ?',
        whereArgs: [customerId],
        limit: 1,
      );
      if (quotations.isNotEmpty) references.add('見積書');

      final sales = await txn.query(
        'sales',
        where: 'customer_id = ?',
        whereArgs: [customerId],
        limit: 1,
      );
      if (sales.isNotEmpty) references.add('売上');

      final deliveries = await txn.query(
        'deliveries',
        where: 'customer_id = ?',
        whereArgs: [customerId],
        limit: 1,
      );
      if (deliveries.isNotEmpty) references.add('納品書');

      return references;
    } catch (e) {
      debugPrint('[CustomerRepo] _checkCustomerReferences error: $e');
      rethrow;
    }
  }

  Future<void> updateContact({
    required String customerId,
    String? email,
    String? tel,
    String? address,
  }) async {
    try {
      final db = await _dbHelper.database;
      await db.transaction((txn) async {
        final nextVersion = await _nextContactVersion(txn, customerId);
        await txn.update(
          'customer_contacts',
          {'is_active': 0},
          where: 'customer_id = ?',
          whereArgs: [customerId],
        );
        await txn.insert('customer_contacts', {
          'id': const Uuid().v4(),
          'customer_id': customerId,
          'email': email,
          'tel': tel,
          'address': address,
          'version': nextVersion,
          'is_active': 1,
          'created_at': DateTime.now().toIso8601String(),
        });
      });

      await _logRepo.logAction(
        action: "UPDATE_CUSTOMER_CONTACT",
        targetType: "CUSTOMER",
        targetId: customerId,
        details: "連絡先を更新 (version up)",
      );
    } catch (e) {
      debugPrint('[CustomerRepo] updateContact error: $e');
      rethrow;
    }
  }

  Future<CustomerContact?> getActiveContact(String customerId) async {
    try {
      final db = await _dbHelper.database;
      final rows = await db.query(
        'customer_contacts',
        where: 'customer_id = ? AND is_active = 1',
        whereArgs: [customerId],
        limit: 1,
      );
      if (rows.isEmpty) return null;
      return CustomerContact.fromMap(rows.first);
    } catch (e) {
      debugPrint('[CustomerRepo] getActiveContact error: $e');
      rethrow;
    }
  }

  Future<int> _nextContactVersion(
    DatabaseExecutor txn,
    String customerId,
  ) async {
    try {
      final res = await txn.rawQuery(
        'SELECT MAX(version) as v FROM customer_contacts WHERE customer_id = ?',
        [customerId],
      );
      final current = res.first['v'] as int?;
      return (current ?? 0) + 1;
    } catch (e) {
      debugPrint('[CustomerRepo] _nextContactVersion error: $e');
      rethrow;
    }
  }

  Future<void> _upsertActiveContact(
    DatabaseExecutor txn,
    Customer customer,
  ) async {
    try {
      final nextVersion = await _nextContactVersion(txn, customer.id);
      await txn.update(
        'customer_contacts',
        {'is_active': 0},
        where: 'customer_id = ?',
        whereArgs: [customer.id],
      );
      await txn.insert('customer_contacts', {
        'id': const Uuid().v4(),
        'customer_id': customer.id,
        'email': customer.email,
        'tel': customer.tel,
        'address': customer.address,
        'version': nextVersion,
        'is_active': 1,
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('[CustomerRepo] _upsertActiveContact error: $e');
      rethrow;
    }
  }

  /// 最新の N 件の顧客を遡ってハッシュチェーン整合性を検証する
  Future<HashChainVerifyResult> verifyTailN({int n = 5}) async {
    try {
      final db = await _dbHelper.database;
      final rows = await db.query(
        'customers',
        where: 'is_current = 1 AND content_hash IS NOT NULL',
        orderBy: 'updated_at DESC',
        limit: n,
      );
      final broken = <String>[];
      for (final row in rows) {
        final storedHash = row['content_hash'] as String?;
        if (storedHash == null) continue;

        final customer = Customer.fromMap(row as Map<String, dynamic>);
        final recomputed = HashUtils.calculateCustomerHash(
          id: customer.id,
          displayName: customer.displayName,
          formalName: customer.formalName,
          title: customer.title,
          department: customer.department,
          address: customer.address,
          tel: customer.tel,
          email: customer.email,
          contactVersionId: customer.contactVersionId,
          odooId: customer.odooId,
          isLocked: customer.isLocked,
          isHidden: customer.isHidden,
          headChar1: customer.headChar1,
          headChar2: customer.headChar2,
          validFrom: customer.validFrom,
          validTo: customer.validTo,
          isCurrentFlag: customer.isCurrent,
          version: customer.version,
          previousHash: customer.previousHash,
        );

        if (recomputed != storedHash) {
          broken.add(customer.id);
          continue;
        }

        if (customer.version > 1 &&
            customer.previousHash != null &&
            customer.previousHash!.isNotEmpty) {
          final prevRows = await db.query(
            'customers',
            columns: ['content_hash'],
            where: 'id = ? AND version = ?',
            whereArgs: [customer.id, customer.version - 1],
            limit: 1,
          );
          if (prevRows.isNotEmpty) {
            final prevContentHash = prevRows.first['content_hash'] as String?;
            if (prevContentHash != null && customer.previousHash != prevContentHash) {
              broken.add(customer.id);
            }
          }
        }
      }
      return HashChainVerifyResult(
        checked: rows.length,
        brokenIds: broken,
        verifiedAt: DateTime.now(),
      );
    } catch (e) {
      debugPrint('[CustomerRepo] verifyTailN error: $e');
      rethrow;
    }
  }

  Future<void> setHidden(String id, bool hidden) async {
    try {
      final db = await _dbHelper.database;
      await db.insert('master_hidden', {
        'master_type': 'customer',
        'master_id': id,
        'is_hidden': hidden ? 1 : 0,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      await _logRepo.logAction(
        action: hidden ? "HIDE_CUSTOMER" : "UNHIDE_CUSTOMER",
        targetType: "CUSTOMER",
        targetId: id,
        details: hidden ? "顧客を非表示にしました" : "顧客を再表示しました",
      );
    } catch (e) {
      debugPrint('[CustomerRepo] setHidden error: $e');
      rethrow;
    }
  }

  Future<int> cleanupDuplicateVersions() async {
    try {
      final db = await _dbHelper.database;
      final customers = await db.query(
        'customers',
        where: 'is_current = 1',
      );

      final Map<String, List<Map<String, dynamic>>> grouped = {};
      for (final c in customers) {
        final name = c['display_name'] as String? ?? '';
        grouped.putIfAbsent(name, () => []).add(c);
      }

      int fixedCount = 0;
      for (final entry in grouped.entries) {
        if (entry.value.length <= 1) continue;
        entry.value.sort((a, b) {
          final va = (a['version'] as int?) ?? 1;
          final vb = (b['version'] as int?) ?? 1;
          return va.compareTo(vb);
        });
        final Map<String, dynamic> newest = entry.value.last;
        for (int i = 0; i < entry.value.length - 1; i++) {
          final old = entry.value[i];
          final newer = entry.value[i + 1];
          await db.update(
            'customers',
            {
              'next_version_id': newer['id'],
              'is_current': 0,
              'is_hidden': 1,
              'valid_to': DateTime.now().toIso8601String(),
            },
            where: 'id = ?',
            whereArgs: [old['id']],
          );
          fixedCount++;
        }
        await db.insert('master_hidden', {
          'master_type': 'customer',
          'master_id': newest['id'],
          'is_hidden': 0,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
      if (fixedCount > 0) {
        await _logRepo.logAction(
          action: 'CLEANUP_CUSTOMER_DUPLICATES',
          targetType: 'CUSTOMER',
          targetId: null,
          details: '重複顧客バージョンを$fixedCount件整理しました',
        );
      }
      return fixedCount;
    } catch (e) {
      debugPrint('[CustomerRepo] cleanupDuplicateVersions error: $e');
      rethrow;
    }
  }

  Future<void> updateKanaOnly(String customerId, String kana) async {
    try {
      final db = await _dbHelper.database;
      await db.update(
        'customers',
        {'kana': kana},
        where: 'id = ? AND is_current = 1',
        whereArgs: [customerId],
      );
    } catch (e) {
      debugPrint('[CustomerRepo] updateKanaOnly error: $e');
      rethrow;
    }
  }
}
