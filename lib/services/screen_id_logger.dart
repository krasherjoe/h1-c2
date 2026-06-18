import 'logger_service.dart';

class ScreenIdLogger {
  static void log(String screenId, String message) {
    LoggerService.instance.debug(screenId, message);
  }
}
