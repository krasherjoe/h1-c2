import 'package:shared_preferences/shared_preferences.dart';

class PluginStateService {
  static const _kPrefix = 'plugin_enabled_';

  Future<bool> isEnabled(String pluginId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('$_kPrefix$pluginId') ?? true;
  }

  Future<void> setEnabled(String pluginId, bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('$_kPrefix$pluginId', enabled);
  }

  Future<Map<String, bool>> loadAll(List<String> pluginIds) async {
    final prefs = await SharedPreferences.getInstance();
    return {
      for (final id in pluginIds)
        id: prefs.getBool('$_kPrefix$id') ?? true,
    };
  }
}
