import 'package:flutter/material.dart';
import '../../../models/project_model.dart';
import '../../explorer/h1_explorer_item.dart';

class ProjectExplorerItem extends H1ExplorerItem {
  final Project project;

  ProjectExplorerItem(this.project);

  @override
  String get id => project.id;

  @override
  String get title => project.name;

  @override
  String? get subtitle {
    final parts = <String>[];
    if (project.customerName != null && project.customerName!.isNotEmpty) {
      parts.add(project.customerName!);
    }
    parts.add('￥${_fmt(project.totalAmount)}');
    return parts.join('  ');
  }

  @override
  String? get badge {
    if (project.status == ProjectStatus.lost) return '失注';
    if (project.status == ProjectStatus.won) return '成約';
    return project.pipelineStage;
  }

  @override
  IconData? get icon {
    switch (project.status) {
      case ProjectStatus.lost: return Icons.cancel_outlined;
      case ProjectStatus.won: return Icons.check_circle;
      default: return Icons.workspaces;
    }
  }

  @override
  DateTime? get updatedAt => project.createdAt;

  @override
  bool get canEdit => true;

  static String _fmt(int n) =>
    n.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
}
