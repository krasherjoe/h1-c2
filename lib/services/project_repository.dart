import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'database_helper.dart';
import '../models/project_model.dart';
import '../models/billing_template_model.dart';
import 'billing_template_repository.dart';

class ProjectRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final _templateRepo = BillingTemplateRepository();

  Future<Database> get _db => _dbHelper.database;

  Future<List<Project>> getAll() async {
    final db = await _db;
    final maps = await db.query('projects', orderBy: 'sort_order ASC, updated_at DESC');
    return maps.map(Project.fromMap).toList();
  }

  Future<void> updateOrder(String id, int order) async {
    final db = await _db;
    await db.update('projects', {
      'sort_order': order,
      'updated_at': DateTime.now().toIso8601String(),
    }, where: 'id = ?', whereArgs: [id]);
  }

  Future<Project?> getById(String id) async {
    final db = await _db;
    final maps = await db.query('projects',
      where: 'id = ?', whereArgs: [id], limit: 1);
    if (maps.isEmpty) return null;
    return Project.fromMap(maps.first);
  }

  Future<List<Project>> getByCustomer(String customerId) async {
    final db = await _db;
    final maps = await db.query('projects',
      where: 'customer_id = ?', whereArgs: [customerId],
      orderBy: 'updated_at DESC');
    return maps.map(Project.fromMap).toList();
  }

  Future<void> save(Project project) async {
    final db = await _db;
    await db.insert('projects', project.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<String> createProject({
    required String name,
    required String customerId,
    required String customerName,
    String? type,
    int? contractMonths,
  }) async {
    final db = await _db;
    final id = const Uuid().v4();
    final now = DateTime.now();
    final maxOrder = await db.rawQuery('SELECT COALESCE(MAX(sort_order), -1) + 1 AS n FROM projects');
    final nextOrder = (maxOrder.first['n'] as num?)?.toInt() ?? 0;
    await db.insert('projects', {
      'id': id,
      'name': name,
      'customer_id': customerId,
      'customer_name': customerName,
      'status': 'active',
      'type': type ?? 'sales',
      'pipeline_stage': '見積',
      'progress': 0,
      'current_stage_index': 0,
      'total_amount': 0,
      'contract_months': contractMonths,
      'sort_order': nextOrder,
      'created_at': now.toIso8601String(),
      'updated_at': now.toIso8601String(),
    });
    return id;
  }

  Future<void> delete(String id) async {
    final db = await _db;
    await db.update('documents', {'project_id': null},
      where: 'project_id = ?', whereArgs: [id]);
    await db.delete('projects', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> linkDocument({
    required String projectId,
    required String documentType,
    required String documentId,
  }) async {
    final db = await _db;
    await db.update('documents', {'project_id': projectId},
      where: 'id = ?', whereArgs: [documentId]);
    await _advanceStage(projectId, documentType);
    await _recalcTotal(projectId);
  }

  Future<void> unlinkDocument(String documentId) async {
    final db = await _db;
    await db.update('documents', {'project_id': null},
      where: 'id = ?', whereArgs: [documentId]);
  }

  Future<void> updateStage(String projectId, String stage) async {
    final db = await _db;
    await db.update('projects', {
      'pipeline_stage': stage,
      'updated_at': DateTime.now().toIso8601String(),
    }, where: 'id = ?', whereArgs: [projectId]);
  }

  Future<void> _advanceStage(String projectId, String documentType) async {
    const stageMap = {
      'estimation': '見積',
      'order': '受注',
      'delivery': '納品',
      'invoice': '請求',
      'receipt': '入金済',
    };
    final targetStage = stageMap[documentType];
    if (targetStage == null) return;
    final project = await getById(projectId);
    if (project == null) return;
    final stages = _allStages;
    final currentIdx = stages.indexOf(project.pipelineStage);
    final targetIdx = stages.indexOf(targetStage);
    if (targetIdx > currentIdx) {
      await updateStage(projectId, targetStage);
    }
  }

  static const _allStages = ['見積', '受注', '発注', '納品', '請求', '入金済'];

  Future<void> _recalcTotal(String projectId) async {
    final db = await _db;
    final result = await db.rawQuery(
      'SELECT COALESCE(SUM(total), 0) as total FROM documents WHERE project_id = ? AND status = ?',
      [projectId, 'confirmed']);
    final total = (result.isNotEmpty ? result.first['total'] as num? : 0) ?? 0;
    await db.update('projects', {
      'total_amount': total.toInt(),
      'updated_at': DateTime.now().toIso8601String(),
    }, where: 'id = ?', whereArgs: [projectId]);
  }

  Future<List<Map<String, dynamic>>> getLinkedDocuments(String projectId) async {
    final db = await _db;
    return db.query('documents',
      where: 'project_id = ?', whereArgs: [projectId],
      orderBy: 'date DESC');
  }

  // ワークフロー操作メソッド

  /// ワークフロー開始
  Future<void> startWorkflow(String projectId) async {
    try {
      final project = await getById(projectId);
      if (project == null) {
        debugPrint('[ProjectRepo] Project not found: $projectId');
        return;
      }

      // テンプレート確認
      if (project.billingTemplateId == null) {
        debugPrint('[ProjectRepo] No billing template for project: $projectId');
        return;
      }

      final template = await _templateRepo.getTemplateById(project.billingTemplateId!);
      if (template == null) {
        debugPrint('[ProjectRepo] Template not found: ${project.billingTemplateId}');
        return;
      }

      // ワークフロー開始
      final now = DateTime.now();
      final firstStep = template.workflowSteps.isNotEmpty 
          ? template.workflowSteps.first.name 
          : null;

      await _updateWorkflow(projectId, {
        'current_workflow_step': firstStep,
        'workflow_started_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      });

      debugPrint('[ProjectRepo] Workflow started for project: $projectId, step: $firstStep');
    } catch (e) {
      debugPrint('[ProjectRepo] startWorkflow error: $e');
      rethrow;
    }
  }

  /// ワークフロー進捗更新
  Future<void> updateWorkflowProgress(String projectId, WorkflowStep step) async {
    try {
      await _updateWorkflow(projectId, {
        'current_workflow_step': step.name,
        'updated_at': DateTime.now().toIso8601String(),
      });
      debugPrint('[ProjectRepo] Workflow progress updated: $projectId -> ${step.name}');
    } catch (e) {
      debugPrint('[ProjectRepo] updateWorkflowProgress error: $e');
      rethrow;
    }
  }

  /// ワークフロー完了
  Future<void> completeWorkflow(String projectId) async {
    try {
      await _updateWorkflow(projectId, {
        'current_workflow_step': null,
        'workflow_completed_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });
      debugPrint('[ProjectRepo] Workflow completed: $projectId');
    } catch (e) {
      debugPrint('[ProjectRepo] completeWorkflow error: $e');
      rethrow;
    }
  }

  /// ワークフロー状態リセット
  Future<void> resetWorkflow(String projectId) async {
    try {
      await _updateWorkflow(projectId, {
        'current_workflow_step': null,
        'workflow_started_at': null,
        'workflow_completed_at': null,
        'updated_at': DateTime.now().toIso8601String(),
      });
      debugPrint('[ProjectRepo] Workflow reset: $projectId');
    } catch (e) {
      debugPrint('[ProjectRepo] resetWorkflow error: $e');
      rethrow;
    }
  }

  /// ワークフロー関連フィールド更新（共通）
  Future<void> _updateWorkflow(String projectId, Map<String, dynamic> updates) async {
    final db = await _db;
    await db.update('projects', updates, where: 'id = ?', whereArgs: [projectId]);
  }

  /// 案件の現在のワークフローステップを取得
  Future<WorkflowStep?> getCurrentWorkflowStep(String projectId) async {
    try {
      final project = await getById(projectId);
      if (project?.currentWorkflowStep == null) return null;

      return WorkflowStep.values.firstWhere(
        (e) => e.name == project!.currentWorkflowStep,
        orElse: () => WorkflowStep.delivery,
      );
    } catch (e) {
      debugPrint('[ProjectRepo] getCurrentWorkflowStep error: $e');
      return null;
    }
  }
}
