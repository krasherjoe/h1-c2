import 'package:flutter/material.dart';
import '../../../services/invoice_repository.dart';

bool isYoungestHashChainEntry(String? currentId, bool? isYoungestIssued) {
  return currentId != null && isYoungestIssued == true;
}

/// Returns true if revert was successful.
Future<bool> confirmAndRevertFormalIssue(
  BuildContext context, {
  required InvoiceRepository invoiceRepo,
  required String currentId,
  required bool isLocked,
  required String? emailSentAt,
  required String? printedAt,
}) async {
  if (!isLocked || emailSentAt != null || printedAt != null) return false;

  if (!await invoiceRepo.isYoungestIssuedInvoice(currentId)) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('この伝票より新しい伝票があるため下書きに戻せません')),
      );
    }
    return false;
  }

  final confirm = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('正式発行の取り消し'),
      content: const Text('この伝票を下書き状態に戻します。\n再度正式発行する必要があります。\n\nよろしいですか？'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('キャンセル')),
        ElevatedButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
          child: const Text('下書きに戻す', style: TextStyle(color: Colors.white)),
        ),
      ],
    ),
  );
  if (confirm != true) return false;

  final ok = await invoiceRepo.revertFormalIssue(currentId);
  if (ok ?? false) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('下書き状態に戻しました。引き続き編集できます。'),
        backgroundColor: Colors.orange,
      ));
    }
    return true;
  } else {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('取り消しに失敗しました（条件を満たしていない可能性があります）'),
        backgroundColor: Colors.red,
      ));
    }
    return false;
  }
}
