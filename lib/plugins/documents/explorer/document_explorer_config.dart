import 'package:flutter/material.dart';
import '../../../plugins/explorer/h1_explorer_config.dart';
import '../../../models/document_type_colors.dart';
import '../../../utils/theme_utils.dart' hide documentTypeColor;
import '../../../services/input_style_service.dart';
import '../models/document_model.dart';
import '../services/document_repository.dart';
import '../screens/document_page.dart';

class DocumentExplorerConfig extends H1ExplorerConfig<DocumentModel> {
  DocumentExplorerConfig();

  @override
  bool get viewerHasOwnScaffold => true;

  // ...

  @override
  Widget buildViewer(BuildContext context, DocumentModel item) {
    return DocumentPage(document: item, isEditing: false);
  }

  @override
  Widget buildEditor(BuildContext context, DocumentModel? item) {
    return DocumentPage(document: item, isEditing: true);
  }

  static const _typeOptions = [
    (value: '', label: 'すべて', icon: Icons.all_inbox),
    (value: 'invoice', label: '請求書', icon: Icons.receipt_long),
    (value: 'receipt', label: '領収書', icon: Icons.receipt),
    (value: 'estimation', label: '見積書', icon: Icons.request_quote),
    (value: 'order', label: '受注書', icon: Icons.shopping_cart_checkout),
    (value: 'delivery', label: '納品書', icon: Icons.local_shipping),
  ];

  @override
  String get explorerTitle => 'D1:伝票管理';

  @override
  List<({String value, String label, IconData icon})> get typeFilterOptions => _typeOptions;

  @override
  String get searchHint => '伝票番号・顧客名で検索';

  @override
  bool get showSearch => true;

  @override
  IconData get itemIcon => Icons.description;

  @override
  String get emptyMessage => '伝票がありません';

  @override
  Future<List<DocumentModel>> fetchItems(String query) async {
    final repo = DocumentRepository();
    DocumentType? filterType;
    if (typeFilter.isNotEmpty) {
      filterType = documentTypeFromString(typeFilter);
    }
    return repo.fetchAll(
      filterType: filterType,
      query: query,
      statusFilter: statusFilter.isNotEmpty ? statusFilter : null,
      dateFrom: dateFrom,
      dateTo: dateTo,
    );
  }

  @override
  Widget buildItemTileContent(BuildContext context, DocumentModel item) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final doctypeColor = documentTypeColor(item.documentType, cs, isDark);
    final verticalType = item.documentType.label.split('').join('\n');
    final repItems = item.items.take(3).map((i) => i.productName).join('、');
    final subject = (item.subject != null && item.subject!.isNotEmpty) ? item.subject : null;
    final date = '${item.date.year}/${item.date.month.toString().padLeft(2, '0')}/${item.date.day.toString().padLeft(2, '0')}';
    final money = '¥${item.total.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}';
    final hasDraft = item.isDraft;
    return ValueListenableBuilder<String>(
      valueListenable: inputStyleNotifier,
      builder: (context, inputStyle, _) {
        final isRaised = inputStyle == 'raised';
        final cardBg = hasDraft
            ? cs.surfaceContainerLow
            : (Theme.of(context).cardTheme.color ?? cs.surface);
        return Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(8),
          boxShadow: isRaised ? [
            BoxShadow(color: cs.shadow.withValues(alpha: 0.12), blurRadius: 8, offset: const Offset(0, 2)),
            BoxShadow(color: cs.shadow.withValues(alpha: 0.06), blurRadius: 16, offset: const Offset(0, 4)),
          ] : null,
        ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
        height: (88 * MediaQuery.textScalerOf(context).scale(1.0)).ceilToDouble(),
        child: Row(
          children: [
            Container(
              width: 22,
              color: doctypeColor,
              alignment: Alignment.center,
              child: Text(verticalType,
                  style: TextStyle(color: textColorOn(doctypeColor), fontSize: 11, fontWeight: FontWeight.bold, height: 1.15),
                  textAlign: TextAlign.center),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(0, 8, 8, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Text(date, style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(item.customerName,
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: cs.onSurface),
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                      if (hasDraft) _statusBadge('下書き', Colors.orange),
                    ]),
                    if (subject != null)
                      Text(subject!, style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                    Expanded(
                      child: Row(children: [
                        Text('📄', style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant)),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(repItems,
                              style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                        ),
                      ]),
                    ),
                    Row(children: [
                      Text('💰', style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant)),
                      const SizedBox(width: 4),
                      Text(money,
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: cs.primary)),
                    ]),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
    );
  },
);
  }

  Widget _statusBadge(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(4),
    ),
    child: Text(text,
        style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w500)),
  );

  @override
  Future<bool> canDelete(DocumentModel item) async => item.isDraft;

  @override
  Future<void> deleteItem(DocumentModel item) async {
    final repo = DocumentRepository();
    await repo.delete(item.id);
  }
}
