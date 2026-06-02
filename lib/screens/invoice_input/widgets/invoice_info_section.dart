import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../services/edit_log_repository.dart';
import '../../../widgets/h1_text_field.dart';

class InvoiceInfoSection extends StatelessWidget {
  final FocusNode subjectFocusNode;
  final TextEditingController subjectController;
  final bool isViewMode;
  final bool isLocked;
  final String? currentId;
  final List<EditLogEntry> editLogs;

  const InvoiceInfoSection({
    super.key,
    required this.subjectFocusNode,
    required this.subjectController,
    required this.isViewMode,
    required this.isLocked,
    this.currentId,
    required this.editLogs,
  });

  BoxDecoration _cardDecoration(BuildContext context, {Color? baseColor}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    baseColor ??= Theme.of(context).cardColor;
    if (isDark) {
      return BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.alphaBlend(Colors.white.withValues(alpha: 0.10), baseColor),
            baseColor,
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant,
          width: 0.8,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.06),
            blurRadius: 6,
            spreadRadius: 0.5,
          ),
        ],
      );
    } else {
      return BoxDecoration(
        color: baseColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final textColor = Theme.of(context).colorScheme.onSurface;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "案件名 / 件名",
          style: TextStyle(fontWeight: FontWeight.bold, color: textColor),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: _cardDecoration(context),
          child: H1TextField(
            focusNode: subjectFocusNode,
            controller: subjectController,
            style: TextStyle(color: textColor),
            readOnly: isViewMode || isLocked,
            enableInteractiveSelection: !(isViewMode || isLocked),
            decoration: InputDecoration(
              hintText: "例：事務所改修工事 / 〇〇月分リース料",
              hintStyle: TextStyle(
                color: textColor.withAlpha((0.5 * 255).round()),
              ),
              border: InputBorder.none,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 4,
                vertical: 4,
              ),
            ),
          ),
        ),
        if (currentId != null) ...[
          const SizedBox(height: 12),
          _buildEditLogs(context),
        ],
      ],
    );
  }

  Widget _buildEditLogs(BuildContext context) {
    if (currentId == null) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final cardColor = theme.cardColor;
    final textColor = theme.colorScheme.onSurface;
    final subtitleColor = theme.colorScheme.onSurfaceVariant;
    final hintColor = theme.colorScheme.onSurface.withValues(alpha: 0.45);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0.5,
          color: cardColor,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: isDark
                      ? theme.colorScheme.shadow.withValues(alpha: 0.2)
                      : theme.colorScheme.shadow.withValues(alpha: 0.08),
                  blurRadius: 10,
                  spreadRadius: -4,
                  offset: const Offset(0, 2),
                  blurStyle: BlurStyle.inner,
                ),
              ],
            ),
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "編集ログ (直近1週間)",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 8),
                if (editLogs.isEmpty)
                  Text(
                    "編集ログはありません",
                    style: TextStyle(color: hintColor, fontSize: 12),
                  )
                else
                  SelectionArea(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: editLogs.map((e) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.circle, size: 6, color: hintColor),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SelectableText(
                                    DateFormat('yyyy/MM/dd HH:mm').format(e.createdAt),
                                    style: TextStyle(fontSize: 11, color: subtitleColor),
                                  ),
                                  SelectableText(
                                    e.message,
                                    style: TextStyle(fontSize: 13, color: textColor),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      )).toList(),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
