import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../../../../services/database_helper.dart';
import '../models/case_model.dart';

class CaseRepository {
  final _db = DatabaseHelper();

  Future<List<CaseModel>> fetchAll({String? type, String? assignee, bool onlyActive = true}) async {
    final db = await _db.database;
    final conditions = <String>[];
    final args = <dynamic>[];
    if (onlyActive) { conditions.add('status < 99'); }
    if (type != null && type.isNotEmpty) { conditions.add('type = ?'); args.add(type); }
    if (assignee != null && assignee.isNotEmpty) { conditions.add('assignee = ?'); args.add(assignee); }
    final where = conditions.isNotEmpty ? conditions.join(' AND ') : null;
    final maps = await db.query('cases', where: where, whereArgs: args.isEmpty ? null : args, orderBy: 'status DESC, created_at DESC');
    return maps.map(CaseModel.fromMap).toList();
  }

  Future<CaseModel?> fetchById(String id) async {
    final db = await _db.database;
    final maps = await db.query('cases', where: 'id = ?', whereArgs: [id], limit: 1);
    return maps.isNotEmpty ? CaseModel.fromMap(maps.first) : null;
  }

  Future<void> save(CaseModel c) async {
    final db = await _db.database;
    await db.insert('cases', c.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<String> create({
    required String type, required String title, int? amount,
    String referenceType = '', String referenceId = '', String description = '',
  }) async {
    final id = const Uuid().v4();
    await save(CaseModel(id: id, type: type, title: title, amount: amount,
      referenceType: referenceType, referenceId: referenceId, description: description,
      createdAt: DateTime.now()));
    return id;
  }

  Future<void> updateDueDate(String id, DateTime dueDate) async {
    final db = await _db.database;
    await db.update('cases', {'due_date': dueDate.toIso8601String()}, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> updateStatus(String id, int status, {String? notes}) async {
    final db = await _db.database;
    final now = DateTime.now().toIso8601String();
    final vals = <String, dynamic>{'status': status, 'escalated_at': now};
    if (status >= 99) vals['resolved_at'] = now;
    if (notes != null) vals['notes'] = notes;
    await db.update('cases', vals, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> escalateAll() async {
    final db = await _db.database;
    final now = DateTime.now();
    final maps = await db.query('cases', where: 'status < 99');
    final escalationRules = <String, List<int>>{
      'overdue': [7, 30, 60],
      'damage': [7, 30, 90],
      'theft': [1, 7, 30],
      'loss': [14, 60, 180],
    };
    for (final m in maps) {
      final c = CaseModel.fromMap(m);
      final rules = escalationRules[c.type] ?? [7, 30, 60];
      final days = now.difference(c.createdAt).inDays;
      int newStatus = c.status;
      if (days >= rules[2] && c.status < 3) newStatus = 3;
      else if (days >= rules[1] && c.status < 2) newStatus = 2;
      else if (days >= rules[0] && c.status < 1) newStatus = 1;
      if (newStatus != c.status) {
        await db.update('cases', {'status': newStatus, 'escalated_at': now.toIso8601String()}, where: 'id = ?', whereArgs: [c.id]);
      }
    }
  }

  Future<int> autoCreateFromOverdueInvoices() async {
    final db = await _db.database;
    final now = DateTime.now();
    const defaultDueDays = 30;

    final existing = await db.query('cases',
      columns: ['reference_id'], where: "reference_type = 'invoice' AND status < 99");
    final existingIds = existing.map((e) => e['reference_id'] as String).toSet();

    final invoices = await db.rawQuery('''
      SELECT id, date, customer_formal_name, subject, total_amount,
             payment_status, received_amount, promised_date
      FROM invoices
      WHERE payment_status IN ('unpaid', 'partial')
        AND total_amount > 0
        AND (received_amount IS NULL OR received_amount < total_amount)
        AND is_draft = 0
    ''');

    int created = 0;
    for (final inv in invoices) {
      final invId = inv['id'] as String;
      if (existingIds.contains(invId)) continue;

      final invoiceDate = DateTime.tryParse(inv['date'] as String? ?? '');
      if (invoiceDate == null) continue;

      final promisedTs = inv['promised_date'] as int?;
      final dueDate = promisedTs != null
          ? DateTime.fromMillisecondsSinceEpoch(promisedTs)
          : invoiceDate.add(Duration(days: defaultDueDays));

      if (now.isBefore(dueDate)) continue;

      final customerName = inv['customer_formal_name'] as String? ?? '';
      final subject = inv['subject'] as String? ?? '';
      final totalAmount = inv['total_amount'] as int? ?? 0;
      final title = subject.isNotEmpty
          ? '$customerName ${subject}'
          : '$customerName ${totalAmount}円';
      final remaining = totalAmount - (inv['received_amount'] as int? ?? 0);

      await create(
        type: 'overdue',
        title: title.length > 80 ? '${title.substring(0, 80)}..' : title,
        amount: remaining,
        referenceType: 'invoice',
        referenceId: invId,
        description: '延滞請求書から自動作成\n'
            '顧客: $customerName\n'
            '請求額: ${totalAmount}円\n'
            '未収: ${remaining}円\n'
            '支払期限: ${dueDate.toIso8601String().substring(0, 10)}',
      );
      created++;
    }
    return created;
  }

  Future<int> getOverdueInvoiceCount() async {
    final db = await _db.database;
    final now = DateTime.now();
    final result = await db.rawQuery('''
      SELECT COUNT(*) AS c FROM invoices
      WHERE payment_status IN ('unpaid', 'partial')
        AND total_amount > 0
        AND (received_amount IS NULL OR received_amount < total_amount)
        AND is_draft = 0
        AND date < ?
    ''', [now.subtract(const Duration(days: 30)).toIso8601String().substring(0, 10)]);
    return (result.first['c'] as int?) ?? 0;
  }
}
