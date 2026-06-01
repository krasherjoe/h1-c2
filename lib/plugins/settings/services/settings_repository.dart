import 'package:shared_preferences/shared_preferences.dart';

class SettingsRepository {
  final SharedPreferences _prefs;

  SettingsRepository(this._prefs);

  int get defaultTaxRate => _prefs.getInt('default_tax_rate') ?? 10;
  set defaultTaxRate(int value) => _prefs.setInt('default_tax_rate', value);

  String get documentNumberPrefix => _prefs.getString('doc_number_prefix') ?? '';
  set documentNumberPrefix(String value) => _prefs.setString('doc_number_prefix', value);
}
