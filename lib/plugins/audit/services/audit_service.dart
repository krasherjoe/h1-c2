import 'package:sqflite/sqflite.dart';
import '../../../services/hash_chain_verify_result.dart';
import '../../../services/invoice_repository.dart';
import '../../documents/services/document_repository.dart';

class AuditResult {
  final int totalHashEntries;
  final HashChainVerifyResult? lastInvoiceCheck;
  final HashChainVerifyResult? lastDocumentCheck;
  final HashChainVerifyResult? lastElectronicBookkeepingCheck;
  final DateTime? lastFullVerifyAt;
  final bool chainHealthy;

  AuditResult({
    required this.totalHashEntries,
    this.lastInvoiceCheck,
    this.lastDocumentCheck,
    this.lastElectronicBookkeepingCheck,
    this.lastFullVerifyAt,
    required this.chainHealthy,
  });
}

class AuditService {
  static Future<AuditResult> runFullAudit(Database db) async {
    final countResult = await db.rawQuery('SELECT COUNT(*) as cnt FROM hash_chain');
    final totalHashEntries = countResult.first['cnt'] as int? ?? 0;

    if (totalHashEntries == 0) {
      return AuditResult(
        totalHashEntries: 0,
        chainHealthy: true,
        lastFullVerifyAt: DateTime.now(),
      );
    }

    final invoiceRepo = InvoiceRepository();
    final documentRepo = DocumentRepository();

    final invoiceCheck = await invoiceRepo.verifyAllLocked();
    final documentCheck = await documentRepo.verifyAllLocked();
    final electronicBookkeepingCheck = await documentRepo.verifyElectronicBookkeeping();

    final chainHealthy = invoiceCheck.isHealthy &&
        documentCheck.isHealthy &&
        electronicBookkeepingCheck.isHealthy;

    return AuditResult(
      totalHashEntries: totalHashEntries,
      lastInvoiceCheck: invoiceCheck,
      lastDocumentCheck: documentCheck,
      lastElectronicBookkeepingCheck: electronicBookkeepingCheck,
      chainHealthy: chainHealthy,
      lastFullVerifyAt: DateTime.now(),
    );
  }
}
