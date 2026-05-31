import 'package:flutter/material.dart';
import '../../../models/invoice_models.dart';
import '../../../services/invoice_repository.dart';
import '../../../services/sys_logger.dart';

Future<Invoice?> createReceiptFromInvoice({
  required BuildContext context,
  required InvoiceRepository invoiceRepo,
  required Invoice originalInvoice,
  required bool isRedInvoice,
}) async {
  if (originalInvoice.isRedInvoice == true || isRedInvoice) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('この伝票は取消済みのため領収証を生成できません')),
      );
    }
    return null;
  }

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('領収証を生成します'),
      content: const Text('この請求書から領収証を生成してもよろしいですか？'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('キャンセル'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: ElevatedButton.styleFrom(backgroundColor: Theme.of(ctx).colorScheme.secondary),
          child: const Text('生成'),
        ),
      ],
    ),
  );

  if (confirmed != true) return null;

  try {
    final newReceiptId = DateTime.now().millisecondsSinceEpoch.toString();
    final receipt = originalInvoice.copyWith(
      id: newReceiptId,
      documentType: DocumentType.receipt,
      isDraft: true,
      isLocked: false,
      taxRate: originalInvoice.taxRate,
      includeTax: originalInvoice.includeTax,
      isTaxInclusiveMode: originalInvoice.isTaxInclusiveMode,
      totalDiscountAmount: originalInvoice.totalDiscountAmount,
      totalDiscountRate: originalInvoice.totalDiscountRate,
      priceAdjustmentType: originalInvoice.priceAdjustmentType,
      priceAdjustmentUnit: originalInvoice.priceAdjustmentUnit,
    );

    await invoiceRepo.saveInvoice(receipt);
    return receipt;
  } catch (e) {
    SysLogger.instance.logError('InvIn', e);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('エラー: $e'), backgroundColor: Theme.of(context).colorScheme.error),
      );
    }
    return null;
  }
}
