// geolocator スタブ - コア版では位置情報機能を無効化
class Geolocator {
  static Future<Map<String, double>> getCurrentPosition() async {
    return {'latitude': 0.0, 'longitude': 0.0};
  }
}
