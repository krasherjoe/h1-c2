import 'package:shared_preferences/shared_preferences.dart';

class AppSettingsRepository {
  static final AppSettingsRepository _instance = AppSettingsRepository._internal();
  factory AppSettingsRepository() => _instance;
  AppSettingsRepository._internal();

  SharedPreferences? _prefs;

  static Future<void> init() async {
    _instance._prefs = await SharedPreferences.getInstance();
  }

  Future<String?> get(String key) async {
    return _prefs?.getString(key);
  }

  Future<void> set(String key, String value) async {
    await _prefs?.setString(key, value);
  }

  Future<int?> getInt(String key) async {
    return _prefs?.getInt(key);
  }

  Future<void> setInt(String key, int value) async {
    await _prefs?.setInt(key, value);
  }

  Future<bool?> getBool(String key) async {
    return _prefs?.getBool(key);
  }

  Future<void> setBool(String key, bool value) async {
    await _prefs?.setBool(key, value);
  }

  Future<String?> getSummaryTheme() async => null;

  Future<void> setSummaryTheme(String value) async {}

  Future<String> getHomeMode() async => 'all';

  Stream<String> watchHomeMode() => const Stream.empty();

  Future<bool> getShowHistoryInvoiceNumber() async => true;

  Future<void> setShowHistoryInvoiceNumber(bool value) async {}
}
