import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsRepository {
  final SharedPreferences _prefs;

  SettingsRepository(this._prefs);

  int get defaultTaxRate => _prefs.getInt('default_tax_rate') ?? 10;
  set defaultTaxRate(int value) => _prefs.setInt('default_tax_rate', value);

  String get documentNumberPrefix => _prefs.getString('doc_number_prefix') ?? '';
  set documentNumberPrefix(String value) => _prefs.setString('doc_number_prefix', value);

  static const _themeKey = 'theme_mode';

  ThemeMode get themeMode {
    final v = _prefs.getString(_themeKey) ?? 'system';
    return switch (v) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }

  set themeMode(ThemeMode mode) {
    _prefs.setString(_themeKey, switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      _ => 'system',
    });
  }

  static const _inputStyleKey = 'input_field_style';

  String get inputFieldStyle => _prefs.getString(_inputStyleKey) ?? 'raised';
  set inputFieldStyle(String v) => _prefs.setString(_inputStyleKey, v);
}
