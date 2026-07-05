class User {
  final String id;
  final String email;
  final String? displayName;
  final String role;
  final String? photoUrl;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? lastLoginAt;

  const User({
    required this.id,
    required this.email,
    this.displayName,
    this.role = 'member',
    this.photoUrl,
    this.isActive = true,
    this.createdAt,
    this.lastLoginAt,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'email': email,
    'display_name': displayName,
    'role': role,
    'photo_url': photoUrl,
    'is_active': isActive ? 1 : 0,
    'created_at': createdAt?.toIso8601String(),
    'last_login_at': lastLoginAt?.toIso8601String(),
  };

  factory User.fromMap(Map<String, dynamic> map) => User(
    id: map['id'] as String,
    email: map['email'] as String,
    displayName: map['display_name'] as String?,
    role: map['role'] as String? ?? 'member',
    photoUrl: map['photo_url'] as String?,
    isActive: (map['is_active'] as int?) == 1,
    createdAt: map['created_at'] != null ? DateTime.parse(map['created_at'] as String) : null,
    lastLoginAt: map['last_login_at'] != null ? DateTime.parse(map['last_login_at'] as String) : null,
  );

  User copyWith({
    String? id,
    String? email,
    String? displayName,
    String? role,
    String? photoUrl,
    bool? isActive,
    DateTime? createdAt,
    DateTime? lastLoginAt,
  }) => User(
    id: id ?? this.id,
    email: email ?? this.email,
    displayName: displayName ?? this.displayName,
    role: role ?? this.role,
    photoUrl: photoUrl ?? this.photoUrl,
    isActive: isActive ?? this.isActive,
    createdAt: createdAt ?? this.createdAt,
    lastLoginAt: lastLoginAt ?? this.lastLoginAt,
  );
}
