import 'package:flutter/material.dart';
import '../../../models/customer_model.dart';
import '../../../models/project_model.dart';

class InvoiceProjectSection extends StatelessWidget {
  final List<Project> customerProjects;
  final String? selectedProjectId;
  final String? selectedProjectName;
  final Customer? selectedCustomer;
  final bool isViewMode;
  final bool isLocked;
  final VoidCallback? onTap;

  const InvoiceProjectSection({
    super.key,
    required this.customerProjects,
    this.selectedProjectId,
    this.selectedProjectName,
    this.selectedCustomer,
    required this.isViewMode,
    required this.isLocked,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasProjects = customerProjects.isNotEmpty;
    final displayText = selectedProjectId != null
        ? (selectedProjectName ?? "案件を選択中")
        : (hasProjects ? "案件を選択（任意）" : "案件なし");
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ListTile(
        leading: Icon(Icons.folder_special, color: Theme.of(context).colorScheme.tertiary),
        title: Text(
          displayText,
          style: TextStyle(
            color: selectedProjectId == null && hasProjects
                ? Theme.of(context).colorScheme.onSurfaceVariant
                : Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: isViewMode
            ? null
            : Text(
                hasProjects
                    ? "${customerProjects.length}件の案件が見つかりました"
                    : (selectedCustomer == null
                        ? "顧客を先に選択してください"
                        : "顧客に紐づく案件はありません"),
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
        trailing: (isViewMode || isLocked || !hasProjects)
            ? null
            : const Icon(Icons.chevron_right),
        onTap: (isViewMode || isLocked || !hasProjects)
            ? null
            : onTap,
      ),
    );
  }
}
