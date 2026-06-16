import 'package:uuid/uuid.dart';
import '../../../../services/database_helper.dart';
import '../models/journal_entry.dart';
import 'account_repository.dart';

class AutoJournalService {
  final _db = DatabaseHelper();
  final _repo = AccountRepository();
  final _uuid = const Uuid();

  Future<int?> _accountId(String code) async {
    final accounts = await _repo.fetchAll();
    return accounts.where((a) => a.code == code).firstOrNull?.id;
  }

  Future<void> createFromInvoice({
    required String documentId,
    required int total,
    DateTime? date,
    String? customerName,
  }) async {
    final debitId = await _accountId('103'); // 売掛金
    final creditId = await _accountId('401'); // 売上高
    if (debitId == null || creditId == null) return;
    final db = await _db.database;
    final now = DateTime.now();
    await db.insert('journal_entries', JournalEntry(
      id: _uuid.v4(),
      date: date ?? now,
      debitAccountId: debitId,
      creditAccountId: creditId,
      amount: total,
      description: '自動: 請求${customerName != null ? " ($customerName)" : ""}',
      documentId: documentId,
      entryType: 'auto',
    ).toMap());
  }

  Future<void> createFromReceipt({
    required String documentId,
    required int amount,
    DateTime? date,
    String? customerName,
  }) async {
    final debitId = await _accountId('101'); // 現金
    final creditId = await _accountId('103'); // 売掛金
    if (debitId == null || creditId == null) return;
    final db = await _db.database;
    final now = DateTime.now();
    await db.insert('journal_entries', JournalEntry(
      id: _uuid.v4(),
      date: date ?? now,
      debitAccountId: debitId,
      creditAccountId: creditId,
      amount: amount,
      description: '自動: 入金${customerName != null ? " ($customerName)" : ""}',
      documentId: documentId,
      entryType: 'auto',
    ).toMap());
  }

  Future<void> createFromCashTransaction({
    required int amount,
    required String type,
    required int accountId,
    DateTime? date,
    String? description,
  }) async {
    final cashId = await _accountId('101');
    if (cashId == null) return;
    final db = await _db.database;
    final now = DateTime.now();
    if (type == 'inflow') {
      await db.insert('journal_entries', JournalEntry(
        id: _uuid.v4(),
        date: date ?? now,
        debitAccountId: cashId,
        creditAccountId: accountId,
        amount: amount,
        description: '自動: 入金(${description ?? ""})',
        entryType: 'auto',
      ).toMap());
    } else {
      await db.insert('journal_entries', JournalEntry(
        id: _uuid.v4(),
        date: date ?? now,
        debitAccountId: accountId,
        creditAccountId: cashId,
        amount: amount,
        description: '自動: 出金(${description ?? ""})',
        entryType: 'auto',
      ).toMap());
    }
  }

  Future<void> createFromReceiptPhoto({
    required int total,
    required String description,
    DateTime? date,
    String? vendor,
    int? tax,
  }) async {
    final expenseId = await _accountId('501'); // 消耗品費（汎用経費）
    final taxExpenseId = await _accountId('512'); // 仮払消費税
    final cashId = await _accountId('101'); // 現金
    if (expenseId == null || cashId == null) return;
    final db = await _db.database;
    final now = DateTime.now();
    final entryDate = date ?? now;
    final baseDesc = '自動: 経費${vendor != null ? " ($vendor)" : ""} - $description';

    if (tax != null && tax > 0 && taxExpenseId != null) {
      await db.insert('journal_entries', JournalEntry(
        id: _uuid.v4(),
        date: entryDate,
        debitAccountId: expenseId,
        creditAccountId: cashId,
        amount: total - tax,
        description: '$baseDesc (税抜)',
        entryType: 'auto',
      ).toMap());
      await db.insert('journal_entries', JournalEntry(
        id: _uuid.v4(),
        date: entryDate,
        debitAccountId: taxExpenseId,
        creditAccountId: cashId,
        amount: tax,
        description: '$baseDesc (消費税)',
        entryType: 'auto',
      ).toMap());
    } else {
      await db.insert('journal_entries', JournalEntry(
        id: _uuid.v4(),
        date: entryDate,
        debitAccountId: expenseId,
        creditAccountId: cashId,
        amount: total,
        description: baseDesc,
        entryType: 'auto',
      ).toMap());
    }
  }
}
