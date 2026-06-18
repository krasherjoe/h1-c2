import 'logger_service.dart';

class SysLogger {
  static final SysLogger instance = SysLogger._();
  SysLogger._();

  void logError(String tag, dynamic message) {
    LoggerService.instance.error(tag, message.toString());
  }

  void logInfo(String tag, String message) {
    LoggerService.instance.info(tag, message);
  }
}
