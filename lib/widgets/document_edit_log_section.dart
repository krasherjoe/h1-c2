import 'package:flutter/material.dart';
import '../plugins/documents/models/document_edit_log.dart';

class DocumentEditLogSection extends StatelessWidget {
  final List<DocumentEditLog> editLogs;
  final ColorScheme colorScheme;

  const DocumentEditLogSection({
    super.key,
    required this.editLogs,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    final cs = colorScheme;
    if (editLogs.isEmpty) return const SizedBox.shrink();
    return Container(
      color: cs.surface,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('📝 編集履歴(2週間保持しています)',
            style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant)),
          const SizedBox(height: 4),
          ...(editLogs.take(5)).map((log) => Container(
            margin: const EdgeInsets.only(bottom: 2),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: cs.surfaceContainerLow,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text('${log.createdAt.month}/${log.createdAt.day} ${log.createdAt.hour.toString().padLeft(2, '0')}:${log.createdAt.minute.toString().padLeft(2, '0')}',
                  style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant)),
                const SizedBox(width: 8),
                Text(log.action,
                  style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant)),
              ]),
              if (log.details.isNotEmpty)
                Text(log.details,
                  style: TextStyle(fontSize: 9, color: cs.onSurfaceVariant.withValues(alpha: 0.7)),
                  maxLines: 2, overflow: TextOverflow.ellipsis),
            ]),
          )),
        ],
      ),
    );
  }
}
