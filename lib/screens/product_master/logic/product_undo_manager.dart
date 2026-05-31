import 'package:flutter/material.dart';
import '../../../services/database_helper.dart';
import '../../../services/activity_log_repository.dart';
import '../models/product_list_types.dart';

void pushUndo({
  required List<BatchUndoEntry> undoStack,
  required List<BatchUndoEntry> redoStack,
  required BatchUndoEntry entry,
}) {
  undoStack.add(entry);
  redoStack.clear();
  if (undoStack.length > 20) undoStack.removeAt(0);
}

void showUndoSnackbar({
  required BuildContext context,
  required String message,
  required BatchUndoEntry entry,
  required bool mounted,
  required VoidCallback onUndo,
}) {
  if (!mounted) return;
  ScaffoldMessenger.of(context)
    ..clearSnackBars()
    ..showSnackBar(SnackBar(
      content: Text(message),
      duration: const Duration(seconds: 6),
      action: SnackBarAction(
        label: '元に戻す',
        onPressed: () {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          onUndo();
        },
      ),
    ));
}

Future<void> performUndo(
  BatchUndoEntry entry,
  ActivityLogRepository logRepo,
  VoidCallback onComplete,
) async {
  final db = await DatabaseHelper().database;
  for (final snapshot in entry.snapshots) {
    try {
      if (entry.type == 'delete' && snapshot.before != null) {
        final map = snapshot.before!.toMap();
        map['is_current'] = 1;
        map['previous_hash'] = '';
        map['content_hash'] = '';
        await db.insert('products', map);
      } else if (entry.type == 'move' && snapshot.before != null) {
        await db.update(
          'products',
          {'category': snapshot.before!.category, 'category_id': snapshot.before!.categoryId},
          where: 'id = ? AND is_current = 1',
          whereArgs: [snapshot.before!.id],
        );
      }
    } catch (e) {
      debugPrint('[P1] undo error: $e');
    }
  }
  logRepo.logAction(
    action: 'undo_${entry.type}',
    targetType: 'product',
    details: '${entry.snapshots.length}件の${entry.type == 'delete' ? '削除' : '移動'}を取り消し',
    screenId: 'P1',
  );
  onComplete();
}

Future<void> performRedo(
  BatchUndoEntry entry,
  VoidCallback onComplete,
) async {
  final db = await DatabaseHelper().database;
  for (final snapshot in entry.snapshots) {
    try {
      if (entry.type == 'delete' && snapshot.before != null) {
        await db.delete(
          'products',
          where: 'id = ? AND is_current = 1',
          whereArgs: [snapshot.before!.id],
        );
      } else if (entry.type == 'move' && snapshot.after != null) {
        await db.update(
          'products',
          {'category': snapshot.after!.category, 'category_id': snapshot.after!.categoryId},
          where: 'id = ? AND is_current = 1',
          whereArgs: [snapshot.after!.id],
        );
      }
    } catch (e) {
      debugPrint('[P1] redo error: $e');
    }
  }
  onComplete();
}
