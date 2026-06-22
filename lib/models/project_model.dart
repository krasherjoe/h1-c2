/// 案件種別
enum ProjectType {
  sales,
  development,
  other,
  collection,
}

extension ProjectTypeX on ProjectType {
  String get displayName {
    switch (this) {
      case ProjectType.sales:
        return '販売';
      case ProjectType.development:
        return '開発';
      case ProjectType.other:
        return 'その他';
      case ProjectType.collection:
        return '回収';
    }
  }

  static ProjectType fromString(String value) {
    switch (value) {
      case 'sales':
        return ProjectType.sales;
      case 'development':
        return ProjectType.development;
      case 'other':
        return ProjectType.other;
      case 'collection':
        return ProjectType.collection;
      default:
        return ProjectType.other;
    }
  }
}

/// 案件ステータス
enum ProjectStatus {
  active,
  won,
  lost,
  suspended,
}

extension ProjectStatusX on ProjectStatus {
  String get displayName {
    switch (this) {
      case ProjectStatus.active:
        return '進行中';
      case ProjectStatus.won:
        return '成約';
      case ProjectStatus.lost:
        return '失注';
      case ProjectStatus.suspended:
        return '保留';
    }
  }

  static ProjectStatus fromString(String value) {
    switch (value) {
      case 'active':
        return ProjectStatus.active;
      case 'won':
        return ProjectStatus.won;
      case 'lost':
        return ProjectStatus.lost;
      case 'suspended':
        return ProjectStatus.suspended;
      default:
        return ProjectStatus.active;
    }
  }
}

/// 案件モデル
class Project {
  final String id;
  final String name;
  final String? customerId;
  final String? customerName;
  final ProjectStatus status;
  final DateTime? startDate;
  final DateTime? endDate;
  final int? contractMonths;
  final String? notes;
  final int totalAmount;
  final DateTime createdAt;
  final DateTime updatedAt;
  final ProjectType type;
  final String pipelineStage;
  final int progress;
  final String? schemeId;
  final int currentStageIndex;
  final int sortOrder;
  final String? ganttConfig;
  final String? billingTemplateId; // 請求テンプレートID
  
  // ワークフロー進捗
  final String? currentWorkflowStep; // 現在のステップ名
  final DateTime? workflowStartedAt; // ワークフロー開始日時
  final DateTime? workflowCompletedAt; // ワークフロー完了日時

  const Project({
    required this.id,
    required this.name,
    this.customerId,
    this.customerName,
    this.status = ProjectStatus.active,
    this.startDate,
    this.endDate,
    this.contractMonths,
    this.notes,
    this.totalAmount = 0,
    required this.createdAt,
    required this.updatedAt,
    this.type = ProjectType.sales,
    this.pipelineStage = '見積',
    this.progress = 0,
    this.schemeId,
    this.currentStageIndex = 0,
    this.sortOrder = 0,
    this.ganttConfig,
    this.billingTemplateId,
    this.currentWorkflowStep,
    this.workflowStartedAt,
    this.workflowCompletedAt,
  });

  int get elapsedMonths {
    if (startDate == null) return 0;
    final now = DateTime.now();
    return (now.year - startDate!.year) * 12 + now.month - startDate!.month;
  }

  double get timeProgress {
    if (startDate == null || contractMonths == null || contractMonths! <= 0) return 0;
    return (elapsedMonths / contractMonths!).clamp(0.0, 1.0);
  }

  bool get isOverdue => endDate != null && DateTime.now().isAfter(endDate!);

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'customer_id': customerId,
        'customer_name': customerName,
        'status': status.name,
        'start_date': startDate?.toIso8601String(),
        'end_date': endDate?.toIso8601String(),
        'contract_months': contractMonths,
        'notes': notes,
        'total_amount': totalAmount,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
        'type': type.name,
        'pipeline_stage': pipelineStage,
        'progress': progress,
        'scheme_id': schemeId,
        'current_stage_index': currentStageIndex,
        'sort_order': sortOrder,
        'gantt_config': ganttConfig,
        'billing_template_id': billingTemplateId,
        'current_workflow_step': currentWorkflowStep,
        'workflow_started_at': workflowStartedAt?.toIso8601String(),
        'workflow_completed_at': workflowCompletedAt?.toIso8601String(),
      };

  factory Project.fromMap(Map<String, dynamic> map) {
    ProjectStatus status = ProjectStatus.active;
    final statusRaw = map['status'] as String?;
    if (statusRaw != null) {
      try {
        status = ProjectStatus.values.firstWhere((e) => e.name == statusRaw);
      } catch (_) {}
    }

    return Project(
      id: map['id'] as String? ?? '',
      name: map['name'] as String? ?? '',
      customerId: map['customer_id'] as String?,
      customerName: map['customer_name'] as String?,
      status: status,
      startDate: _parseProjectDate(map['start_date']),
      endDate: _parseProjectDate(map['end_date']),
      contractMonths: map['contract_months'] as int?,
      notes: map['notes'] as String?,
      totalAmount: map['total_amount'] as int? ?? 0,
      createdAt: DateTime.parse(map['created_at'] as String? ?? ''),
      updatedAt: DateTime.parse(map['updated_at'] as String? ?? ''),
      type: ProjectType.values.firstWhere(
        (e) => e.name == (map['type'] as String? ?? 'sales'),
        orElse: () => ProjectType.sales,
      ),
      pipelineStage: map['pipeline_stage'] as String? ?? '見積',
      progress: (map['progress'] as int?) ?? 0,
      schemeId: map['scheme_id'] as String?,
      currentStageIndex: (map['current_stage_index'] as int?) ?? 0,
      sortOrder: (map['sort_order'] as int?) ?? 0,
      ganttConfig: map['gantt_config'] as String?,
      billingTemplateId: map['billing_template_id'] as String?,
      currentWorkflowStep: map['current_workflow_step'] as String?,
      workflowStartedAt: map['workflow_started_at'] != null
          ? DateTime.tryParse(map['workflow_started_at'] as String)
          : null,
      workflowCompletedAt: map['workflow_completed_at'] != null
          ? DateTime.tryParse(map['workflow_completed_at'] as String)
          : null,
    );
  }

  Project copyWith({
    String? id,
    String? name,
    String? customerId,
    String? customerName,
    ProjectStatus? status,
    DateTime? startDate,
    DateTime? endDate,
    int? contractMonths,
    String? notes,
    int? totalAmount,
    DateTime? createdAt,
    DateTime? updatedAt,
    ProjectType? type,
    String? pipelineStage,
    int? progress,
    String? schemeId,
    int? currentStageIndex,
    int? sortOrder,
    String? ganttConfig,
    String? billingTemplateId,
    String? currentWorkflowStep,
    DateTime? workflowStartedAt,
    DateTime? workflowCompletedAt,
  }) {
    return Project(
      id: id ?? this.id,
      name: name ?? this.name,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      status: status ?? this.status,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      contractMonths: contractMonths ?? this.contractMonths,
      notes: notes ?? this.notes,
      totalAmount: totalAmount ?? this.totalAmount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      type: type ?? this.type,
      pipelineStage: pipelineStage ?? this.pipelineStage,
      progress: progress ?? this.progress,
      schemeId: schemeId ?? this.schemeId,
      currentStageIndex: currentStageIndex ?? this.currentStageIndex,
      sortOrder: sortOrder ?? this.sortOrder,
      ganttConfig: ganttConfig ?? this.ganttConfig,
      billingTemplateId: billingTemplateId ?? this.billingTemplateId,
      currentWorkflowStep: currentWorkflowStep ?? this.currentWorkflowStep,
      workflowStartedAt: workflowStartedAt ?? this.workflowStartedAt,
      workflowCompletedAt: workflowCompletedAt ?? this.workflowCompletedAt,
    );
  }
}

DateTime? _parseProjectDate(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  final s = value as String;
  if (s.isEmpty) return null;
  // ISO 8601 format stored by toMap()
  try {
    return DateTime.parse(s);
  } catch (_) {}
  // YYYY/MM/DD format from UI
  final parts = s.split('/');
  if (parts.length == 3) {
    final y = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    final d = int.tryParse(parts[2]);
    if (y != null && m != null && d != null) return DateTime(y, m, d);
  }
  return null;
}

/// マイルストーンモデル
class Milestone {
  final String id;
  final String projectId;
  final String name;
  final DateTime? dueDate;
  final bool isCompleted;
  final int displayOrder;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Milestone({
    required this.id,
    required this.projectId,
    required this.name,
    this.dueDate,
    this.isCompleted = false,
    this.displayOrder = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'project_id': projectId,
        'name': name,
        'due_date': dueDate?.toIso8601String(),
        'is_completed': isCompleted ? 1 : 0,
        'display_order': displayOrder,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  factory Milestone.fromMap(Map<String, dynamic> map) {
    return Milestone(
      id: map['id'] as String? ?? '',
      projectId: map['project_id'] as String? ?? '',
      name: map['name'] as String? ?? '',
      dueDate: map['due_date'] != null
          ? DateTime.tryParse(map['due_date'] as String? ?? '')
          : null,
      isCompleted: (map['is_completed'] as int?) == 1,
      displayOrder: (map['display_order'] as int?) ?? 0,
      createdAt: DateTime.parse(map['created_at'] as String? ?? ''),
      updatedAt: DateTime.parse(map['updated_at'] as String? ?? ''),
    );
  }

  Milestone copyWith({
    String? name,
    DateTime? dueDate,
    bool? isCompleted,
    int? displayOrder,
    DateTime? updatedAt,
  }) {
    return Milestone(
      id: id,
      projectId: projectId,
      name: name ?? this.name,
      dueDate: dueDate ?? this.dueDate,
      isCompleted: isCompleted ?? this.isCompleted,
      displayOrder: displayOrder ?? this.displayOrder,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }
}
