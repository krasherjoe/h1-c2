import 'package:flutter/material.dart';
import '../../../models/project_model.dart';
import '../../../services/project_repository.dart';

Future<Project?> showQuickProjectCreateDialog(
  BuildContext context, {
  required String customerId,
  required String customerName,
  required String initialSubject,
  required ProjectRepository projectRepo,
}) async {
  final controller = TextEditingController(text: initialSubject.isNotEmpty ? initialSubject : '');
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('新規案件を作成'),
      content: TextField(
        controller: controller,
        decoration: const InputDecoration(
          labelText: '案件名',
          hintText: '例：サーバー導入プロジェクト',
        ),
        autofocus: true,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('キャンセル'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('作成'),
        ),
      ],
    ),
  );
  if (confirmed == true && controller.text.trim().isNotEmpty) {
    final newProject = await projectRepo.createProject(
      name: controller.text.trim(),
      customerId: customerId,
      customerName: customerName,
      status: ProjectStatus.active,
      startDate: DateTime.now(),
    );
    return newProject;
  }
  return null;
}
