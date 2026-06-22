import 'package:flutter/foundation.dart' show debugPrint;
import '../../../services/database_helper.dart';
import '../models/accounting_voucher.dart';

class AccountingVoucherRepository {
  final _db = DatabaseHelper();

  String generateId() {
    return DateTime.now().millisecondsSinceEpoch.toString();
  }

  Future<List<AccountingVoucher>> fetchAll({
    AccountingVoucherType? filterType,
    String? query,
    String? statusFilter,
    DateTime? dateFrom,
    DateTime? dateTo,
  }) async {
    try {
      final db = await _db.database;
      final whereClauses = <String>[];
      final whereArgs = <dynamic>[];

      if (filterType != null) {
        whereClauses.add('type = ?');
        whereArgs.add(filterType.name);
      }

      if (query != null && query.isNotEmpty) {
        whereClauses.add('(voucher_number LIKE ? OR customer_name LIKE ? OR description LIKE ?)');
        final searchPattern = '%$query%';
        whereArgs.addAll([searchPattern, searchPattern, searchPattern]);
      }

      if (statusFilter != null) {
        whereClauses.add('status = ?');
        whereArgs.add(statusFilter);
      }

      if (dateFrom != null) {
        whereClauses.add('date >= ?');
        whereArgs.add(dateFrom.toIso8601String());
      }

      if (dateTo != null) {
        whereClauses.add('date <= ?');
        whereArgs.add(dateTo.toIso8601String());
      }

      final where = whereClauses.isNotEmpty ? whereClauses.join(' AND ') : null;

      final results = await db.query(
        'accounting_vouchers',
        where: where,
        whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
        orderBy: 'date DESC, created_at DESC',
      );

      return results.map((map) => AccountingVoucher.fromMap(map)).toList();
    } catch (e) {
      debugPrint('[AccountingVoucherRepository] fetchAll error: $e');
      rethrow;
    }
  }

  Future<AccountingVoucher?> getById(String id) async {
    try {
      final db = await _db.database;
      final results = await db.query(
        'accounting_vouchers',
        where: 'id = ?',
        whereArgs: [id],
      );

      if (results.isEmpty) return null;
      return AccountingVoucher.fromMap(results.first);
    } catch (e) {
      debugPrint('[AccountingVoucherRepository] getById error: $e');
      rethrow;
    }
  }

  Future<void> save(AccountingVoucher voucher) async {
    try {
      final db = await _db.database;
      final existing = await getById(voucher.id);

      if (existing != null) {
        await db.update(
          'accounting_vouchers',
          voucher.toMap()..['updated_at'] = DateTime.now().toIso8601String(),
          where: 'id = ?',
          whereArgs: [voucher.id],
        );
      } else {
        await db.insert('accounting_vouchers', voucher.toMap());
      }
    } catch (e) {
      debugPrint('[AccountingVoucherRepository] save error: $e');
      rethrow;
    }
  }

  Future<void> delete(String id) async {
    try {
      final db = await _db.database;
      await db.delete(
        'accounting_vouchers',
        where: 'id = ?',
        whereArgs: [id],
      );
    } catch (e) {
      debugPrint('[AccountingVoucherRepository] delete error: $e');
      rethrow;
    }
  }

  Future<String> generateVoucherNumber(AccountingVoucherType type) async {
    final db = await _db.database;
    final prefix = switch (type) {
      AccountingVoucherType.sales => 'SL',
      AccountingVoucherType.cashIn => 'CI',
      AccountingVoucherType.cashOut => 'CO',
      AccountingVoucherType.transfer => 'TF',
    };

    final year = DateTime.now().year;
    final month = DateTime.now().month;

    final results = await db.query(
      'accounting_vouchers',
      where: 'type = ? AND date >= ? AND date < ?',
      whereArgs: [
        type.name,
        DateTime(year, month, 1).toIso8601String(),
        DateTime(year, month + 1, 1).toIso8601String(),
      ],
      orderBy: 'voucher_number DESC',
      limit: 1,
    );

    int sequence = 1;
    if (results.isNotEmpty) {
      final lastNumber = results.first['voucher_number'] as String;
      final lastSequence = int.tryParse(lastNumber.split('-').last) ?? 0;
      sequence = lastSequence + 1;
    }

    return '$prefix-$year${month.toString().padLeft(2, '0')}-$sequence';
  }
}
