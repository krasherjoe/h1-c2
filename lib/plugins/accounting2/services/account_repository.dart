import 'package:sqflite/sqflite.dart';
import '../../../services/database_helper.dart';
import '../models/account.dart';
import 'audit_log_service.dart';

class AccountRepository {
  final DatabaseHelper _db = DatabaseHelper();
  final _audit = AuditLogService();

  Future<Database> get _database => _db.database;

  Future<List<Account>> fetchAll() async {
    final db = await _database;
    final maps = await db.query('accounts', orderBy: 'code');
    return maps.map(Account.fromMap).toList();
  }

  Future<Account?> fetchById(int id) async {
    final db = await _database;
    final maps = await db.query('accounts', where: 'id = ?', whereArgs: [id], limit: 1);
    return maps.isNotEmpty ? Account.fromMap(maps.first) : null;
  }

  Future<List<Account>> fetchByCategory(String category) async {
    final db = await _database;
    final maps = await db.query('accounts', where: 'category = ?', whereArgs: [category], orderBy: 'code');
    return maps.map(Account.fromMap).toList();
  }

  Future<Account> save(Account account) async {
    final db = await _database;
    final now = DateTime.now().toIso8601String();
    if (account.id != null) {
      final old = await fetchById(account.id!);
      await db.update('accounts', {
        'code': account.code,
        'name': account.name,
        'category': account.category,
        'updated_at': now,
      }, where: 'id = ?', whereArgs: [account.id]);
      await _audit.log(tableName: 'accounts', recordId: account.id.toString(), action: 'update',
        oldValues: old?.toMap(), newValues: account.toMap());
      return account;
    }
    final id = await db.insert('accounts', {
      'code': account.code,
      'name': account.name,
      'category': account.category,
      'is_system': 0,
      'created_at': now,
      'updated_at': now,
    });
    await _audit.log(tableName: 'accounts', recordId: id.toString(), action: 'insert',
      newValues: account.toMap());
    return account.copyWith(id: id);
  }

  Future<bool> canDelete(Account account) async {
    if (account.isSystem) return false;
    final db = await _database;
    final journalCount = Sqflite.firstIntValue(await db.rawQuery(
      'SELECT COUNT(*) FROM journal_entries WHERE debit_account_id = ? OR credit_account_id = ?',
      [account.id, account.id],
    )) ?? 0;
    final cashCount = Sqflite.firstIntValue(await db.rawQuery(
      'SELECT COUNT(*) FROM cash_transactions WHERE account_id = ?',
      [account.id],
    )) ?? 0;
    return journalCount == 0 && cashCount == 0;
  }

  Future<void> delete(int id) async {
    final old = await fetchById(id);
    final db = await _database;
    await db.delete('accounts', where: 'id = ?', whereArgs: [id]);
    await _audit.log(tableName: 'accounts', recordId: id.toString(), action: 'delete',
      oldValues: old?.toMap());
  }
}
