import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class ErrorLogEntry {
  final String timestamp;
  final String message;
  final String? stackTrace;
  final String? screen;
  final String? context;

  ErrorLogEntry({
    required this.timestamp,
    required this.message,
    this.stackTrace,
    this.screen,
    this.context,
  });

  Map<String, dynamic> toJson() => {
        'timestamp': timestamp,
        'message': message,
        'stackTrace': stackTrace,
        'screen': screen,
        'context': context,
      };

  factory ErrorLogEntry.fromJson(Map<String, dynamic> json) => ErrorLogEntry(
        timestamp: json['timestamp'] as String,
        message: json['message'] as String,
        stackTrace: json['stackTrace'] as String?,
        screen: json['screen'] as String?,
        context: json['context'] as String?,
      );
}

class ErrorLogService {
  static const _key = 'error_logs';
  static const _maxLogs = 100;
  static ErrorLogService? _instance;
  late SharedPreferences _prefs;

  ErrorLogService._();

  static ErrorLogService get instance {
    _instance ??= ErrorLogService._();
    return _instance!;
  }

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  Future<void> logError(String message, {String? stackTrace, String? screen, String? context}) async {
    await init();
    final entry = ErrorLogEntry(
      timestamp: DateTime.now().toIso8601String(),
      message: message,
      stackTrace: stackTrace,
      screen: screen,
      context: context,
    );

    final logs = await getLogs();
    logs.add(entry);

    // 最大数を超えたら古いログを削除
    if (logs.length > _maxLogs) {
      logs.removeRange(0, logs.length - _maxLogs);
    }

    await _saveLogs(logs);
  }

  Future<List<ErrorLogEntry>> getLogs() async {
    await init();
    final jsonStr = _prefs.getString(_key);
    if (jsonStr == null || jsonStr.isEmpty) return [];

    try {
      final List<dynamic> jsonList = jsonDecode(jsonStr);
      return jsonList.map((e) => ErrorLogEntry.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> clearLogs() async {
    await init();
    await _prefs.remove(_key);
  }

  Future<void> _saveLogs(List<ErrorLogEntry> logs) async {
    final jsonStr = jsonEncode(logs.map((e) => e.toJson()).toList());
    await _prefs.setString(_key, jsonStr);
  }
}
