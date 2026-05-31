import 'package:flutter/foundation.dart' show debugPrint;

class GpsPosition {
  final double latitude;
  final double longitude;
  const GpsPosition({this.latitude = 0.0, this.longitude = 0.0});
}

class GpsService {
  Future<GpsPosition?> getCurrentLocation() async {
    debugPrint('[GpsService] stub: location disabled in core');
    return null;
  }

  Future<void> logLocation() async {}
}
