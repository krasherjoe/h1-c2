import 'package:flutter/services.dart';
import 'package:pdf/widgets.dart' as pw;

pw.Font? _cachedFont;

Future<pw.Font> loadIpaexFont() async {
  if (_cachedFont != null) return _cachedFont!;
  final data = await rootBundle.load('fonts/ipaexg.ttf');
  _cachedFont = pw.Font.ttf(data);
  return _cachedFont!;
}
