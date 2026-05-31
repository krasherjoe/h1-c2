import 'package:flutter/foundation.dart' show debugPrint;

enum BarcodeType {
  jan13,
  jan8,
  upcA,
  other,
}

class BarcodeUtils {
  static BarcodeType detectType(String code) {
    final digits = _onlyDigits(code);
    if (digits == null) return BarcodeType.other;
    if (digits.length == 13 && digits.startsWith('49')) return BarcodeType.jan13;
    if (digits.length == 13) return BarcodeType.jan13;
    if (digits.length == 8) return BarcodeType.jan8;
    if (digits.length == 12) return BarcodeType.upcA;
    return BarcodeType.other;
  }

  static int calcCheckDigit(String code) {
    final digits = _onlyDigits(code);
    if (digits == null) return -1;
    final len = digits.length;
    int sum = 0;
    for (int i = 0; i < len; i++) {
      final d = digits.codeUnitAt(i) - 0x30;
      sum += d * ((len - 1 - i).isEven ? 3 : 1);
    }
    return (10 - (sum % 10)) % 10;
  }

  static bool validate(String code) {
    final digits = _onlyDigits(code);
    if (digits == null) return false;
    if (digits.length < 2) return false;
    final body = digits.substring(0, digits.length - 1);
    final expected = calcCheckDigit(body);
    final actual = digits.codeUnitAt(digits.length - 1) - 0x30;
    return expected >= 0 && expected == actual;
  }

  static String? _onlyDigits(String code) {
    final buf = StringBuffer();
    for (int i = 0; i < code.length; i++) {
      final c = code.codeUnitAt(i);
      if (c >= 0x30 && c <= 0x39) {
        buf.writeCharCode(c);
      } else if (c != 0x20 && c != 0x2d) {
        return null;
      }
    }
    final result = buf.toString();
    return result.isEmpty ? null : result;
  }

  static String? normalize(String code) {
    if (code.isEmpty) return null;
    final digits = _onlyDigits(code);
    if (digits == null) return null;
    if (validate(digits)) return digits;
    debugPrint('[BarcodeUtils] invalid check digit: $code');
    return null;
  }

  static String display(String code) {
    final digits = _onlyDigits(code);
    if (digits == null) return code;
    if (digits.length == 13) return '${digits.substring(0, 3)}-${digits.substring(3, 8)}-${digits.substring(8)}';
    if (digits.length == 8) return '${digits.substring(0, 4)}-${digits.substring(4)}';
    return digits;
  }
}
