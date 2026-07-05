import 'package:flutter/material.dart';
import 'database_helper.dart';
import 'role_service.dart';

enum AppFeature {
  masterEdit, masterDelete, masterCreate,
  invoiceView, invoiceEdit, invoiceCreate, invoiceDelete, invoiceIssue,
  accountingView,
  settingEdit,
  backup,
}

class PermissionService {
  static final PermissionService _instance = PermissionService._internal();
  factory PermissionService() => _instance;
  PermissionService._internal();

  Map<String, bool> _perms = {};

  static const _allFeatures = {
    'masterEdit': '顧客・商品マスター編集',
    'masterDelete': '顧客・商品マスター削除',
    'masterCreate': '顧客・商品マスター作成',
    'invoiceView': '伝票閲覧',
    'invoiceEdit': '伝票編集',
    'invoiceCreate': '伝票作成',
    'invoiceDelete': '伝票削除',
    'invoiceIssue': '伝票正式発行',
    'accountingView': '会計機能',
    'settingEdit': '設定変更',
    'backup': 'バックアップ',
  };

  static Map<String, String> get allFeatures => Map.unmodifiable(_allFeatures);

  static const Map<String, bool> defaultChildPermissions = {
    'masterEdit': false, 'masterDelete': false, 'masterCreate': false,
    'invoiceView': true, 'invoiceEdit': true, 'invoiceCreate': true,
    'invoiceDelete': false, 'invoiceIssue': false,
    'accountingView': false, 'settingEdit': false, 'backup': false,
  };

  Future<void> loadFromDb() async {
    try {
      final db = await DatabaseHelper().database;
      final rows = await db.query('permissions');
      if (rows.isEmpty) {
        _perms = Map<String, bool>.from(defaultChildPermissions);
      } else {
        _perms = {for (final r in rows) r['feature'] as String: (r['allowed'] as int) == 1};
      }
    } catch (_) {
      _perms = Map<String, bool>.from(defaultChildPermissions);
    }
  }

  Future<void> applySyncPermissions(Map<String, bool> perms) async {
    _perms = Map.from(perms);
    try {
      final db = await DatabaseHelper().database;
      await db.delete('permissions');
      for (final e in perms.entries) {
        await db.insert('permissions', {'feature': e.key, 'allowed': e.value ? 1 : 0});
      }
    } catch (_) {}
  }

  bool hasPermission(AppFeature feature) => _perms[feature.name] ?? true;
  bool get canEdit => hasPermission(AppFeature.masterEdit);
  bool get canDelete => hasPermission(AppFeature.masterDelete);
  bool get canCreate => hasPermission(AppFeature.masterCreate);
}

Future<bool> guardWrite(BuildContext context, AppFeature feature) async {
  final roleService = RoleService();
  if (await roleService.hasPermission(feature.name)) return true;
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('この機能を使用する権限がありません')),
    );
  }
  return false;
}
