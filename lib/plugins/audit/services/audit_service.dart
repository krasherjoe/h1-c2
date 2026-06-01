import 'package:sqflite/sqflite.dart';
import '../../../services/hash_chain_verify_result.dart';
import '../../../services/customer_repository.dart';
import '../../../services/product_repository.dart';
import '../../../services/invoice_repository.dart';

class AuditResult {
  final int totalHashEntries;
  final HashChainVerifyResult? lastCustomerCheck;
  final HashChainVerifyResult? lastProductCheck;
  final HashChainVerifyResult? lastInvoiceCheck;
  final DateTime? lastFullVerifyAt;
  final bool chainHealthy;

  AuditResult({
    required this.totalHashEntries,
    this.lastCustomerCheck,
    this.lastProductCheck,
    this.lastInvoiceCheck,
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

    final customerRepo = CustomerRepository();
    final productRepo = ProductRepository();
    final invoiceRepo = InvoiceRepository();

    final customerCheck = await customerRepo.verifyTailN(n: 10);
    final productCheck = await productRepo.verifyTailN(n: 10);
    final invoiceCheck = await invoiceRepo.verifyAllLocked();

    final chainHealthy = customerCheck.isHealthy &&
        productCheck.isHealthy &&
        invoiceCheck.isHealthy;

    return AuditResult(
      totalHashEntries: totalHashEntries,
      lastCustomerCheck: customerCheck,
      lastProductCheck: productCheck,
      lastInvoiceCheck: invoiceCheck,
      chainHealthy: chainHealthy,
      lastFullVerifyAt: DateTime.now(),
    );
  }
}
