import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../models/invoice_models.dart';
import '../../../models/customer_model.dart';
import '../../../models/project_model.dart';
import '../../../models/product_model.dart';
import '../../../services/product_repository.dart';
import '../../../services/edit_log_repository.dart';
import '../../../services/app_settings_repository.dart';
import '../../../widgets/document_card.dart';
import '../logic/invoice_item_ops.dart';
import '../logic/invoice_calculator.dart';
import '../logic/invoice_source_viewer.dart';
import '../logic/invoice_state_helpers.dart';
import '../widgets/invoice_header_section.dart';
import '../widgets/invoice_customer_section.dart';
import '../widgets/invoice_project_section.dart';
import '../widgets/invoice_info_section.dart';
import '../widgets/invoice_payment_section.dart';
import '../widgets/invoice_items_section.dart';
import '../widgets/invoice_summary_section.dart';
import '../widgets/invoice_red_invoice_section.dart';
import '../widgets/invoice_price_adjustment_dialog.dart';
import '../widgets/invoice_tax_rate_picker.dart';
import '../widgets/invoice_item_edit_sheet.dart';

class InvoiceBodyContent extends StatelessWidget {
  final DateTime selectedDate;
  final bool showNewBadge;
  final bool showCopyBadge;
  final bool isViewMode;
  final bool isLocked;
  final bool hasRedInvoice;
  final bool isRedInvoice;
  final DocumentType documentType;
  final Customer? selectedCustomer;
  final Invoice? currentInvoice;
  final List<InvoiceItem> items;
  final TextEditingController subjectController;
  final FocusNode subjectFocusNode;
  final String? currentId;
  final List<EditLogEntry> editLogs;
  final bool isSalesMode;
  final String salesPaymentMethod;
  final DateTime? salesPaymentDueDate;
  final DocumentStatus salesStatus;
  final List<Project> customerProjects;
  final String? selectedProjectId;
  final String? selectedProjectName;
  final bool summaryIsBlue;
  final double taxRate;
  final bool includeTax;
  final bool isTaxInclusiveMode;
  final int grossProfit;
  final NumberFormat format;
  final ProductRepository productRepo;
  final EditLogRepository editLogRepo;
  final AppSettingsRepository settingsRepo;
  final Customer? customerForPricing;
  final ValueChanged<List<InvoiceItem>> onItemsChanged;
  final ValueChanged<Invoice?> onCurrentInvoiceChanged;
  final void Function(double taxRate, bool includeTax, bool isTaxInclusiveMode) onTaxRateChanged;
  final VoidCallback onPushHistory;
  final VoidCallback onLoadEditLogs;

  final Future<void> Function()? onDateTap;
  final Future<void> Function()? onCreateReceipt;
  final Future<void> Function()? onSelectCustomer;
  final VoidCallback? onProjectTap;
  final ValueChanged<int> onDeleteItem;
  final void Function(int, int) onReorder;
  final ValueChanged<int> onDecrementQuantity;
  final void Function(int, int) onSetQuantity;
  final ValueChanged<int> onIncrementQuantity;
  final Future<void> Function() onCreateRedInvoice;
  final Future<void> Function() onViewSourceInvoice;
  final ValueChanged<String> onPaymentMethodChanged;
  final ValueChanged<DateTime?> onPaymentDueDateChanged;
  final VoidCallback onSalesStatusToggle;
  final ValueChanged<bool> onSummaryThemeChanged;
  final Future<Product> Function(Product) resolveVariant;

  const InvoiceBodyContent({
    super.key,
    required this.selectedDate,
    required this.showNewBadge,
    required this.showCopyBadge,
    required this.isViewMode,
    required this.isLocked,
    required this.hasRedInvoice,
    required this.isRedInvoice,
    required this.documentType,
    this.selectedCustomer,
    this.currentInvoice,
    required this.items,
    required this.subjectController,
    required this.subjectFocusNode,
    this.currentId,
    required this.editLogs,
    required this.isSalesMode,
    required this.salesPaymentMethod,
    this.salesPaymentDueDate,
    required this.salesStatus,
    required this.customerProjects,
    this.selectedProjectId,
    this.selectedProjectName,
    required this.summaryIsBlue,
    required this.taxRate,
    required this.includeTax,
    required this.isTaxInclusiveMode,
    required this.grossProfit,
    required this.format,
    required this.productRepo,
    required this.editLogRepo,
    required this.settingsRepo,
    this.customerForPricing,
    required this.onItemsChanged,
    required this.onCurrentInvoiceChanged,
    required this.onTaxRateChanged,
    required this.onPushHistory,
    required this.onLoadEditLogs,
    this.onDateTap,
    this.onCreateReceipt,
    this.onSelectCustomer,
    this.onProjectTap,
    required this.onDeleteItem,
    required this.onReorder,
    required this.onDecrementQuantity,
    required this.onSetQuantity,
    required this.onIncrementQuantity,
    required this.onCreateRedInvoice,
    required this.onViewSourceInvoice,
    required this.onPaymentMethodChanged,
    required this.onPaymentDueDateChanged,
    required this.onSalesStatusToggle,
    required this.onSummaryThemeChanged,
    required this.resolveVariant,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InvoiceHeaderSection(
          selectedDate: selectedDate,
          showNewBadge: showNewBadge,
          showCopyBadge: showCopyBadge,
          isViewMode: isViewMode,
          isLocked: isLocked,
          documentType: documentType,
          hasRedInvoice: hasRedInvoice,
          isRedInvoice: isRedInvoice,
          onDateTap: isViewMode ? null : onDateTap,
          onCreateReceipt: onCreateReceipt,
        ),
        const SizedBox(height: 16),
        InvoiceCustomerSection(
          selectedCustomer: selectedCustomer,
          currentInvoice: currentInvoice,
          isViewMode: isViewMode,
          isLocked: isLocked,
          onSelectCustomer: onSelectCustomer,
        ),
        const SizedBox(height: 12),
        InvoiceProjectSection(
          customerProjects: customerProjects,
          selectedProjectId: selectedProjectId,
          selectedProjectName: selectedProjectName,
          selectedCustomer: selectedCustomer,
          isViewMode: isViewMode,
          isLocked: isLocked,
          onTap: onProjectTap,
        ),
        const SizedBox(height: 16),
        InvoiceInfoSection(
          subjectFocusNode: subjectFocusNode,
          subjectController: subjectController,
          isViewMode: isViewMode,
          isLocked: isLocked,
          currentId: currentId,
          editLogs: editLogs,
        ),
        if (isSalesMode) ...[
          const SizedBox(height: 12),
          InvoicePaymentSection(
            isSalesMode: true,
            salesPaymentMethod: salesPaymentMethod,
            salesPaymentDueDate: salesPaymentDueDate,
            selectedDate: selectedDate,
            isViewMode: isViewMode,
            documentType: documentType,
            salesStatus: salesStatus,
            onPaymentMethodChanged: onPaymentMethodChanged,
            onPaymentDueDateChanged: onPaymentDueDateChanged,
            onSalesStatusToggle: onSalesStatusToggle,
          ),
        ],
        const SizedBox(height: 20),
        InvoiceItemsSection(
          items: items,
          format: format,
          isViewMode: isViewMode,
          isLocked: isLocked,
          onTapItem: (int idx) async {
            if (isLocked) return;
            final result = await showItemEditSheet(
              context,
              item: items[idx],
              customerId: customerForPricing?.id,
              productRepo: productRepo,
            );
            if (result == null || !context.mounted) return;
            final updatedItem = result['item'] as InvoiceItem;
            final productName = result['resolvedProductName'] as String;
            final priceNote = result['priceNote'] as String?;
            final newItems = List<InvoiceItem>.from(items);
            newItems[idx] = updatedItem;
            onItemsChanged(newItems);
            onPushHistory();
            final id = currentId ?? DateTime.now().millisecondsSinceEpoch.toString();
            final note = priceNote != null ? '（$priceNote）' : '';
            await editLogRepo.addLog(id, '明細「$productName」を商品マスターから変更しました$note');
            onLoadEditLogs();
          },
          onDeleteItem: onDeleteItem,
          onReorder: onReorder,
          onAddItem: () async {
            final result = await addItemToInvoice(
              context,
              productRepo: productRepo,
              customerId: customerForPricing?.id,
              resolveVariant: resolveVariant,
            );
            if (result == null || !context.mounted) return;
            final newItems = List<InvoiceItem>.from(items)..add(result.item);
            onItemsChanged(newItems);
            onPushHistory();
            final id = currentId ?? DateTime.now().millisecondsSinceEpoch.toString();
            final priceNote = result.priceNote != null ? '（${result.priceNote}）' : '';
            final msg = "商品「${result.productName}」を追加しました$priceNote";
            await editLogRepo.addLog(id, msg);
            onLoadEditLogs();
            if (result.source != PriceSource.master &&
                result.source != PriceSource.variantMaster) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  duration: const Duration(seconds: 2),
                  content: Row(
                    children: [
                      const Icon(Icons.discount, color: Colors.white, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text('${result.productName}: ${result.priceNote} → ¥${result.unitPrice}'),
                      ),
                    ],
                  ),
                  backgroundColor: Theme.of(context).colorScheme.primary,
                ),
              );
            }
          },
          onAddItemByBarcode: () async {
            final result = await addItemByBarcode(
              context,
              productRepo: productRepo,
              customerId: customerForPricing?.id,
              resolveVariant: resolveVariant,
            );
            if (result == null || !context.mounted) return;
            final newItems = List<InvoiceItem>.from(items)..add(result.item);
            onItemsChanged(newItems);
            onPushHistory();
            final id = currentId ?? DateTime.now().millisecondsSinceEpoch.toString();
            final priceNote = result.priceNote != null ? '（${result.priceNote}）' : '';
            await editLogRepo.addLog(id, "商品「${result.productName}」をバーコードから追加$priceNote");
            onLoadEditLogs();
          },
          onPasteItems: () async {
            final parsedItems = await pasteItemsFromBuffer(context);
            if (parsedItems == null || parsedItems.isEmpty || !context.mounted) return;
            final newItems = List<InvoiceItem>.from(items)..addAll(parsedItems);
            onItemsChanged(newItems);
            onPushHistory();
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('${parsedItems.length}件の明細を追加しました')),
            );
          },
          onDecrementQuantity: onDecrementQuantity,
          onSetQuantity: onSetQuantity,
          onIncrementQuantity: onIncrementQuantity,
        ),
        const SizedBox(height: 20),
        InvoiceSummarySection(
          subtotal: calculateSubTotal(items),
          itemDiscountAmount: calculateItemDiscount(items),
          priceAdjustmentDiscount: calculatePriceAdjustmentDiscount(
            currentInvoice, items, isTaxInclusiveMode, includeTax, taxRate,
          ),
          grossProfit: grossProfit,
          taxRate: taxRate,
          isTaxInclusiveMode: isTaxInclusiveMode,
          includeTax: includeTax,
          isViewMode: isViewMode,
          isLocked: isLocked,
          summaryIsBlue: summaryIsBlue,
          format: format,
          onPriceAdjustmentTap: () async {
            final result = await showPriceAdjustmentDialog(
              context,
              subtotal: calculateSubTotal(items),
              itemDiscount: calculateItemDiscount(items),
              taxRate: taxRate,
              includeTax: includeTax,
              isTaxInclusiveMode: isTaxInclusiveMode,
              currentAdjustmentType: currentInvoice?.priceAdjustmentType,
              currentAdjustmentUnit: currentInvoice?.priceAdjustmentUnit,
            );
            if (result != null && context.mounted) {
              final updated = currentInvoice?.copyWith(
                priceAdjustmentType: result['type'] as String?,
                priceAdjustmentUnit: result['unit'] as int?,
              );
              onCurrentInvoiceChanged?.call(updated);
              onPushHistory();
            }
          },
          onTaxRateTap: () async {
            final result = await showTaxRatePicker(
              context,
              currentRate: taxRate,
            );
            if (result != null && context.mounted) {
              onTaxRateChanged?.call(
                result['taxRate'] as double,
                result['includeTax'] as bool,
                result['isTaxInclusiveMode'] as bool,
              );
              onPushHistory();
              final logMsg = result['logMsg'] as String;
              if (logMsg.isNotEmpty) {
                final id = currentId ?? DateTime.now().millisecondsSinceEpoch.toString();
                await editLogRepo.addLog(id, logMsg);
                onLoadEditLogs();
              }
            }
          },
          onSummaryThemeChanged: (isBlue) async {
            onSummaryThemeChanged(isBlue);
            await settingsRepo.setSummaryTheme(isBlue ? 'blue' : 'white');
          },
        ),
        const SizedBox(height: 12),
        InvoiceRedInvoiceSection(
          isLocked: isLocked,
          currentId: currentId,
          hasRedInvoice: hasRedInvoice,
          isRedInvoice: isRedInvoice,
          sourceDocumentId: currentInvoice?.sourceDocumentId,
          documentType: documentType,
          redInvoiceButtonLabel: 'この${documentTypeLabel(documentType).replaceAll('書', '')}を取り消す赤伝を起票',
          onCreateRedInvoice: onCreateRedInvoice,
          onViewSourceInvoice: onViewSourceInvoice,
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}
