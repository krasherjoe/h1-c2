class DebugConsole {
  static final _cmds = <String, Future<String> Function(List<String> args)>{};

  static void register(String name, Future<String> Function(List<String> args) fn) {
    _cmds[name] = fn;
  }

  static Future<String> call(String name, List<String> args) async {
    final fn = _cmds[name];
    if (fn == null) {
      final alt = _cmds.entries.where((e) => e.key.startsWith(name)).toList();
      if (alt.length == 1) return alt[0].value(args);
      if (alt.length > 1) {
        return '曖昧: ${alt.map((e) => e.key).join(', ')}';
      }
      return '不明なコマンド: $name\n登録済み: ${_cmds.keys.join(', ')}';
    }
    return fn(args);
  }

  static List<String> get registered => _cmds.keys.toList();
}
