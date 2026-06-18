import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart' as l;

enum LogLevel { debug, info, warn, error }

class LoggerService {
  static final LoggerService instance = LoggerService._();
  LoggerService._();

  final l.Logger _logger = l.Logger(
    printer: l.PrettyPrinter(
      methodCount: 0,
      errorMethodCount: 5,
      printEmojis: false,
      colors: false,
    ),
    output: _ProductionOutput(),
  );

  bool _debugMode = kDebugMode;

  void setDebugMode(bool v) => _debugMode = v;

  void debug(String tag, String message) {
    if (!_debugMode) return;
    _logger.d('[$tag] $message');
  }

  void info(String tag, String message) {
    _logger.i('[$tag] $message');
  }

  void warn(String tag, String message) {
    _logger.w('[$tag] $message');
  }

  void error(String tag, String message, [dynamic error, StackTrace? stack]) {
    _logger.e('[$tag] $message', error: error, stackTrace: stack);
  }
}

class _ProductionOutput extends l.LogOutput {
  @override
  void output(l.OutputEvent event) {
    for (final line in event.lines) {
      debugPrint(line);
    }
  }
}
