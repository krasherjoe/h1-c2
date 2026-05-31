/// カスタムフィールドタイプ
enum CustomFieldType {
  text,
  number,
  date,
  datetime,
  select,
  multiselect,
  checkbox,
  textarea,
  email,
  phone,
  url,
  currency,
}

/// カスタムフィールドのバリデーション
class CustomFieldValidation {
  final bool required;
  final int? minLength;
  final int? maxLength;
  final double? min;
  final double? max;
  final String? pattern;
  final List<String>? options;

  const CustomFieldValidation({
    this.required = false,
    this.minLength,
    this.maxLength,
    this.min,
    this.max,
    this.pattern,
    this.options,
  });

  Map<String, dynamic> toMap() => {
        'required': required ? 1 : 0,
        'min_length': minLength,
        'max_length': maxLength,
        'min_value': min,
        'max_value': max,
        'pattern': pattern,
        'options': options?.join(','),
      };

  factory CustomFieldValidation.fromMap(Map<String, dynamic> map) {
    return CustomFieldValidation(
      required: (map['required'] as int? ?? 0) == 1,
      minLength: map['min_length'] as int?,
      maxLength: map['max_length'] as int?,
      min: map['min_value'] as double?,
      max: map['max_value'] as double?,
      pattern: map['pattern'] as String?,
      options: map['options'] != null && map['options'].toString().isNotEmpty
          ? map['options'].toString().split(',')
          : null,
    );
  }
}

/// カスタムフィールド定義
class CustomField {
  final String id;
  final String businessProfileId;
  final String fieldName;
  final String fieldLabel;
  final CustomFieldType fieldType;
  final CustomFieldValidation validation;
  final int displayOrder;
  final bool isActive;
  final String? description;
  final String? defaultValue;
  final DateTime createdAt;
  final DateTime updatedAt;

  const CustomField({
    required this.id,
    required this.businessProfileId,
    required this.fieldName,
    required this.fieldLabel,
    required this.fieldType,
    required this.validation,
    this.displayOrder = 0,
    this.isActive = true,
    this.description,
    this.defaultValue,
    required this.createdAt,
    required this.updatedAt,
  });

  factory CustomField.create({
    required String businessProfileId,
    required String fieldName,
    required String fieldLabel,
    required CustomFieldType fieldType,
    CustomFieldValidation? validation,
    String? description,
    String? defaultValue,
  }) {
    final now = DateTime.now();
    return CustomField(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      businessProfileId: businessProfileId,
      fieldName: fieldName,
      fieldLabel: fieldLabel,
      fieldType: fieldType,
      validation: validation ?? const CustomFieldValidation(),
      description: description,
      defaultValue: defaultValue,
      createdAt: now,
      updatedAt: now,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'business_profile_id': businessProfileId,
        'field_name': fieldName,
        'field_label': fieldLabel,
        'field_type': fieldType.name,
        'validation': validation.toMap(),
        'display_order': displayOrder,
        'is_active': isActive ? 1 : 0,
        'description': description,
        'default_value': defaultValue,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  factory CustomField.fromMap(Map<String, dynamic> map) {
    return CustomField(
      id: map['id'] as String? ?? '',
      businessProfileId: map['business_profile_id'] as String? ?? '',
      fieldName: map['field_name'] as String? ?? '',
      fieldLabel: map['field_label'] as String? ?? '',
      fieldType: CustomFieldType.values.firstWhere(
        (type) => type.name == map['field_type'],
        orElse: () => CustomFieldType.text,
      ),
      validation: CustomFieldValidation.fromMap(
        map['validation'] as Map<String, dynamic>,
      ),
      displayOrder: map['display_order'] as int? ?? 0,
      isActive: (map['is_active'] as int?) == 1,
      description: map['description'] as String?,
      defaultValue: map['default_value'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String? ?? ''),
      updatedAt: DateTime.parse(map['updated_at'] as String? ?? ''),
    );
  }

  CustomField copyWith({
    String? fieldName,
    String? fieldLabel,
    CustomFieldType? fieldType,
    CustomFieldValidation? validation,
    int? displayOrder,
    bool? isActive,
    String? description,
    String? defaultValue,
    DateTime? updatedAt,
  }) {
    return CustomField(
      id: id,
      businessProfileId: businessProfileId,
      fieldName: fieldName ?? this.fieldName,
      fieldLabel: fieldLabel ?? this.fieldLabel,
      fieldType: fieldType ?? this.fieldType,
      validation: validation ?? this.validation,
      displayOrder: displayOrder ?? this.displayOrder,
      isActive: isActive ?? this.isActive,
      description: description ?? this.description,
      defaultValue: defaultValue ?? this.defaultValue,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is CustomField && other.id == id);

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'CustomField(id: $id, fieldName: $fieldName, fieldType: $fieldType)';
}

/// カスタムフィールドの値
class CustomFieldValue {
  final String id;
  final String customFieldId;
  final String entityId;
  final String entityType;
  final dynamic value;
  final DateTime createdAt;
  final DateTime updatedAt;

  const CustomFieldValue({
    required this.id,
    required this.customFieldId,
    required this.entityId,
    required this.entityType,
    required this.value,
    required this.createdAt,
    required this.updatedAt,
  });

  factory CustomFieldValue.create({
    required String customFieldId,
    required String entityId,
    required String entityType,
    required dynamic value,
  }) {
    final now = DateTime.now();
    return CustomFieldValue(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      customFieldId: customFieldId,
      entityId: entityId,
      entityType: entityType,
      value: value,
      createdAt: now,
      updatedAt: now,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'custom_field_id': customFieldId,
        'entity_id': entityId,
        'entity_type': entityType,
        'value': value?.toString(),
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  factory CustomFieldValue.fromMap(Map<String, dynamic> map) {
    return CustomFieldValue(
      id: map['id'] as String? ?? '',
      customFieldId: map['custom_field_id'] as String? ?? '',
      entityId: map['entity_id'] as String? ?? '',
      entityType: map['entity_type'] as String? ?? '',
      value: map['value'],
      createdAt: DateTime.parse(map['created_at'] as String? ?? ''),
      updatedAt: DateTime.parse(map['updated_at'] as String? ?? ''),
    );
  }

  CustomFieldValue copyWith({
    String? customFieldId,
    String? entityId,
    String? entityType,
    dynamic value,
    DateTime? updatedAt,
  }) {
    return CustomFieldValue(
      id: id,
      customFieldId: customFieldId ?? this.customFieldId,
      entityId: entityId ?? this.entityId,
      entityType: entityType ?? this.entityType,
      value: value ?? this.value,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }
}
