import 'package:flutter/material.dart';

class ImportColumn {
  final String? title;
  final String? key;
  final String? label;
  final List<String>? matchKeywords;
  final bool required;

  const ImportColumn({
    this.title,
    this.key,
    this.label,
    this.matchKeywords,
    this.required = false,
  });
}

class GenericCsvImportScreen<T> extends StatefulWidget {
  final String screenId;
  final String entityName;
  final List<ImportColumn> columns;
  final Future<void> Function(T entry) onImport;
  final T Function(List<String> row, List<int> colMap, String id) parser;
  final String Function(T entry) previewText1;
  final String Function(T entry) previewText2;
  final String Function(T entry)? previewText3;

  const GenericCsvImportScreen({
    super.key,
    required this.screenId,
    required this.entityName,
    required this.columns,
    required this.onImport,
    required this.parser,
    required this.previewText1,
    required this.previewText2,
    this.previewText3,
  });

  @override
  State<GenericCsvImportScreen<T>> createState() => _GenericCsvImportScreenState<T>();
}

class _GenericCsvImportScreenState<T> extends State<GenericCsvImportScreen<T>> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.screenId}:${widget.entityName}インポート'),
      ),
      body: const Center(
        child: Text('CSVインポート'),
      ),
    );
  }
}
