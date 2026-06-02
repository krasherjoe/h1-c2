import 'package:flutter/material.dart';
import '../../../plugins/explorer/h1_explorer_config.dart';
import '../models/document_model.dart';
import '../services/document_repository.dart';
import 'document_viewer.dart';
import 'document_editor.dart';

class DocumentExplorerConfig extends H1ExplorerConfig<DocumentModel> {
  DocumentExplorerConfig();

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
  Widget buildViewer(BuildContext context, DocumentModel item) {
    return DocumentViewer(document: item);
  }

  @override
  Widget buildEditor(BuildContext context, DocumentModel? item) {
    return DocumentEditor(document: item);
  }

  @override
  Future<bool> canDelete(DocumentModel item) async => item.isDraft;

  @override
  Future<void> deleteItem(DocumentModel item) async {
    final repo = DocumentRepository();
    await repo.delete(item.id);
  }
}
