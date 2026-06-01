import 'package:flutter/material.dart';
import '../../plugins/explorer/h1_explorer.dart';
import '../../plugins/documents/explorer/document_explorer_config.dart';
import '../../widgets/screen_id_title.dart';

class InvoiceHistoryScreen extends StatelessWidget {
  final bool isPickerMode;
  const InvoiceHistoryScreen({super.key, this.isPickerMode = false});

  @override
  Widget build(BuildContext context) {
    return H1Explorer(
      config: DocumentExplorerConfig(),
      appBarTitle: const ScreenAppBarTitle(
        screenId: 'IH',
        title: '伝票履歴',
      ),
    );
  }
}
