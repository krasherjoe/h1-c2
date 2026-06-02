import 'package:flutter/material.dart';
import '../../../models/customer_model.dart';
import '../../../services/customer_repository.dart';
import '../../../services/customer_data_cleaner.dart';
import '../../../services/master_csv_exporter.dart';
import '../../../services/sys_logger.dart';
import '../../../services/screen_id_logger.dart';
import '../../../widgets/generic_csv_import_screen.dart';

import '../screens/phonebook_selection_screen.dart';

Future<void> importCsv(BuildContext context, VoidCallback onComplete) async {
  await Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => GenericCsvImportScreen<Customer>(
        screenId: 'C1',
        entityName: '顧客',
        columns: const [
          ImportColumn(label: '表示名', required: true, matchKeywords: ['表示名', '名前', 'name', '顧客名']),
          ImportColumn(label: '正式名称', matchKeywords: ['正式名称', '正式名', 'formal']),
          ImportColumn(label: '電話番号', matchKeywords: ['電話', 'tel', 'phone']),
          ImportColumn(label: 'メール', matchKeywords: ['メール', 'email', 'mail']),
          ImportColumn(label: '住所', matchKeywords: ['住所', 'address']),
          ImportColumn(label: '敬称', matchKeywords: ['敬称', 'title', '称号']),
        ],
        onImport: (c) => CustomerRepository().saveCustomer(c),
        parser: (row, colMap, id) => Customer(
          id: id,
          displayName: row[colMap[0]].trim(),
          formalName: colMap[1] >= 0 && colMap[1] < row.length ? row[colMap[1]].trim() : row[colMap[0]].trim(),
          tel: colMap[2] >= 0 && colMap[2] < row.length ? row[colMap[2]].trim() : null,
          email: colMap[3] >= 0 && colMap[3] < row.length ? row[colMap[3]].trim() : null,
          address: colMap[4] >= 0 && colMap[4] < row.length ? row[colMap[4]].trim() : null,
          title: colMap[5] >= 0 && colMap[5] < row.length ? HonorificCode.toCode(row[colMap[5]].trim()) : HonorificCode.san,
        ),
        previewText1: (c) => c.displayName,
        previewText2: (c) => c.tel ?? '',
      ),
    ),
  );
  if (!context.mounted) return;
  onComplete();
}

void exportCsv(List<Customer> customers) {
  MasterCsvExporter.export(
    entityName: '顧客',
    headers: ['表示名', '正式名称', '電話番号', 'メール', '住所', '敬称'],
    rows: customers.map((c) => [
      c.displayName,
      c.formalName,
      c.tel ?? '',
      c.email ?? '',
      c.address ?? '',
      c.title,
    ]).toList(),
  );
}

Future<void> showPhonebookImport({
  required BuildContext context,
  required CustomerRepository customerRepo,
  required VoidCallback onComplete,
}) async {
  try {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(builder: (_) => const PhonebookSelectionScreen()),
    );
    if (!context.mounted) return;
    if (result != null) {
      final customer = result['customer'] as Customer?;
      if (customer == null) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('顧客データを取得できませんでした'),
            backgroundColor: Theme.of(context).colorScheme.secondary,
            duration: const Duration(seconds: 2),
          ),
        );
        return;
      }
      final issue = CustomerDataCleaner.analyzeCustomer(customer);
      final cleanCustomer = issue?.fixed ?? customer;
      try {
        await customerRepo.saveCustomer(cleanCustomer);
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(children: [
              Icon(Icons.check_circle, color: Theme.of(context).colorScheme.onPrimary),
              const SizedBox(width: 12),
              Expanded(child: Text('電話帳から「${cleanCustomer.displayName}」を追加しました')),
            ]),
            backgroundColor: Theme.of(context).colorScheme.primary,
            duration: const Duration(seconds: 3),
          ),
        );
        onComplete();
      } on DuplicateCustomerException catch (e) {
        SysLogger.instance.logError('C1', e);
        if (!context.mounted) return;
        await Future.delayed(const Duration(milliseconds: 100));
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        final shouldContinue = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Row(children: [
              Icon(Icons.warning_amber_rounded, color: Theme.of(context).colorScheme.secondary),
              const SizedBox(width: 8),
              const Text('顧客が重複しています'),
            ]),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('以下の顧客と重複している可能性があります：', style: TextStyle(fontWeight: FontWeight.w500)),
                  const SizedBox(height: 16),
                  _buildDuplicateInfoRow('表示名:', Text(e.customer.displayName)),
                  if (e.customer.tel != null && e.customer.tel!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _buildDuplicateInfoRow('電話番号:', Text(e.customer.tel!, style: TextStyle(color: Theme.of(context).colorScheme.secondary))),
                  ],
                  if (e.customer.email != null && e.customer.email!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _buildDuplicateInfoRow('メール:', Text(e.customer.email!)),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton.icon(
                onPressed: () => Navigator.pop(dialogContext, false),
                icon: const Icon(Icons.close),
                label: const Text('キャンセル'),
              ),
              ElevatedButton.icon(
                onPressed: () => Navigator.pop(dialogContext, true),
                icon: const Icon(Icons.add_circle_outline),
                label: const Text('上書き登録'),
                style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.secondary),
              ),
            ],
          ),
        );
        if (shouldContinue == true) {
          await customerRepo.saveCustomer(cleanCustomer, force: true);
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(children: [
                const Icon(Icons.info_outline),
                const SizedBox(width: 12),
                Expanded(child: Text('顧客を登録しました（重複許容）：${cleanCustomer.displayName}')),
              ]),
              backgroundColor: Theme.of(context).colorScheme.secondary,
              duration: const Duration(seconds: 3),
            ),
          );
          onComplete();
        }
      } catch (e) {
        if (!context.mounted) return;
        await Future.delayed(const Duration(milliseconds: 100));
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Icon(Icons.error_outline, color: Theme.of(context).colorScheme.onPrimary),
                  const SizedBox(width: 12),
                  const Expanded(child: Text('顧客登録中にエラーが発生しました')),
                ]),
              ],
            ),
            backgroundColor: Theme.of(context).colorScheme.error,
            duration: const Duration(seconds: 5),
          ),
        );
        ScreenIdLogger.log('C2', 'インポートエラー：$e');
      }
    }
  } catch (e, st) {
    ScreenIdLogger.log('C2', '_showPhonebookImport エラー：$e');
    ScreenIdLogger.log('C2', 'スタックトレース：$st');
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('電話帳の読み込みに失敗しました：$e')),
      );
    }
  }
}

Widget _buildDuplicateInfoRow(String label, Widget content) {
  return Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SizedBox(width: 80, child: Text(label)),
      Expanded(child: content),
    ],
  );
}
