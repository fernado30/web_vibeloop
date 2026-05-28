import 'dart:io';

import 'package:flutter/foundation.dart';

class AdConfig {
  const AdConfig._();

  static bool get isAdsEnabled => kDebugMode;

  static bool get useTestAds => kDebugMode;

  static bool get shouldLoadAds => isAdsEnabled;

  static const String androidAppId = 'ca-app-pub-3940256099942544~3347511713';
  static const String iosAppId = 'ca-app-pub-3940256099942544~1458002511';

  static const String _androidBannerId = 'ca-app-pub-3940256099942544/9214589741';
  static const String _iosBannerId = 'ca-app-pub-3940256099942544/2435281174';

  static const String _androidInterstitialId = 'ca-app-pub-3940256099942544/1033173712';
  static const String _iosInterstitialId = 'ca-app-pub-3940256099942544/4411468910';

  static const String _androidRewardedId = 'ca-app-pub-3940256099942544/5224354917';
  static const String _iosRewardedId = 'ca-app-pub-3940256099942544/1712485313';

  static String get bannerUnitId => Platform.isIOS ? _iosBannerId : _androidBannerId;

  static String get interstitialUnitId => Platform.isIOS ? _iosInterstitialId : _androidInterstitialId;

  static String get rewardedUnitId => Platform.isIOS ? _iosRewardedId : _androidRewardedId;
}
