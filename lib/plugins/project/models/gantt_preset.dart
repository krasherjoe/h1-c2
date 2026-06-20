import '../../documents/models/document_model.dart';

/// ガントチャートタスク
class GanttTask {
  final String id;
  final String label;
  final DocumentType? documentType;
  final bool isCustom;

  const GanttTask({
    required this.id,
    required this.label,
    this.documentType,
    this.isCustom = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'documentType': documentType?.name,
        'isCustom': isCustom,
      };

  factory GanttTask.fromJson(Map<String, dynamic> json) => GanttTask(
        id: json['id'] as String,
        label: json['label'] as String,
        documentType: json['documentType'] != null
            ? documentTypeFromString(json['documentType'] as String)
            : null,
        isCustom: json['isCustom'] as bool? ?? false,
      );
}

/// ガントチャートプリセット
class GanttPreset {
  final String id;
  final String name;
  final List<GanttTask> tasks;

  const GanttPreset({
    required this.id,
    required this.name,
    required this.tasks,
  });

  static const standard = GanttPreset(
    id: 'standard',
    name: '標準フロー',
    tasks: [
      GanttTask(id: 'estimation', label: '見積', documentType: DocumentType.estimation),
      GanttTask(id: 'order', label: '受注', documentType: DocumentType.order),
      GanttTask(id: 'delivery', label: '納品', documentType: DocumentType.delivery),
      GanttTask(id: 'invoice', label: '請求', documentType: DocumentType.invoice),
    ],
  );

  static const simple = GanttPreset(
    id: 'simple',
    name: '簡易フロー',
    tasks: [
      GanttTask(id: 'estimation', label: '見積', documentType: DocumentType.estimation),
      GanttTask(id: 'invoice', label: '請求', documentType: DocumentType.invoice),
    ],
  );

  static const purchase = GanttPreset(
    id: 'purchase',
    name: '発注フロー',
    tasks: [
      GanttTask(id: 'order', label: '発注', documentType: DocumentType.order),
      GanttTask(id: 'delivery', label: '納品', documentType: DocumentType.delivery),
      GanttTask(id: 'invoice', label: '請求', documentType: DocumentType.invoice),
    ],
  );

  static const salesOnly = GanttPreset(
    id: 'sales_only',
    name: '受注のみ',
    tasks: [
      GanttTask(id: 'order', label: '受注', documentType: DocumentType.order),
      GanttTask(id: 'delivery', label: '納品', documentType: DocumentType.delivery),
      GanttTask(id: 'invoice', label: '請求', documentType: DocumentType.invoice),
    ],
  );

  static const allPresets = [standard, simple, purchase, salesOnly];

  static GanttPreset? getById(String id) {
    for (final preset in allPresets) {
      if (preset.id == id) return preset;
    }
    return null;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'tasks': tasks.map((t) => t.toJson()).toList(),
      };

  factory GanttPreset.fromJson(Map<String, dynamic> json) => GanttPreset(
        id: json['id'] as String,
        name: json['name'] as String,
        tasks: (json['tasks'] as List<dynamic>)
            .map((t) => GanttTask.fromJson(t as Map<String, dynamic>))
            .toList(),
      );
}
