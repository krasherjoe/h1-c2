enum Priority { low, medium, high }

enum TaskStatus { todo, doing, done }

enum TodoStatus { pending, done }

class DailyReport {
  final String id;
  final String date;
  final String doneText;
  final String planText;
  final String? issueText;
  final String? tags;
  final String? projectId;
  final String createdAt;
  final String updatedAt;

  DailyReport({
    required this.id,
    required this.date,
    required this.doneText,
    required this.planText,
    this.issueText,
    this.tags,
    this.projectId,
    required this.createdAt,
    required this.updatedAt,
  });

  List<String> get tagList =>
      tags != null && tags!.isNotEmpty
          ? tags!.split(',').map((t) => t.trim()).where((t) => t.isNotEmpty).toList()
          : [];

  Map<String, dynamic> toMap() => {
        'id': id,
        'report_date': date,
        'done_text': doneText,
        'plan_text': planText,
        'issue_text': issueText,
        'tags': tags,
        'project_id': projectId,
        'created_at': createdAt,
        'updated_at': updatedAt,
      };

  factory DailyReport.fromMap(Map<String, dynamic> map) => DailyReport(
        id: map['id'] as String? ?? '',
        date: map['report_date'] as String? ?? '',
        doneText: map['done_text'] as String? ?? '',
        planText: map['plan_text'] as String? ?? '',
        issueText: map['issue_text'] as String?,
        tags: map['tags'] as String?,
        projectId: map['project_id'] as String?,
        createdAt: map['created_at'] as String? ?? '',
        updatedAt: map['updated_at'] as String? ?? '',
      );

  DailyReport copyWith({
    String? doneText,
    String? planText,
    String? issueText,
    String? tags,
    String? projectId,
  }) =>
      DailyReport(
        id: id,
        date: date,
        doneText: doneText ?? this.doneText,
        planText: planText ?? this.planText,
        issueText: issueText ?? this.issueText,
        tags: tags ?? this.tags,
        projectId: projectId ?? this.projectId,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );
}

class TimeLog {
  final String id;
  final String taskId;
  final String projectId;
  final DateTime date;
  final double hours;
  final String? memo;
  final DateTime createdAt;

  const TimeLog({
    required this.id,
    required this.taskId,
    required this.projectId,
    required this.date,
    required this.hours,
    this.memo,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'task_id': taskId,
        'project_id': projectId,
        'date': date.toIso8601String(),
        'hours': hours,
        'memo': memo,
        'created_at': createdAt.toIso8601String(),
      };

  factory TimeLog.fromMap(Map<String, dynamic> map) => TimeLog(
        id: map['id'] as String? ?? '',
        taskId: map['task_id'] as String? ?? '',
        projectId: map['project_id'] as String? ?? '',
        date: DateTime.parse(map['date'] as String? ?? ''),
        hours: (map['hours'] as num?)?.toDouble() ?? 0,
        memo: map['memo'] as String?,
        createdAt: DateTime.parse(map['created_at'] as String? ?? ''),
      );

  TimeLog copyWith({
    DateTime? date,
    double? hours,
    String? memo,
  }) =>
      TimeLog(
        id: id,
        taskId: taskId,
        projectId: projectId,
        date: date ?? this.date,
        hours: hours ?? this.hours,
        memo: memo ?? this.memo,
        createdAt: createdAt,
      );
}

class TodoTask {
  final String id;
  final String title;
  final Priority priority;
  final TodoStatus status;
  final String? category;
  final String? referenceId;
  final String? referenceType;
  final DateTime? dueDate;
  final DateTime createdAt;

  const TodoTask({
    required this.id,
    required this.title,
    this.priority = Priority.medium,
    this.status = TodoStatus.pending,
    this.category,
    this.referenceId,
    this.referenceType,
    this.dueDate,
    required this.createdAt,
  });

  bool get isDone => status == TodoStatus.done;
  bool get isOverdue => dueDate != null && dueDate!.isBefore(DateTime.now()) && !isDone;

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'priority': priority.name,
        'status': status.name,
        'category': category,
        'reference_id': referenceId,
        'reference_type': referenceType,
        'due_date': dueDate?.toIso8601String(),
        'created_at': createdAt.toIso8601String(),
      };

  factory TodoTask.fromMap(Map<String, dynamic> map) => TodoTask(
        id: map['id'] as String? ?? '',
        title: map['title'] as String? ?? '',
        priority: Priority.values.firstWhere(
          (e) => e.name == map['priority'],
          orElse: () => Priority.medium,
        ),
        status: TodoStatus.values.firstWhere(
          (e) => e.name == map['status'],
          orElse: () => TodoStatus.pending,
        ),
        category: map['category'] as String?,
        referenceId: map['reference_id'] as String?,
        referenceType: map['reference_type'] as String?,
        dueDate: map['due_date'] != null ? DateTime.tryParse(map['due_date'] as String? ?? '') : null,
        createdAt: DateTime.parse(map['created_at'] as String? ?? ''),
      );

  TodoTask copyWith({
    String? title,
    Priority? priority,
    TodoStatus? status,
    String? category,
    String? referenceId,
    String? referenceType,
    DateTime? dueDate,
  }) =>
      TodoTask(
        id: id,
        title: title ?? this.title,
        priority: priority ?? this.priority,
        status: status ?? this.status,
        category: category ?? this.category,
        referenceId: referenceId ?? this.referenceId,
        referenceType: referenceType ?? this.referenceType,
        dueDate: dueDate ?? this.dueDate,
        createdAt: createdAt,
      );
}

class Task {
  final String id;
  final String projectId;
  final String? milestoneId;
  final String title;
  final TaskStatus status;
  final double estimatedHours;
  final DateTime? dueDate;
  final int sortOrder;
  final DateTime createdAt;

  const Task({
    required this.id,
    required this.projectId,
    this.milestoneId,
    required this.title,
    this.status = TaskStatus.todo,
    this.estimatedHours = 0,
    this.dueDate,
    this.sortOrder = 0,
    required this.createdAt,
  });

  bool get isDone => status == TaskStatus.done;

  Map<String, dynamic> toMap() => {
        'id': id,
        'project_id': projectId,
        'milestone_id': milestoneId,
        'title': title,
        'status': status.name,
        'estimated_hours': estimatedHours,
        'due_date': dueDate?.toIso8601String(),
        'sort_order': sortOrder,
        'created_at': createdAt.toIso8601String(),
      };

  factory Task.fromMap(Map<String, dynamic> map) {
    final rawStatus = map['status'] as String?;
    final status = rawStatus != null
        ? TaskStatus.values.firstWhere(
            (e) => e.name == rawStatus,
            orElse: () => TaskStatus.todo,
          )
        : TaskStatus.todo;
    return Task(
      id: map['id'] as String? ?? '',
      projectId: map['project_id'] as String? ?? '',
      milestoneId: map['milestone_id'] as String?,
      title: map['title'] as String? ?? '',
      status: status,
      estimatedHours: (map['estimated_hours'] as num?)?.toDouble() ?? 0,
      dueDate: map['due_date'] != null ? DateTime.tryParse(map['due_date'] as String? ?? '') : null,
      sortOrder: (map['sort_order'] as int?) ?? 0,
      createdAt: DateTime.parse(map['created_at'] as String? ?? ''),
    );
  }

  Task copyWith({
    String? title,
    TaskStatus? status,
    double? estimatedHours,
    DateTime? dueDate,
    String? milestoneId,
    int? sortOrder,
  }) =>
      Task(
        id: id,
        projectId: projectId,
        milestoneId: milestoneId ?? this.milestoneId,
        title: title ?? this.title,
        status: status ?? this.status,
        estimatedHours: estimatedHours ?? this.estimatedHours,
        dueDate: dueDate ?? this.dueDate,
        sortOrder: sortOrder ?? this.sortOrder,
        createdAt: createdAt,
      );
}
