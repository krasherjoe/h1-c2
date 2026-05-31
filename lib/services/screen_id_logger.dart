import 'package:flutter/foundation.dart';

class ScreenIdLogger {
  static void log(String screenId, String message) =>
      debugPrint('[$screenId] $message');
}
