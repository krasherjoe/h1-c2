import '../models/tracking_model.dart';

/// 追跡サービス
/// 各社の追跡URLを生成する機能のみ提供
class TrackingService {
  /// 追跡URLを取得
  String getTrackingUrl(Carrier carrier, String trackingNumber) {
    switch (carrier) {
      case Carrier.yamato:
        return 'https://toi.kuronekoyamato.co.jp/cgi-bin/tneko?number01=$trackingNumber';
      case Carrier.sagawa:
        return 'https://k2k.sagawa-exp.co.jp/p/web/okurijosearch.do?no1=$trackingNumber';
      case Carrier.jpPost:
        return 'https://tracking.post.japanpost.jp/services/srv/search/direct?searchLang=ja&locale=ja&reqCodeNo1=$trackingNumber';
      default:
        throw UnimplementedError('Unsupported carrier: ${carrier.name}');
    }
  }
}
