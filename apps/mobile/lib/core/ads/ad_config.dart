import 'dart:io';

import 'package:flutter/foundation.dart';

class AdConfig {
  const AdConfig._();

  static bool get isAdsEnabled => shouldLoadAds;

  static bool get useTestAds => kDebugMode;

  static bool get shouldLoadAds =>
      shouldLoadBannerAds || shouldLoadInterstitialAds || shouldLoadRewardedAds;

  static bool get shouldLoadBannerAds => Platform.isAndroid || kDebugMode;

  static bool get shouldLoadInterstitialAds => Platform.isAndroid || kDebugMode;

  static bool get shouldLoadRewardedAds => kDebugMode;

  static const String androidAppId = 'ca-app-pub-3770146961182211~3054846230';
  static const String iosAppId = 'ca-app-pub-3940256099942544~1458002511';

  static const String _androidBannerId = 'ca-app-pub-3770146961182211/6592178675';
  static const String _iosBannerId = 'ca-app-pub-3940256099942544/2435281174';

  static const String _androidInterstitialId = 'ca-app-pub-3770146961182211/6977944643';
  static const String _iosInterstitialId = 'ca-app-pub-3940256099942544/4411468910';

  static const String _androidRewardedId = 'ca-app-pub-3940256099942544/5224354917';
  static const String _iosRewardedId = 'ca-app-pub-3940256099942544/1712485313';

  static String get bannerUnitId {
    if (Platform.isAndroid) {
      return kDebugMode ? 'ca-app-pub-3940256099942544/9214589741' : _androidBannerId;
    }
    return _iosBannerId;
  }

  static String get interstitialUnitId {
    if (Platform.isAndroid) {
      return kDebugMode ? 'ca-app-pub-3940256099942544/1033173712' : _androidInterstitialId;
    }
    return _iosInterstitialId;
  }

  static String get rewardedUnitId => Platform.isIOS ? _iosRewardedId : _androidRewardedId;
}
