import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

class ErrorReporter {
  static String _appVersion = '';

  static Future<void> initVersion() async {
    if (_appVersion.isNotEmpty) return;
    _appVersion = const String.fromEnvironment('APP_VERSION', defaultValue: '');
    if (_appVersion.isEmpty) {
      try {
        final info = await PackageInfo.fromPlatform();
        _appVersion = info.version;
      } catch (_) {
        _appVersion = 'dev';
      }
    }
  }

  static void sendError({
    required String message,
    String? detail,
    String? screenId,
    StackTrace? stackTrace,
  }) {
    debugPrint('[ErrorReporter] $message');
    if (detail != null) debugPrint('  detail: $detail');
    if (screenId != null) debugPrint('  screen: $screenId');
    if (stackTrace != null) debugPrint('  stack: ${stackTrace.toString().substring(0, stackTrace.toString().length.clamp(0, 500))}');
  }

  static void sendLog({required String message}) {
    debugPrint('[Log] $message');
  }

  static void showError(
    BuildContext context, {
    required String message,
    String? detail,
    String? screenId,
    StackTrace? stackTrace,
  }) {
    sendError(
      message: message,
      detail: detail,
      screenId: screenId,
      stackTrace: stackTrace,
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
      ),
    );
  }

  static Future<T?> tryWithReport<T>({
    required String label,
    required Future<T?> Function() fn,
    String? screenId,
  }) async {
    try {
      return await fn();
    } catch (e, st) {
      sendError(message: '$label: $e', detail: e.toString(), screenId: screenId, stackTrace: st);
      return null;
    }
  }
}
