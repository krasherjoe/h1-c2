import 'dart:math' as math;
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
    final sinDLat = math.sin(dLat / 2);
    final sinDLng = math.sin(dLng / 2);
    final a = sinDLat * sinDLat +
        math.cos(_toRad(lat1)) * math.cos(_toRad(lat2)) * sinDLng * sinDLng;
    return R * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  static double _toRad(double deg) => deg * math.pi / 180;
}
