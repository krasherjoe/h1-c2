import 'package:flutter/material.dart';
import '../../../plugins/explorer/h1_explorer_config.dart';
import '../models/document_model.dart';
import '../services/document_repository.dart';
import 'document_viewer.dart';
import 'document_editor.dart';

class DocumentExplorerConfig extends H1ExplorerConfig<DocumentModel> {
  final DocumentType? filterType;

  DocumentExplorerConfig({this.filterType});

  @override
  String get explorerTitle => filterType?.label ?? '伝票管理';

  @override
  String get searchHint => '伝票番号・顧客名で検索';

  @override
  IconData get itemIcon => Icons.description;

  @override
  String get emptyMessage => '伝票がありません';

  @override
  Future<List<DocumentModel>> fetchItems(String query) async {
    final repo = DocumentRepository();
    return repo.fetchAll(filterType: filterType, query: query);
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
