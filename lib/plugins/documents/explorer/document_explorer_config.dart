import 'package:flutter/material.dart';
import '../../../plugins/explorer/h1_explorer_config.dart';
import '../../../models/document_type_colors.dart';
import '../../../utils/theme_utils.dart' hide documentTypeColor;
import '../../../services/input_style_service.dart';
import '../models/document_model.dart';
import '../services/document_repository.dart';
import '../screens/document_page.dart';
import '../../project/screens/project_detail_screen.dart';
import '../../../constants/screen_ids.dart';

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
    (value: 'invoice', label: '請求', icon: Icons.receipt_long),
    (value: 'receipt', label: '領収', icon: Icons.receipt),
    (value: 'estimation', label: '見積', icon: Icons.request_quote),
    (value: 'order', label: '受注', icon: Icons.shopping_cart_checkout),
    (value: 'delivery', label: '納品', icon: Icons.local_shipping),
    (value: 'bulk_invoice', label: '一括請求', icon: Icons.collections),
  ];

  @override
  String get explorerTitle => '${S.d1}:伝票管理';

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

  static IconData _typeIcon(DocumentType type) => switch (type) {
    DocumentType.estimation => Icons.request_quote,
    DocumentType.order => Icons.shopping_cart_checkout,
    DocumentType.delivery => Icons.local_shipping,
    DocumentType.invoice => Icons.receipt_long,
    DocumentType.receipt => Icons.receipt,
  };

  @override
  List<({IconData icon, String label, Future<void> Function() onTap})>? fabActions(
          BuildContext context) =>
      DocumentType.values.map((t) => (
        icon: _typeIcon(t),
        label: '${t.label}を新規作成',
        onTap: () => _openNewDocument(context, t),
      )).toList();

  Future<void> _openNewDocument(BuildContext context, DocumentType type) async {
    final result = await Navigator.push<dynamic>(
      context,
      MaterialPageRoute(
        builder: (_) => DocumentPage(
          isEditing: true,
          initialType: type,
        ),
      ),
    );
    if (result != null) {
      onListChanged?.call();
    }
  }

  @override
  Future<List<DocumentModel>> fetchItems(String query) async {
    final repo = DocumentRepository();
    DocumentType? filterType;
    if (typeFilter.isNotEmpty && typeFilter != 'bulk_invoice') {
      filterType = documentTypeFromString(typeFilter);
    }
    
    final documents = await repo.fetchAll(
      filterType: filterType,
      query: query,
      statusFilter: statusFilter.isNotEmpty ? statusFilter : null,
      dateFrom: dateFrom,
      dateTo: dateTo,
    );

    // 一括請求フィルタ（売掛レポート添付の請求書）
    if (typeFilter == 'bulk_invoice') {
      // TODO: 売掛レポート添付フラグでフィルタ
      // 現在は請求書のみ返す
      return documents.where((doc) => doc.documentType == DocumentType.invoice).toList();
    }

    return documents;
  }

  @override
  Widget buildItemTileContent(BuildContext context, DocumentModel item) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final doctypeColor = documentTypeColor(item.documentType, cs, isDark);
    // 伝票タイプを短縮（「書」を削除）
    final shortType = item.documentType.label.replaceAll('書', '');
    final verticalType = shortType.split('').join('\n');
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
                      if (hasDraft) _statusBadge('下書き', Colors.orange, cs),
                      if (item.projectId != null)
                        _ProjectBadge(projectId: item.projectId!),
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

  Widget _statusBadge(String text, Color color, ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color, width: 1),
      ),
      child: Text(text,
          style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w500)),
    );
  }

  @override
  Future<bool> canDelete(DocumentModel item) async => item.isDraft;

  @override
  Future<void> deleteItem(DocumentModel item) async {
    final repo = DocumentRepository();
    await repo.delete(item.id);
    await repo.addEditLog(item.id, '削除',
      details: '${item.documentType.label} #${item.documentNumber} ${item.customerName}\n${item.items.length}明細');
  }
}

class _ProjectBadge extends StatelessWidget {
  final String projectId;
  const _ProjectBadge({required this.projectId});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ProjectDetailScreen(projectId: projectId),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(left: 4),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        decoration: BoxDecoration(
          color: cs.primaryContainer.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.workspaces, size: 12, color: cs.onPrimaryContainer),
            const SizedBox(width: 3),
            Text('案件', style: TextStyle(fontSize: 10, color: cs.onPrimaryContainer, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}
