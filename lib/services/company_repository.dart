import 'package:flutter/foundation.dart' show debugPrint;
import 'package:sqflite/sqflite.dart';
import 'database_helper.dart';
import '../models/company_info.dart';

class CompanyRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  Future<CompanyInfo?> getCompanyInfo() async {
    try {
      final db = await _dbHelper.database;
      final maps = await db.query('company_info', limit: 1);
      if (maps.isNotEmpty) {
        return CompanyInfo.fromMap(maps.first);
      }
      return null;
    } catch (e) {
      debugPrint('[CompanyRepo] getCompanyInfo error: $e');
      return null;
    }
  }

  Future<void> saveCompanyInfo(CompanyInfo info) async {
    try {
      final db = await _dbHelper.database;
      await db.insert(
        'company_info',
        info.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      debugPrint('[CompanyRepo] saveCompanyInfo error: $e');
      rethrow;
    }
  }
}
