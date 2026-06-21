import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class ScreenshotService {
  static final ScreenshotService _instance = ScreenshotService._internal();
  factory ScreenshotService() => _instance;
  ScreenshotService._internal();

  GlobalKey? _appKey;

  /// アプリ全体のGlobalKeyを設定（ICE-APIプラグイン有効時に呼び出す）
  void setGlobalKey(GlobalKey key) {
    _appKey = key;
  }

  /// スクリーンショットを取得してBase64エンコードされたPNGを返す
  /// 注意: RenderRepaintBoundaryでラップされたウィジェットのGlobalKeyが必要
  Future<String> captureToBase64() async {
    if (_appKey == null) {
      throw Exception('GlobalKey not set. ICE-API plugin must be enabled.');
    }
    try {
      final bytes = await captureToBytes();
      return base64Encode(bytes);
    } catch (e) {
      throw Exception('スクリーンショット取得失敗: $e');
    }
  }

  /// スクリーンショットを取得してファイルに保存
  /// 注意: RenderRepaintBoundaryでラップされたウィジェットのGlobalKeyが必要
  Future<String> captureToFile({String? filename}) async {
    if (_appKey == null) {
      throw Exception('GlobalKey not set. ICE-API plugin must be enabled.');
    }
    try {
      final bytes = await captureToBytes();
      
      final dir = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final name = filename ?? 'screenshot_$timestamp.png';
      final filePath = p.join(dir.path, name);
      
      final file = File(filePath);
      await file.writeAsBytes(bytes);
      
      return filePath;
    } catch (e) {
      throw Exception('スクリーンショット保存失敗: $e');
    }
  }

  /// スクリーンショットを取得してバイト配列を返す
  /// 注意: RenderRepaintBoundaryでラップされたウィジェットのGlobalKeyが必要
  Future<Uint8List> captureToBytes() async {
    if (_appKey == null) {
      throw Exception('GlobalKey not set. ICE-API plugin must be enabled.');
    }
    try {
      final RenderRepaintBoundary boundary = _appKey!.currentContext?.findRenderObject() as RenderRepaintBoundary;
      if (boundary == null) {
        throw Exception('RenderRepaintBoundary not found');
      }
      
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        throw Exception('ByteData is null');
      }
      
      return byteData.buffer.asUint8List();
    } catch (e) {
      throw Exception('スクリーンショット取得失敗: $e');
    }
  }

  /// スクリーンショット機能が有効かどうか
  bool get isEnabled => _appKey != null;
}
