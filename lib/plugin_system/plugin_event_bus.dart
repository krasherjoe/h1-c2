import 'package:flutter/foundation.dart';

class PluginEventBus {
  static final PluginEventBus instance = PluginEventBus._();

  PluginEventBus._();

  final Map<String, List<Function(dynamic)>> _listeners = {};

  void emit(String eventName, dynamic data) {
    final listeners = _listeners[eventName];
    if (listeners == null) return;
    for (final listener in listeners) {
      try {
        listener(data);
      } catch (e) {
        debugPrint('[EventBus] Error in listener: $e');
      }
    }
  }

  void on(String eventName, Function(dynamic) handler) {
    _listeners.putIfAbsent(eventName, () => []).add(handler);
  }

  void off(String eventName, Function(dynamic) handler) {
    _listeners[eventName]?.remove(handler);
  }

  void clear() {
    _listeners.clear();
  }
}
