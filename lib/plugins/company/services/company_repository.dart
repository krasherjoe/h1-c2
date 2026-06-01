import 'package:sqflite/sqflite.dart';
import '../models/company_profile.dart';

class CompanyRepository {
  final Database _db;
  CompanyRepository(this._db);

  Future<CompanyProfile?> loadProfile() async {
    final rows = await _db.query('company_info', limit: 1);
    if (rows.isEmpty) return null;
    return CompanyProfile.fromMap(rows.first);
  }

  Future<void> saveProfile(CompanyProfile profile) async {
    final existing = await _db.query('company_info', limit: 1);
    final data = profile.toMap();
    if (existing.isEmpty) {
      await _db.insert('company_info', data);
    } else {
      await _db.update('company_info', data, where: 'id = ?', whereArgs: [1]);
    }
  }
}
