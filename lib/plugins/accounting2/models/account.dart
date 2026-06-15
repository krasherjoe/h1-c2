class Account {
  final int? id;
  final String code;
  final String name;
  final String category;
  final bool isSystem;

  const Account({
    this.id,
    required this.code,
    required this.name,
    required this.category,
    this.isSystem = false,
  });

  Map<String, dynamic> toMap() => {
    'code': code,
    'name': name,
    'category': category,
    'is_system': isSystem ? 1 : 0,
  };

  factory Account.fromMap(Map<String, dynamic> map) => Account(
    id: map['id'] as int?,
    code: map['code'] as String? ?? '',
    name: map['name'] as String? ?? '',
    category: map['category'] as String? ?? '',
    isSystem: (map['is_system'] as int?) == 1,
  );

  Account copyWith({int? id, String? code, String? name, String? category, bool? isSystem}) => Account(
    id: id ?? this.id,
    code: code ?? this.code,
    name: name ?? this.name,
    category: category ?? this.category,
    isSystem: isSystem ?? this.isSystem,
  );
}
