import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ReceiptOcrResult {
  final String? vendor;
  final String? date;
  final int total;
  final int? subtotal;
  final int? tax;
  final List<String> items;

  const ReceiptOcrResult({
    this.vendor,
    this.date,
    required this.total,
    this.subtotal,
    this.tax,
    this.items = const [],
  });
}

class GeminiOcrService {
  static const _kPrefKey = 'gemini_api_key';

  static Future<String?> getApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    final key = prefs.getString(_kPrefKey);
    return key?.isNotEmpty == true ? key : null;
  }

  static Future<void> setApiKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kPrefKey, key);
  }

  Future<ReceiptOcrResult?> analyzeReceipt(String imagePath) async {
    final apiKey = await getApiKey();
    if (apiKey == null) {
      debugPrint('[GeminiOcr] APIキー未設定');
      return null;
    }

    try {
      final file = File(imagePath);
      if (!file.existsSync()) {
        debugPrint('[GeminiOcr] ファイルが見つかりません: $imagePath');
        return null;
      }

      final imageBytes = await file.readAsBytes();
      final model = GenerativeModel(
        model: 'gemini-1.5-flash',
        apiKey: apiKey,
        generationConfig: GenerationConfig(
          temperature: 0.1,
          responseMimeType: 'application/json',
        ),
      );

      final prompt = '''
あなたは請求書・レシートのOCRアシスタントです。
画像から以下の情報をJSONで抽出してください。

必要なフィールド:
- vendor: 事業者名（文字列、なければnull）
- date: 日付（YYYY-MM-DD形式、なければnull）
- total: 合計金額（整数、必須）
- subtotal: 小計（整数、なければnull）
- tax: 消費税額（整数、なければnull）
- items: 品目リスト（文字列配列、なければ空配列）

ルール:
- 金額は必ず整数（税抜き/税込み問わず）
- 日付はYYYY-MM-DD形式に変換
- 不明なフィールドはnullにする
- JSONのみを出力。説明文は不要

出力例:
{"vendor": "株式会社サンプル", "date": "2026-06-01", "total": 5500, "subtotal": 5000, "tax": 500, "items": ["品目A", "品目B"]}
''';

      final response = await model.generateContent([
        Content.multi([TextPart(prompt), DataPart('image/jpeg', imageBytes)]),
      ]);

      final text = response.text;
      if (text == null || text.isEmpty) {
        debugPrint('[GeminiOcr] 応答なし');
        return null;
      }

      final json = jsonDecode(text) as Map<String, dynamic>;
      return ReceiptOcrResult(
        vendor: json['vendor'] as String?,
        date: json['date'] as String?,
        total: json['total'] as int? ?? 0,
        subtotal: json['subtotal'] as int?,
        tax: json['tax'] as int?,
        items: (json['items'] as List?)?.cast<String>() ?? [],
      );
    } catch (e, st) {
      debugPrint('[GeminiOcr] エラー: $e\n$st');
      return null;
    }
  }
}
