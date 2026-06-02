class Warehouse {
  const Warehouse({
    required this.id,
    required this.name,
    this.location,
    this.notes,
    this.isHidden = false,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final String? location;
  final String? notes;
  final bool isHidden;
  final DateTime updatedAt;

  Warehouse copyWith({
    String? id,
    String? name,
    String? location,
    String? notes,
    bool? isHidden,
    DateTime? updatedAt,
  }) {
    return Warehouse(
      id: id ?? this.id,
      name: name ?? this.name,
      location: location ?? this.location,
      notes: notes ?? this.notes,
      isHidden: isHidden ?? this.isHidden,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory Warehouse.fromMap(Map<String, Object?> map) {
    return Warehouse(
      id: map['id'] as String? ?? '',
      name: map['name'] as String? ?? '-',
      location: map['location'] as String?,
      notes: map['notes'] as String?,
      isHidden: (map['is_hidden'] as int? ?? 0) == 1,
      updatedAt: DateTime.parse(map['updated_at'] as String? ?? ''),
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'name': name,
      'location': location,
      'notes': notes,
      'is_hidden': isHidden ? 1 : 0,
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}
