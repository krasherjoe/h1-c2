import 'package:flutter/foundation.dart';

class SysLogger {
  static final SysLogger instance = SysLogger._();
  SysLogger._();

  void logError(String tag, dynamic message) =>
      debugPrint('[$tag] ERROR: $message');

  void logInfo(String tag, String message) =>
      debugPrint('[$tag] INFO: $message');
}
