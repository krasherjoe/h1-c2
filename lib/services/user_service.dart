import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/user_model.dart';
import 'database_helper.dart';

class UserService {
  static final UserService _instance = UserService._internal();
  factory UserService() => _instance;
  UserService._internal();

  User? _currentUser;
  User? get currentUser => _currentUser;

  /// メールアドレスでユーザーを検索、なければ作成
  Future<User> getOrCreateUser({
    required String email,
    String? displayName,
    String? photoUrl,
  }) async {
    final db = await DatabaseHelper().database;

    // 既存ユーザーを検索
    final rows = await db.query(
      'users',
      where: 'email = ?',
      whereArgs: [email],
    );

    if (rows.isNotEmpty) {
      // 既存ユーザー → last_login_at を更新
      final user = User.fromMap(rows.first);
      final updated = user.copyWith(lastLoginAt: DateTime.now());
      await db.update(
        'users',
        updated.toMap(),
        where: 'id = ?',
        whereArgs: [user.id],
      );
      _currentUser = updated;
      _log('既存ユーザーログイン: ${user.email}');
      return updated;
    }

    // 新規ユーザー作成
    final now = DateTime.now();
    final newUser = User(
      id: const Uuid().v4(),
      email: email,
      displayName: displayName,
      photoUrl: photoUrl,
      role: 'member',
      createdAt: now,
      lastLoginAt: now,
    );
    await db.insert('users', newUser.toMap());
    _currentUser = newUser;
    _log('新規ユーザー作成: ${newUser.email}');
    return newUser;
  }

  /// ログアウト
  void logout() {
    _currentUser = null;
    _log('ログアウト');
  }

  /// 全ユーザー取得
  Future<List<User>> getAllUsers() async {
    final db = await DatabaseHelper().database;
    final rows = await db.query('users', orderBy: 'created_at DESC');
    return rows.map((r) => User.fromMap(r)).toList();
  }

  /// ユーザーのロールを更新
  Future<void> updateRole(String userId, String role) async {
    final db = await DatabaseHelper().database;
    await db.update(
      'users',
      {'role': role},
      where: 'id = ?',
      whereArgs: [userId],
    );
  }

  /// ユーザーを無効化
  Future<void> deactivate(String userId) async {
    final db = await DatabaseHelper().database;
    await db.update(
      'users',
      {'is_active': 0},
      where: 'id = ?',
      whereArgs: [userId],
    );
  }

  void _log(String msg) {
    debugPrint('[UserService] $msg');
  }
}
