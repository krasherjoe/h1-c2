import 'package:sqflite/sqflite.dart' show ConflictAlgorithm;
import 'database_helper.dart';
import 'user_service.dart';

class RoleService {
  static final RoleService _instance = RoleService._internal();
  factory RoleService() => _instance;
  RoleService._internal();

  final Map<String, Map<String, bool>> _userPermissions = {};

  /// 現在のユーザーの権限を取得
  Future<bool> hasPermission(String feature) async {
    final user = UserService().currentUser;
    if (user == null) return false;
    if (user.role == 'admin') return true;

    final perms = await _getPermissionsForUser(user.id);
    return perms[feature] ?? _defaultPermission(user.role, feature);
  }

  /// ユーザーの権限一覧を取得
  Future<Map<String, bool>> _getPermissionsForUser(String userId) async {
    if (_userPermissions.containsKey(userId)) {
      return _userPermissions[userId]!;
    }
    final db = await DatabaseHelper().database;
    final rows = await db.query('user_permissions', where: 'user_id = ?', whereArgs: [userId]);
    final perms = {for (final r in rows) r['feature'] as String: (r['allowed'] as int) == 1};
    _userPermissions[userId] = perms;
    return perms;
  }

  /// デフォルト権限（ロールベース）
  bool _defaultPermission(String role, String feature) {
    switch (role) {
      case 'admin': return true;
      case 'member':
        return feature != 'settingEdit' && feature != 'backup';
      case 'viewer':
        return feature.endsWith('View');
      default: return false;
    }
  }

  /// ユーザーの権限を設定
  Future<void> setPermission(String userId, String feature, bool allowed) async {
    final db = await DatabaseHelper().database;
    await db.insert(
      'user_permissions',
      {'user_id': userId, 'feature': feature, 'allowed': allowed ? 1 : 0},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    _userPermissions.remove(userId);
  }

  /// ユーザーのロールを変更
  Future<void> setRole(String userId, String role) async {
    final db = await DatabaseHelper().database;
    await db.update('users', {'role': role}, where: 'id = ?', whereArgs: [userId]);
    _userPermissions.remove(userId);
  }

  /// キャッシュクリア
  void clearCache() {
    _userPermissions.clear();
  }

  static const featureLabels = {
    'masterEdit': 'マスター編集',
    'masterDelete': 'マスター削除',
    'masterCreate': 'マスター作成',
    'invoiceView': '伝票閲覧',
    'invoiceEdit': '伝票編集',
    'invoiceCreate': '伝票作成',
    'invoiceDelete': '伝票削除',
    'invoiceIssue': '伝票発行',
    'accountingView': '会計閲覧',
    'settingEdit': '設定変更',
    'backup': 'バックアップ',
    'userManage': 'ユーザー管理',
  };
}
