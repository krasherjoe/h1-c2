import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'database_helper.dart';

class CompanyService {
  static final ValueNotifier<String?> activeCompanyNotifier = ValueNotifier(null);

  static const _prefKey = 'current_company';
  static const _dirName = '販売アシスト1号code';
  static const _defaultFileName = 'default_company.txt';

  static Future<String> _getBasePath() async {
    if (Platform.isAndroid) {
      final path = '/storage/emulated/0/Documents/$_dirName';
      try {
        await Directory(path).create(recursive: true);
        return path;
      } catch (_) {
        debugPrint('[CompanyService] 外部ストレージアクセス不可、app-privateにフォールバック');
      }
    }
    final appDir = await getApplicationDocumentsDirectory();
    return p.join(appDir.path, _dirName);
  }

  static Future<Directory> getCompanyDirectory() async {
    final path = await _getBasePath();
    final dir = Directory(path);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  static Future<List<String>> getCompanyList() async {
    final dir = await getCompanyDirectory();
    final files = dir.listSync().whereType<File>();
    return files
        .where((f) => f.path.endsWith('.db'))
        .map((f) => p.basenameWithoutExtension(f.path))
        .where((name) => !name.startsWith('.'))
        .toList()..sort();
  }

  static Future<String?> getCurrentCompany() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_prefKey);
  }

  static Future<void> setCurrentCompany(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, name);
  }

  static Future<String> getCurrentDbPath() async {
    final name = await getCurrentCompany() ?? 'default';
    final dir = await getCompanyDirectory();
    return p.join(dir.path, '$name.db');
  }

  static Future<bool> companyExists(String name) async {
    final dir = await getCompanyDirectory();
    return File(p.join(dir.path, '$name.db')).exists();
  }

  static Future<String> createCompany(String name) async {
    final dir = await getCompanyDirectory();
    final dbPath = p.join(dir.path, '$name.db');
    final db = await openDatabase(dbPath);
    await createAllTables(db, DatabaseHelper.databaseVersion);
    await db.close();
    return name;
  }

  static Future<void> deleteCompany(String name) async {
    final dir = await getCompanyDirectory();
    final file = File(p.join(dir.path, '$name.db'));
    if (await file.exists()) await file.delete();
  }

  static Future<void> switchCompany(String name) async {
    await DatabaseHelper.closeAndReset();
    await setCurrentCompany(name);
    activeCompanyNotifier.value = name;
  }

  static Future<String> getDefaultCompany() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefKey);
    if (saved != null) return saved;
    return 'default';
  }
}
