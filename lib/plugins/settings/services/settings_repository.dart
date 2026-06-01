import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/company_profile.dart';

class SettingsRepository {
  final SharedPreferences _prefs;

  static const _profileKey = 'company_profile';

  SettingsRepository(this._prefs);

  Future<CompanyProfile> loadCompanyProfile() async {
    final json = _prefs.getString(_profileKey);
    if (json == null) return const CompanyProfile();
    return CompanyProfile.fromJson(jsonDecode(json) as Map<String, dynamic>);
  }

  Future<void> saveCompanyProfile(CompanyProfile profile) async {
    await _prefs.setString(_profileKey, jsonEncode(profile.toJson()));
  }

  int get defaultTaxRate => _prefs.getInt('default_tax_rate') ?? 10;
  set defaultTaxRate(int value) => _prefs.setInt('default_tax_rate', value);

  String get documentNumberPrefix => _prefs.getString('doc_number_prefix') ?? '';
  set documentNumberPrefix(String value) => _prefs.setString('doc_number_prefix', value);
}
