import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../models/invoice_models.dart';
import '../../../models/payment_schedule_model.dart' show PaymentStatus;
import '../../../widgets/document_card.dart' show DocumentStatus;

class InvoicePaymentSection extends StatelessWidget {
  final bool isSalesMode;
  final String salesPaymentMethod;
  final DateTime? salesPaymentDueDate;
  final DateTime selectedDate;
  final bool isViewMode;
  final DocumentType documentType;
  final String? bankAccountDisplay;
  final DocumentStatus salesStatus;
  final ValueChanged<String>? onPaymentMethodChanged;
  final ValueChanged<DateTime?>? onPaymentDueDateChanged;
  final VoidCallback? onSalesStatusToggle;

  const InvoicePaymentSection({
    super.key,
    required this.isSalesMode,
    required this.salesPaymentMethod,
    this.salesPaymentDueDate,
    required this.selectedDate,
    required this.isViewMode,
    required this.documentType,
    this.bankAccountDisplay,
    required this.salesStatus,
    this.onPaymentMethodChanged,
    this.onPaymentDueDateChanged,
    this.onSalesStatusToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isSalesMode) _buildSalesPaymentSection(context),
        _buildBankAccountSection(context),
      ],
    );
  }

  Widget _buildSalesPaymentSection(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final dateFmt = DateFormat('yyyy/MM/dd');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.payments, size: 18, color: cs.primary),
            const SizedBox(width: 8),
            Text('支払方法:', style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
            const SizedBox(width: 8),
            DropdownButton<String>(
              value: salesPaymentMethod,
              underline: const SizedBox(),
              isDense: true,
              items: ['現金', '振込', 'クレジットカード', '掛売', 'その他']
                  .map((m) => DropdownMenuItem(value: m, child: Text(m, style: const TextStyle(fontSize: 13))))
                  .toList(),
              onChanged: isViewMode ? null : (v) { if (v == null) return; onPaymentMethodChanged?.call(v); },
            ),
            const Spacer(),
            GestureDetector(
              onTap: isViewMode
                  ? null
                  : () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: salesPaymentDueDate ?? selectedDate.add(const Duration(days: 30)),
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) {
                        onPaymentDueDateChanged?.call(picked);
                      }
                    },
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.date_range, size: 18, color: cs.primary),
                  const SizedBox(width: 4),
                  Text(salesPaymentDueDate != null ? dateFmt.format(salesPaymentDueDate!) : '入金予定日未設定',
                      style: TextStyle(fontSize: 12, color: salesPaymentDueDate != null ? cs.onSurface : cs.onSurfaceVariant)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            const Icon(Icons.info_outline, size: 16),
            const SizedBox(width: 8),
            Text('ステータス: ', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: salesStatus == DocumentStatus.draft ? cs.secondaryContainer : cs.tertiaryContainer,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                salesStatus == DocumentStatus.draft ? '下書き' : '確定',
                style: TextStyle(fontSize: 11, color: salesStatus == DocumentStatus.draft ? cs.onSecondaryContainer : cs.onTertiaryContainer),
              ),
            ),
            if (!isViewMode) ...[
              const SizedBox(width: 8),
              TextButton(
                style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 28), tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                onPressed: onSalesStatusToggle,
                child: Text(salesStatus == DocumentStatus.draft ? '確定にする' : '下書きに戻す', style: TextStyle(fontSize: 11, color: cs.primary)),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildBankAccountSection(BuildContext context) {
    if (bankAccountDisplay == null) return const SizedBox.shrink();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            '振込先：',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: isDark ? Theme.of(context).colorScheme.onSurfaceVariant : Theme.of(context).colorScheme.onSurface,
            ),
          ),
          Expanded(
            child: Text(
              bankAccountDisplay!,
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
