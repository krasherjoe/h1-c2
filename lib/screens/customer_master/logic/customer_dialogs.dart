import 'package:flutter/material.dart';
import '../../../models/customer_model.dart';
import '../../../models/custom_field_model.dart';
import '../../../services/customer_repository.dart';
import '../../../services/customer_data_cleaner.dart';
import '../../../services/sys_logger.dart';
import '../../../widgets/custom_field_display_widget.dart';
import '../../../widgets/h1_text_field.dart';

Future<void> showContactUpdateDialog({
  required BuildContext context,
  required Customer customer,
  required CustomerRepository customerRepo,
  required VoidCallback onComplete,
}) async {
  final emailController = TextEditingController(text: customer.email ?? "");
  final telController = TextEditingController(text: customer.tel ?? "");
  final addressController = TextEditingController(text: customer.address ?? "");
  final updated = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('連絡先を更新'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          H1TextField(controller: emailController, decoration: const InputDecoration(labelText: 'メール')),
          H1TextField(controller: telController, decoration: const InputDecoration(labelText: '電話番号'), keyboardType: TextInputType.phone),
          H1TextField(controller: addressController, decoration: const InputDecoration(labelText: '住所')),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('キャンセル')),
        ElevatedButton(
          onPressed: () async {
            await customerRepo.updateContact(
              customerId: customer.id,
              email: emailController.text.isEmpty ? null : emailController.text,
              tel: telController.text.isEmpty ? null : telController.text,
              address: addressController.text.isEmpty ? null : addressController.text,
            );
            if (!context.mounted) return;
            Navigator.pop(context, true);
          },
          child: const Text('保存'),
        ),
      ],
    ),
  );
  if (!context.mounted) return;
  if (updated == true) onComplete();
}

void showContextActions({
  required BuildContext context,
  required Customer c,
  required CustomerRepository customerRepo,
  required List<CustomField> customFields,
  required VoidCallback onEdit,
  required VoidCallback onContactUpdate,
  required VoidCallback onReload,
}) {
  showModalBottomSheet(
    context: context,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('詳細を表示'),
            onTap: () {
              Navigator.pop(ctx);
              showDetailPane(
                context: context, c: c, onEdit: onEdit,
                onContactUpdate: () { onContactUpdate(); },
                customerRepo: customerRepo,
                customFields: customFields,
                onReload: onReload,
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.edit), title: const Text('編集'),
            onTap: () { Navigator.pop(ctx); onEdit(); },
          ),
          ListTile(
            leading: const Icon(Icons.contact_mail), title: const Text('連絡先を更新'),
            onTap: () { Navigator.pop(ctx); onContactUpdate(); },
          ),
          ListTile(
            leading: const Icon(Icons.visibility_off), title: const Text('非表示にする'),
            onTap: () async {
              Navigator.pop(ctx);
              await customerRepo.setHidden(c.id, true);
              if (!context.mounted) return;
              onReload();
            },
          ),
          ListTile(
            leading: Icon(Icons.delete_outline, color: Theme.of(context).colorScheme.error),
            title: Text('削除', style: TextStyle(color: Theme.of(context).colorScheme.error)),
            onTap: () async {
              Navigator.pop(ctx);
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('削除確認（電子帳簿保存法）'),
                  content: Text('「${c.displayName}」を削除しますか？\n※電子帳簿保存法により、実際の削除は行わずに非表示フラグのみを設定します。履歴は保持されます。'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('キャンセル')),
                    TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text('削除', style: TextStyle(color: Theme.of(context).colorScheme.error))),
                  ],
                ),
              );
              if (confirm == true) {
                await customerRepo.setHidden(c.id, true);
                if (!context.mounted) return;
                onReload();
              }
            },
          ),
        ],
      ),
    ),
  );
}

void showDetailPane({
  required BuildContext context,
  required Customer c,
  required VoidCallback onEdit,
  required VoidCallback? onContactUpdate,
  required CustomerRepository customerRepo,
  required List<CustomField> customFields,
  required VoidCallback onReload,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (context) => DraggableScrollableSheet(
      initialChildSize: 0.5,
      maxChildSize: 0.8,
      minChildSize: 0.4,
      expand: false,
      builder: (context, scrollController) => Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          controller: scrollController,
          children: [
            Row(children: [
              Icon(c.isLocked ? Icons.link : Icons.person,
                  color: c.isLocked ? Theme.of(context).colorScheme.error : Theme.of(context).colorScheme.primary),
              const SizedBox(width: 8),
              Expanded(child: Text(c.formalName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18))),
            ]),
            const SizedBox(height: 8),
            if (c.address != null) Text('住所: ${c.address}') else const SizedBox.shrink(),
            if (c.tel != null) Text('TEL: ${c.tel}') else const SizedBox.shrink(),
            if (c.email != null) Text('メール: ${c.email}') else const SizedBox.shrink(),
            Text('敬称: ${c.title}'),
            const SizedBox(height: 12),
            if (customFields.isNotEmpty) ...[
              const Divider(),
              const SizedBox(height: 8),
              Text('カスタムフィールド', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Theme.of(context).colorScheme.onSurfaceVariant)),
              const SizedBox(height: 8),
              CustomFieldDisplayWidget(entityId: c.id, entityType: 'customer', fields: customFields),
            ],
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 8, children: [
              OutlinedButton.icon(
                onPressed: () { Navigator.pop(context); onEdit(); },
                icon: const Icon(Icons.edit),
                label: Text(c.isLocked ? '編集（履歴保存）' : '編集'),
              ),
              if (onContactUpdate != null)
                OutlinedButton.icon(
                  onPressed: c.isLocked ? null : () { Navigator.pop(context); onContactUpdate(); },
                  icon: const Icon(Icons.contact_mail),
                  label: const Text('連絡先を更新'),
                ),
              if (!c.isLocked)
                OutlinedButton.icon(
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('削除確認'),
                        content: Text('「${c.displayName}」を削除しますか？'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('キャンセル')),
                          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text('削除', style: TextStyle(color: Theme.of(context).colorScheme.error))),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      Navigator.pop(context);
                      await customerRepo.setHidden(c.id, true);
                      if (!context.mounted) return;
                      onReload();
                    }
                  },
                  icon: Icon(Icons.delete_outline, color: Theme.of(context).colorScheme.error),
                  label: Text('削除', style: TextStyle(color: Theme.of(context).colorScheme.error)),
                ),
            ]),
          ],
        ),
      ),
    ),
  );
}

Future<void> cleanDuplicateHonorific({
  required BuildContext context,
  required List<Customer> customers,
  required CustomerRepository customerRepo,
  required VoidCallback onComplete,
}) async {
  try {
    final issues = CustomerDataCleaner.screenAll(customers);
    if (issues.isEmpty) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('敬称の重複は見つかりませんでした')));
      return;
    }
    if (!context.mounted) return;
    await _showHonorificScreeningDialog(context, issues, customerRepo, onComplete);
  } catch (e) {
    SysLogger.instance.logError('C1', e);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('エラーが発生しました: $e')));
  }
}

Future<void> _showHonorificScreeningDialog(
  BuildContext context,
  List<HonorificsIssue> issues,
  CustomerRepository customerRepo,
  VoidCallback onComplete,
) async {
  final selected = <String, bool>{};
  for (final i in issues) selected[i.original.id] = true;

  await showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialogState) {
        final checked = issues.where((i) => selected[i.original.id] ?? true).toList();
        return AlertDialog(
          title: Row(children: [
            Icon(Icons.auto_fix_high, color: Theme.of(context).colorScheme.secondary),
            const SizedBox(width: 8),
            const Text('敬称重複チェック'),
          ]),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(children: [
                    Icon(Icons.warning_amber, color: Theme.of(context).colorScheme.secondary, size: 18),
                    const SizedBox(width: 6),
                    Text('${issues.length}件の問題を検出', style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSecondaryContainer)),
                    const Spacer(),
                    TextButton(onPressed: () => setDialogState(() { for (final i in issues) selected[i.original.id] = true; }), child: const Text('全選択')),
                    TextButton(onPressed: () => setDialogState(() { for (final i in issues) selected[i.original.id] = false; }), child: const Text('解除')),
                  ]),
                ),
                const SizedBox(height: 8),
                ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.45),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: issues.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final issue = issues[i];
                      final isChecked = selected[issue.original.id] ?? true;
                      return CheckboxListTile(
                        value: isChecked,
                        onChanged: (v) => setDialogState(() => selected[issue.original.id] = v ?? false),
                        dense: true,
                        title: Text(issue.original.displayName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          if (issue.fixedFormalName != issue.original.formalName)
                            RichText(text: TextSpan(style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurface), children: [
                              TextSpan(text: '正式: ', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                              TextSpan(text: issue.original.formalName, style: TextStyle(color: Theme.of(context).colorScheme.error, decoration: TextDecoration.lineThrough)),
                              const TextSpan(text: ' → '),
                              TextSpan(text: issue.fixedFormalName, style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold)),
                            ])),
                          if (issue.fixedDisplayName != issue.original.displayName)
                            RichText(text: TextSpan(style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurface), children: [
                              TextSpan(text: '表示: ', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                              TextSpan(text: issue.original.displayName, style: TextStyle(color: Theme.of(context).colorScheme.error, decoration: TextDecoration.lineThrough)),
                              const TextSpan(text: ' → '),
                              TextSpan(text: issue.fixedDisplayName, style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold)),
                            ])),
                          Text('敬称: ${issue.original.title}', style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                        ]),
                      );
                    },
                  ),
                ),
                if (checked.isNotEmpty)
                  Padding(padding: const EdgeInsets.only(top: 8), child: Text('${checked.length}件を修正します', style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.secondary))),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('キャンセル')),
            ElevatedButton.icon(
              icon: const Icon(Icons.auto_fix_high, size: 18),
              label: Text('${checked.length}件を修正'),
              style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.secondary),
              onPressed: checked.isEmpty ? null : () async {
                Navigator.pop(ctx);
                for (final issue in checked) {
                  try {
                    if (issue.fixed != null) await customerRepo.saveCustomer(issue.fixed!);
                  } catch (e) {
                    debugPrint('[CustomerMaster] honorific fix error: $e');
                  }
                }
                onComplete();
              },
            ),
          ],
        );
      },
    ),
  );
}
