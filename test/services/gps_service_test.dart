import 'package:flutter_test/flutter_test.dart';
import 'package:h_1_core/services/gps_service.dart';

void main() {
  group('distanceKm', () {
    test('同一地点の距離は0', () {
      final d = GpsService.distanceKm(35.0, 135.0, 35.0, 135.0);
      expect(d, closeTo(0, 0.001));
    });

    test('東京→大阪が約400km', () {
      // 東京駅: 35.681, 139.767
      // 大阪駅: 34.702, 135.495
      final d = GpsService.distanceKm(35.681, 139.767, 34.702, 135.495);
      expect(d, closeTo(403, 10));
    });

    test('東京→札幌が約800km', () {
      // 東京駅: 35.681, 139.767
      // 札幌駅: 43.068, 141.351
      final d = GpsService.distanceKm(35.681, 139.767, 43.068, 141.351);
      expect(d, closeTo(830, 20));
    });

    test('東京→那覇が約1500km', () {
      // 東京駅: 35.681, 139.767
      // 那覇空港: 26.204, 127.652
      final d = GpsService.distanceKm(35.681, 139.767, 26.204, 127.652);
      expect(d, closeTo(1550, 30));
    });

    test('南北対称', () {
      final d1 = GpsService.distanceKm(35.0, 135.0, 36.0, 136.0);
      final d2 = GpsService.distanceKm(36.0, 136.0, 35.0, 135.0);
      expect(d1, closeTo(d2, 0.001));
    });

    test('赤道上の経度差', () {
      final d = GpsService.distanceKm(0, 0, 0, 1);
      expect(d, closeTo(111, 5));
    });
  });
}
