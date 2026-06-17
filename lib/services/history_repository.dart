import 'package:uuid/uuid.dart';
import '../services/database_helper.dart';

class HistoryRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final _uuid = const Uuid();

  /// PDF出力履歴を記録
  Future<void> recordPdfOutput({
    required String documentType,
    required String documentId,
    required String documentNumber,
    String? customerName,
    String? filePath,
    required String contentHash,
  }) async {
    final db = await _dbHelper.database;
    await db.insert('pdf_output_history', {
      'id': _uuid.v4(),
      'document_type': documentType,
      'document_id': documentId,
      'document_number': documentNumber,
      'customer_name': customerName,
      'file_path': filePath,
      'content_hash': contentHash,
      'output_at': DateTime.now().toIso8601String(),
    });
  }

  /// メール送信履歴を記録
  Future<void> recordEmailSend({
    String? documentType,
    String? documentId,
    String? documentNumber,
    required String recipientEmail,
    String? recipientName,
    required String subject,
    String status = 'sent',
  }) async {
    final db = await _dbHelper.database;
    await db.insert('email_send_history', {
      'id': _uuid.v4(),
      'document_type': documentType,
      'document_id': documentId,
      'document_number': documentNumber,
      'recipient_email': recipientEmail,
      'recipient_name': recipientName,
      'subject': subject,
      'status': status,
      'sent_at': DateTime.now().toIso8601String(),
    });
  }

  /// PDF出力履歴を取得
  Future<List<Map<String, dynamic>>> getPdfOutputHistory({
    String? documentType,
    String? documentId,
    int limit = 50,
  }) async {
    final db = await _dbHelper.database;
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

    final where = conditions.isNotEmpty ? 'WHERE ${conditions.join(' AND ')}' : null;
    return await db.query(
      'pdf_output_history',
      where: where,
      whereArgs: args.isNotEmpty ? args : null,
      orderBy: 'output_at DESC',
      limit: limit,
    );
  }

  /// メール送信履歴を取得
  Future<List<Map<String, dynamic>>> getEmailSendHistory({
    String? documentType,
    String? documentId,
    int limit = 50,
  }) async {
    final db = await _dbHelper.database;
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

    final where = conditions.isNotEmpty ? 'WHERE ${conditions.join(' AND ')}' : null;
    return await db.query(
      'email_send_history',
      where: where,
      whereArgs: args.isNotEmpty ? args : null,
      orderBy: 'sent_at DESC',
      limit: limit,
    );
  }
}
