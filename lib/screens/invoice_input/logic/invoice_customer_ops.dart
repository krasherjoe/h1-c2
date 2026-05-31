import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../models/customer_model.dart';
import '../../../models/invoice_models.dart';
import '../../../models/project_model.dart';
import '../../../services/product_repository.dart';
import '../../../services/project_repository.dart';
import '../../../screens/customer_master/customer_master_screen.dart';
import '../widgets/invoice_quick_project_dialog.dart';

Future<Customer?> selectCustomer(
  BuildContext context, {
  required Customer? currentCustomer,
  required List<InvoiceItem> items,
  required ProductRepository productRepo,
  required ValueChanged<List<InvoiceItem>> onItemsRecalculated,
}) async {
  final Customer? picked = await Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => CustomerMasterScreen(selectionMode: true),
      fullscreenDialog: true,
    ),
  );
  if (picked == null || !context.mounted) return null;
  if (picked.id == currentCustomer?.id) return null;

  if (items.isNotEmpty) {
    final shouldRecalculate = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('顧客変更と価格再計算'),
        content: Text(
          '明細${items.length}件があります。'
          '「${picked.displayName}」のランク・顧客別価格に基づき、'
          '単価を再計算しますか？',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('変更のみ'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('再計算する'),
          ),
        ],
      ),
    );
    if (!context.mounted) return null;

    if (shouldRecalculate == true) {
      final newItems = List<InvoiceItem>.from(items);
      int changedCount = 0;
      for (int i = 0; i < newItems.length; i++) {
        final item = newItems[i];
        if (item.productId != null) {
          final resolved = await productRepo.resolveUnitPrice(
            productId: item.productId!,
            customerId: picked.id,
          );
          if (!context.mounted) return null;
          newItems[i] = item.copyWith(unitPrice: resolved.unitPrice);
          changedCount++;
        }
      }
      if (context.mounted) {
        onItemsRecalculated(newItems);
        if (changedCount > 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$changedCount件の単価を再計算しました'),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    }
  }

  return picked;
}

void showProjectPicker(
  BuildContext context, {
  required List<Project> customerProjects,
  required String? selectedProjectId,
  required String? selectedProjectName,
  required Customer? selectedCustomer,
  required String initialSubject,
  required ProjectRepository projectRepo,
  required ValueChanged<String?> onProjectSelected,
  required ValueChanged<Project> onProjectCreated,
}) {
  if (customerProjects.isEmpty) return;
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("案件を選択", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: Icon(Icons.remove_circle_outline, color: Theme.of(context).colorScheme.onSurfaceVariant),
              title: Text("案件なし", style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
              onTap: () {
                onProjectSelected(null);
                Navigator.pop(ctx);
              },
            ),
            const Divider(),
            ...customerProjects.map((p) => ListTile(
              leading: Icon(
                Icons.folder_special,
                color: p.status == ProjectStatus.active ? Theme.of(context).colorScheme.secondary : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              title: Text(p.name),
              subtitle: Text("${p.status.displayName} ・ ${NumberFormat('#,###').format(p.totalAmount)}円"),
              trailing: selectedProjectId == p.id
                  ? Icon(Icons.check_circle, color: Theme.of(context).colorScheme.secondary)
                  : null,
              onTap: () {
                onProjectSelected(p.id);
                Navigator.pop(ctx);
              },
            )),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  Navigator.pop(ctx);
                  if (selectedCustomer == null) return;
                  final newProject = await showQuickProjectCreateDialog(
                    context,
                    customerId: selectedCustomer.id,
                    customerName: selectedCustomer.displayName,
                    initialSubject: initialSubject,
                    projectRepo: projectRepo,
                  );
                  if (newProject == null || !context.mounted) return;
                  onProjectCreated(newProject);
                },
                icon: const Icon(Icons.add),
                label: const Text("新規案件を作成"),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
