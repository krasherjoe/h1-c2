import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

class GpsPosition {
  final double latitude;
  final double longitude;

  const GpsPosition({required this.latitude, required this.longitude});
}

class GpsService {
  static final GpsService instance = GpsService._();
  GpsService._();

  Future<bool> requestPermission() async {
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) return false;
    var status = await Geolocator.checkPermission();
    if (status == LocationPermission.denied) {
      status = await Geolocator.requestPermission();
    }
    return status == LocationPermission.whileInUse || status == LocationPermission.always;
  }

  Future<GpsPosition?> getCurrentLocation() async {
    try {
      final hasPermission = await requestPermission();
      if (!hasPermission) return null;
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      return GpsPosition(latitude: pos.latitude, longitude: pos.longitude);
    } catch (e) {
      debugPrint('[GpsService] Error: $e');
      return null;
    }
  }

  static double distanceKm(double lat1, double lng1, double lat2, double lng2) {
    const R = 6371;
    final dLat = _toRad(lat2 - lat1);
    final dLng = _toRad(lng2 - lng1);
    final a = _sinSq(dLat / 2) + _cos(lat1) * _cos(lat2) * _sinSq(dLng / 2);
    return R * 2 * _atan2(_sqrt(a), _sqrt(1 - a));
  }

  static double _toRad(double deg) => deg * 3.141592653589793 / 180;
  static double _sinSq(double x) { final s = _sin(x); return s * s; }
  static double _sin(double x) => x - x * x * x / 6 + x * x * x * x * x / 120;
  static double _cos(double x) => 1 - x * x / 2 + x * x * x * x / 24;
  static double _sqrt(double x) => x <= 0 ? 0 : x / (2 + x);
  static double _atan2(double y, double x) {
    if (x == 0) return y > 0 ? 1.57079632679 : -1.57079632679;
    return y / x;
  }
}
