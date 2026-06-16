class CaseModel {
  final String id;
  final String type;
  final int status;
  final int priority;
  final String referenceType;
  final String referenceId;
  final String title;
  final int? amount;
  final String description;
  final String? assignee;
  final DateTime? dueDate;
  final DateTime createdAt;
  final DateTime? escalatedAt;
  final DateTime? resolvedAt;
  final String? notes;

  const CaseModel({
    required this.id,
    required this.type,
    this.status = 0,
    this.priority = 0,
    this.referenceType = '',
    this.referenceId = '',
    required this.title,
    this.amount,
    this.description = '',
    this.assignee,
    this.dueDate,
    required this.createdAt,
    this.escalatedAt,
    this.resolvedAt,
    this.notes,
  });

  bool get isResolved => status >= 99;

  String get statusLabel {
    if (status >= 99) return '解決';
    return switch (status) { 0 => '発見', 1 => '注意', 2 => '警告', 3 => '重大', _ => '不明' };
  }

  String get typeLabel => switch (type) {
    'overdue' => '滞留', 'damage' => '破損', 'theft' => '盗難', 'loss' => '紛失',
    'bug' => 'バグ', 'feature' => '機能', 'task' => 'タスク',
    'web' => 'Web制作', 'illust' => 'イラスト制作',
    _ => type,
  };

  int get elapsedDays => DateTime.now().difference(createdAt).inDays;

  Map<String, dynamic> toMap() => {
    'id': id, 'type': type, 'status': status, 'priority': priority,
    'reference_type': referenceType, 'reference_id': referenceId,
    'title': title, 'amount': amount, 'description': description,
    'assignee': assignee, 'due_date': dueDate?.toIso8601String(),
    'created_at': createdAt.toIso8601String(),
    'escalated_at': escalatedAt?.toIso8601String(),
    'resolved_at': resolvedAt?.toIso8601String(),
    'notes': notes,
  };

  factory CaseModel.fromMap(Map<String, dynamic> m) => CaseModel(
    id: m['id'] as String? ?? '',
    type: m['type'] as String? ?? '',
    status: m['status'] as int? ?? 0,
    priority: m['priority'] as int? ?? 0,
    referenceType: m['reference_type'] as String? ?? '',
    referenceId: m['reference_id'] as String? ?? '',
    title: m['title'] as String? ?? '',
    amount: m['amount'] as int?,
    description: m['description'] as String? ?? '',
    assignee: m['assignee'] as String?,
    dueDate: m['due_date'] != null ? DateTime.tryParse(m['due_date'] as String) : null,
    createdAt: DateTime.tryParse(m['created_at'] as String? ?? '') ?? DateTime.now(),
    escalatedAt: m['escalated_at'] != null ? DateTime.tryParse(m['escalated_at'] as String) : null,
    resolvedAt: m['resolved_at'] != null ? DateTime.tryParse(m['resolved_at'] as String) : null,
    notes: m['notes'] as String?,
  );

  CaseModel copyWith({int? status, DateTime? escalatedAt, DateTime? resolvedAt, String? notes, String? title, String? description, String? assignee, DateTime? dueDate}) => CaseModel(
    id: id, type: type, status: status ?? this.status, priority: priority,
    referenceType: referenceType, referenceId: referenceId,
    title: title ?? this.title, amount: amount, description: description ?? this.description,
    assignee: assignee ?? this.assignee, dueDate: dueDate ?? this.dueDate,
    createdAt: createdAt, escalatedAt: escalatedAt ?? this.escalatedAt,
    resolvedAt: resolvedAt ?? this.resolvedAt, notes: notes ?? this.notes,
  );
}
