import 'package:flutter/material.dart';
import '../../../models/invoice_models.dart';
import '../../../models/payment_schedule_model.dart' show PaymentStatus;
import '../../../utils/theme_utils.dart';
import '../draft_badge.dart';

class InvoiceAppBar extends StatelessWidget {
  final DocumentType documentType;
  final bool isSalesMode;
  final bool isViewMode;
  final bool isDraft;
  final bool isLocked;
  final bool showCopyBadge;
  final bool titleBarFlash;
  final Invoice? currentInvoice;
  final bool canUndo;
  final bool canRedo;
  final bool saving;
  final VoidCallback? onCopyAsNew;
  final VoidCallback? onUndo;
  final VoidCallback? onRedo;
  final VoidCallback? onImportFromDocuments;
  final VoidCallback? onSave;
  final VoidCallback? onToggleEditMode;
  final VoidCallback? onDocumentTypeChangeTap;

  const InvoiceAppBar({
    super.key,
    required this.documentType,
    required this.isSalesMode,
    required this.isViewMode,
    required this.isDraft,
    required this.isLocked,
    this.showCopyBadge = false,
    this.titleBarFlash = false,
    this.currentInvoice,
    required this.canUndo,
    required this.canRedo,
    this.saving = false,
    this.onCopyAsNew,
    this.onUndo,
    this.onRedo,
    this.onImportFromDocuments,
    this.onSave,
    this.onToggleEditMode,
    this.onDocumentTypeChangeTap,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  String _documentTypeLabel(DocumentType type) {
    switch (type) {
      case DocumentType.estimation:
        return "見積書";
      case DocumentType.order:
        return "受注伝票";
      case DocumentType.delivery:
        return "納品書";
      case DocumentType.invoice:
        return "請求書";
      case DocumentType.receipt:
        return "領収書";
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final docColor = isSalesMode
        ? Theme.of(context).colorScheme.tertiary
        : documentTypeColor(documentType, Theme.of(context).colorScheme, isDark);
    final docFgColor = appBarForeground(docColor);

    return AppBar(
      backgroundColor: docColor,
      foregroundColor: docFgColor,
      leading: const BackButton(),
      titleSpacing: 0,
      title: GestureDetector(
        onTap: isSalesMode
            ? null
            : isDraft && !isLocked
            ? onDocumentTypeChangeTap
            : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: titleBarFlash
                ? docFgColor.withValues(alpha: 0.3)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(isSalesMode
                    ? "${isViewMode ? 'D3' : 'D4'}:売上${isViewMode ? '' : '(編集)'}"
                    : "${isViewMode ? 'D3' : 'D4'}:${_documentTypeLabel(documentType)}${isViewMode ? '' : '(編集)'}",
                    overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14)),
              ),
              if (isSalesMode)
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: docFgColor.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text('売上', style: TextStyle(fontSize: 9, color: docFgColor)),
                  ),
                )
              else if (currentInvoice != null && currentInvoice!.paymentStatus == PaymentStatus.paid)
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Icon(Icons.check_circle, size: 14, color: Colors.green),
                )
              else if (currentInvoice != null && currentInvoice!.paymentStatus == PaymentStatus.partial)
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Icon(Icons.adjust, size: 14, color: Colors.orange),
                ),
            ],
          ),
        ),
      ),
      actions: [
        if (isDraft && isViewMode)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            child: const DraftBadge(),
          ),
        IconButton(
          icon: AnimatedScale(
            scale: showCopyBadge ? 1.3 : 1.0,
            duration: const Duration(milliseconds: 150),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: EdgeInsets.all(showCopyBadge ? 8 : 0),
              decoration: BoxDecoration(
                color: showCopyBadge
                    ? Theme.of(context).colorScheme.secondary.withValues(alpha: 0.3)
                    : Colors.transparent,
                shape: BoxShape.circle,
                border: showCopyBadge
                    ? Border.all(color: Theme.of(context).colorScheme.secondary, width: 2)
                    : null,
              ),
              child: Icon(
                showCopyBadge ? Icons.check : Icons.copy,
                color: showCopyBadge ? Theme.of(context).colorScheme.secondary : null,
              ),
            ),
          ),
          tooltip: "コピーして新規",
          onPressed: onCopyAsNew,
        ),
        if (isLocked)
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: Icon(Icons.lock, color: docFgColor),
          )
        else if (isViewMode)
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: "編集モードにする",
            onPressed: onToggleEditMode,
          )
        else ...[
          IconButton(
            icon: const Icon(Icons.undo),
            onPressed: canUndo ? onUndo : null,
            tooltip: "元に戻す",
          ),
          IconButton(
            icon: const Icon(Icons.redo),
            onPressed: canRedo ? onRedo : null,
            tooltip: "やり直す",
          ),
          if (!isLocked)
            IconButton(
              icon: const Icon(Icons.file_download_outlined),
              tooltip: "伝票から取込",
              onPressed: onImportFromDocuments,
            ),
          if (!isLocked)
            IconButton(
              icon: const Icon(Icons.save),
              tooltip: "保存",
              onPressed: saving ? null : onSave,
            ),
        ],
      ],
    );
  }
}
