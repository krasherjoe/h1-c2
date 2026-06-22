import 'package:flutter/material.dart';
import '../../../models/billing_template_model.dart';
import '../../../services/billing_template_repository.dart';
import 'billing_template_screen.dart';

class BillingTemplateListScreen extends StatefulWidget {
  const BillingTemplateListScreen({super.key});

  @override
  State<BillingTemplateListScreen> createState() => _BillingTemplateListScreenState();
}

class _BillingTemplateListScreenState extends State<BillingTemplateListScreen> {
  final _repo = BillingTemplateRepository();
  List<BillingTemplate> _templates = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final templates = await _repo.getAllTemplates();
      if (mounted) {
        setState(() {
          _templates = templates;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('読み込みエラー: $e')),
        );
      }
    }
  }

  Future<void> _deleteTemplate(BillingTemplate template) async {
    if (template.isDefault) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('デフォルトテンプレートは削除できません')),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('テンプレート削除'),
        content: Text('${template.name}を削除しますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('削除'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _repo.deleteTemplate(template.id);
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('削除しました')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('削除エラー: $e')),
        );
      }
    }
  }

  Future<void> _setDefaultTemplate(BillingTemplate template) async {
    try {
      await _repo.setDefaultTemplate(template.id);
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${template.name}をデフォルトに設定しました')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('設定エラー: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('請求テンプレート一覧'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _templates.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.receipt_long, size: 64, color: cs.onSurfaceVariant.withValues(alpha: 0.4)),
                      const SizedBox(height: 16),
                      const Text('テンプレートがありません'),
                      const SizedBox(height: 8),
                      Text(
                        '右下のボタンから新規作成',
                        style: TextStyle(color: cs.onSurfaceVariant),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _templates.length,
                  itemBuilder: (context, index) {
                    final template = _templates[index];
                    return _buildTemplateCard(template, cs);
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const BillingTemplateScreen(),
            ),
          );
          if (result == true) {
            _load();
          }
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildTemplateCard(BillingTemplate template, ColorScheme cs) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: template.isDefault ? cs.primary : cs.surfaceContainerHighest,
          child: Icon(
            template.isDefault ? Icons.star : Icons.receipt_long,
            color: template.isDefault ? cs.onPrimary : cs.onSurfaceVariant,
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                template.name,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            if (template.isDefault)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: cs.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'デフォルト',
                  style: TextStyle(
                    fontSize: 10,
                    color: cs.onPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (template.description != null) ...[
              Text(template.description!),
              const SizedBox(height: 4),
            ],
            Text(
              '${template.closingMonthType.displayName} / ${template.closingDay == 99 ? "月末" : "${template.closingDay}日"} 締め',
              style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
            ),
            Text(
              '${template.paymentTerm.displayName} / ${template.invoiceTiming.displayName}',
              style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
            ),
            if (template.autoGenerateInvoice || template.autoSendEmail) ...[
              const SizedBox(height: 4),
              Wrap(
                spacing: 4,
                children: [
                  if (template.autoGenerateInvoice)
                    _buildChip('自動発行', cs),
                  if (template.autoSendEmail)
                    _buildChip('自動メール', cs),
                ],
              ),
            ],
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (action) {
            switch (action) {
              case 'edit':
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => BillingTemplateScreen(
                      templateId: template.id,
                      isEditing: true,
                    ),
                  ),
                ).then((result) {
                  if (result == true) _load();
                });
                break;
              case 'default':
                _setDefaultTemplate(template);
                break;
              case 'delete':
                _deleteTemplate(template);
                break;
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(value: 'edit', child: Text('編集')),
            if (!template.isDefault)
              const PopupMenuItem(value: 'default', child: Text('デフォルトに設定')),
            if (!template.isDefault)
              const PopupMenuItem(value: 'delete', child: Text('削除', style: TextStyle(color: Colors.red))),
          ],
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => BillingTemplateScreen(
                templateId: template.id,
                isEditing: true,
              ),
            ),
          ).then((result) {
            if (result == true) _load();
          });
        },
      ),
    );
  }

  Widget _buildChip(String label, ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: cs.tertiaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          color: cs.onTertiaryContainer,
        ),
      ),
    );
  }
}
