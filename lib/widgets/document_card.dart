import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// 汎用伝票カードウィジェット
/// 見積・受注・売上など、あらゆる伝票の一覧表示に使用可能
class DocumentCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String amount;
  final DateTime date;
  final DocumentStatus status;
  final Color themeColor;
  final VoidCallback? onTap;
  final List<CardAction>? actions;
  final String? grossProfit;
  final DateTime? paymentDueDate;

  const DocumentCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.date,
    required this.status,
    required this.themeColor,
    this.onTap,
    this.actions,
    this.grossProfit,
    this.paymentDueDate,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (subtitle.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              subtitle,
                              style: TextStyle(
                                fontSize: 14,
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        amount,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: themeColor,
                        ),
                      ),
                      Text(
                        DateFormat('yyyy/MM/dd').format(date),
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      if (paymentDueDate != null)
                        Text(
                          '入金予定: ${DateFormat('yyyy/MM/dd').format(paymentDueDate!)}',
                          style: TextStyle(
                            fontSize: 11,
                            color: Theme.of(context).colorScheme.tertiary,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _buildStatusChip(status, cs),
                  const Spacer(),
                  if (grossProfit != null && grossProfit!.isNotEmpty)
                    Text(
                      grossProfit!,
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.tertiary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  if (actions != null)
                    ...actions!.map((action) => Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: IconButton(
                            icon: Icon(action.icon, size: 20),
                            onPressed: action.onPressed,
                            tooltip: action.label,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        )),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(DocumentStatus status, ColorScheme cs) {
    Color color;
    String label;

    switch (status) {
      case DocumentStatus.draft:
        color = cs.secondary;
        label = '下書き';
        break;
      case DocumentStatus.confirmed:
        color = cs.tertiary;
        label = '確定';
        break;
      case DocumentStatus.cancelled:
        color = cs.outline;
        label = 'キャンセル';
        break;
    }

    return Chip(
      label: Text(label),
      backgroundColor: color.withValues(alpha: 0.2),
      labelStyle: TextStyle(
        color: color,
        fontSize: 12,
        fontWeight: FontWeight.w500,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}

/// 伝票ステータス
enum DocumentStatus {
  draft,
  confirmed,
  cancelled,
}

/// カードアクション
class CardAction {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  const CardAction({
    required this.label,
    required this.icon,
    required this.onPressed,
  });
}
