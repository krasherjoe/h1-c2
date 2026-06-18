import 'package:flutter/material.dart';
import '../../../models/customer_model.dart';
import '../../../models/custom_field_model.dart';
import '../../../services/customer_repository.dart';
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
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('敬称の重複は見つかりませんでした')));
  return;
}
