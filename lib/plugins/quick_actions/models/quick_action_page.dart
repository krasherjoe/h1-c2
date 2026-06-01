class QuickActionPage {
  final String id;
  String name;
  int sortOrder;
  List<String> actionIds;

  QuickActionPage({
    required this.id,
    required this.name,
    this.sortOrder = 0,
    List<String>? actionIds,
  }) : actionIds = actionIds ?? [];

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'sortOrder': sortOrder,
    'actionIds': actionIds,
  };

  factory QuickActionPage.fromJson(Map<String, dynamic> json) =>
      QuickActionPage(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '新規ページ',
        sortOrder: json['sortOrder'] as int? ?? 0,
        actionIds: (json['actionIds'] as List<dynamic>?)?.cast<String>() ?? [],
      );

  QuickActionPage copyWith({
    String? name,
    int? sortOrder,
    List<String>? actionIds,
  }) => QuickActionPage(
    id: id,
    name: name ?? this.name,
    sortOrder: sortOrder ?? this.sortOrder,
    actionIds: actionIds ?? List.from(this.actionIds),
  );
}
