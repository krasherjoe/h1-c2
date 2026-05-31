import 'package:flutter/material.dart';
import '../../../models/invoice_models.dart';

class InvoiceBottomBar extends StatelessWidget {
  final bool isSalesMode;
  final bool isViewMode;
  final bool isLocked;
  final bool hasItems;
  final bool emailSentAtNull;
  final bool printedAtNull;
  final Invoice? currentInvoice;
  final bool isYoungestEntry;
  final VoidCallback? onPreview;
  final VoidCallback? onEdit;
  final VoidCallback? onSave;
  final VoidCallback? onRevertFormalIssue;

  const InvoiceBottomBar({
    super.key,
    required this.isSalesMode,
    required this.isViewMode,
    required this.isLocked,
    required this.hasItems,
    required this.emailSentAtNull,
    required this.printedAtNull,
    required this.currentInvoice,
    required this.isYoungestEntry,
    this.onPreview,
    this.onEdit,
    this.onSave,
    this.onRevertFormalIssue,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(left: 16, right: 16, bottom: 20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.shadow.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              behavior: HitTestBehavior.translucent,
              onVerticalDragUpdate: (_) {},
              child: Row(
                children: [
                  if (!isSalesMode)
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: (hasItems && onPreview != null) ? onPreview : null,
                        icon: const Icon(Icons.picture_as_pdf),
                        label: const Text("PDFプレビュー"),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          side: BorderSide(color: Theme.of(context).colorScheme.primary),
                        ),
                      ),
                    ),
                  if (!isSalesMode) const SizedBox(width: 8),
                  Expanded(
                    child: isLocked
                        ? (emailSentAtNull && printedAtNull
                            && currentInvoice != null
                            && isYoungestEntry
                            ? OutlinedButton.icon(
                                onPressed: onRevertFormalIssue,
                                icon: const Icon(Icons.lock_open),
                                label: const Text("下書きに戻す"),
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(color: Colors.orange.shade400),
                                  foregroundColor: Colors.orange.shade700,
                                ),
                              )
                            : SizedBox(
                                width: double.infinity,
                                child: Chip(
                                  avatar: const Icon(Icons.lock, size: 16),
                                  label: const Text("編集不可（送信・印刷済）"),
                                  backgroundColor: Colors.grey.shade200,
                                ),
                              ))
                        : (isViewMode
                              ? ElevatedButton.icon(
                                  onPressed: onEdit,
                                  icon: const Icon(Icons.edit),
                                  label: const Text("編集"),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Theme.of(context).colorScheme.primary,
                                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                  ),
                                )
                              : ElevatedButton.icon(
                                  onPressed: onSave,
                                  icon: const Icon(Icons.save),
                                  label: const Text("保存"),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Theme.of(context).colorScheme.primary,
                                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                  ),
                                )),
                  ),
                ],
              ),
            ),
            if (isViewMode)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(top: 12),
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.swipe, size: 16, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 6),
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'タイトルバー横になぞると拡大縮小できます',
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
