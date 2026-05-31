import 'database_helper.dart';

class EditLogRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  Future<void> _ensureTable() async {
    final db = await _dbHelper.database;
    await db.execute('''
      CREATE TABLE IF NOT EXISTS edit_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        invoice_id TEXT,
        message TEXT,
        created_at INTEGER
      )
    ''');
  }

  Future<void> addLog(String invoiceId, String message) async {
    await _ensureTable();
    final db = await _dbHelper.database;
    final now = DateTime.now().millisecondsSinceEpoch;
    final cutoff = DateTime.now().subtract(const Duration(days: 30)).millisecondsSinceEpoch;
    await db.delete('edit_logs', where: 'created_at < ?', whereArgs: [cutoff]);
    await db.insert('edit_logs', {
      'invoice_id': invoiceId,
      'message': message,
      'created_at': now,
    });
  }

  Future<List<EditLogEntry>> getLogs(String invoiceId) async {
    await _ensureTable();
    final db = await _dbHelper.database;
    final cutoff = DateTime.now().subtract(const Duration(days: 14)).millisecondsSinceEpoch;
    final res = await db.query(
      'edit_logs',
      where: 'invoice_id = ? AND created_at >= ?',
      whereArgs: [invoiceId, cutoff],
      orderBy: 'created_at DESC',
    );
    return res
        .map((e) => EditLogEntry(
              id: e['id'] as int? ?? 0,
              invoiceId: e['invoice_id'] as String? ?? '',
              message: e['message'] as String? ?? '',
              createdAt: DateTime.fromMillisecondsSinceEpoch(e['created_at'] as int? ?? 0),
            ))
        .toList();
  }
}

class EditLogEntry {
  final int id;
  final String invoiceId;
  final String message;
  final DateTime createdAt;

  EditLogEntry({required this.id, required this.invoiceId, required this.message, required this.createdAt});
}
