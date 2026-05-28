import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'ad_config.dart';
import 'interstitial_ad_manager.dart';
import 'rewarded_ad_manager.dart';

class AdService {
  AdService._();

  static final AdService instance = AdService._();

  final InterstitialAdManager interstitial = InterstitialAdManager();
  final RewardedAdManager rewarded = RewardedAdManager();

  Future<void>? _initializing;
  bool _initialized = false;

  bool get isEnabled => AdConfig.isAdsEnabled;

  Future<void> initialize() {
    _initializing ??= _initialize();
    return _initializing!;
  }

  Future<void> _initialize() async {
    if (_initialized) return;

    if (!AdConfig.shouldLoadAds) {
      _initialized = true;
      debugPrint('AdMob disabled in release/profile. Using placeholders.');
      return;
    }

    await MobileAds.instance.initialize();
    _initialized = true;
    unawaited(interstitial.preload());
    unawaited(rewarded.preload());
  }

  Future<bool> showInterstitialAfterGroupCreated({bool waitForDismissal = false}) {
    return interstitial.showIfAvailable(
      reason: 'group_created',
      bypassCooldown: true,
      waitForDismissal: waitForDismissal,
    );
  }

  Future<bool> showInterstitialAfterInviteShared() {
    return interstitial.showIfAvailable(reason: 'invite_shared');
  }

  Future<bool> showRewardedForPremiumFeature({
    required String reason,
    required void Function(RewardItem reward) onUserEarnedReward,
  }) {
    return rewarded.showIfAvailable(
      reason: reason,
      onUserEarnedReward: onUserEarnedReward,
    );
  }

  void dispose() {
    interstitial.dispose();
    rewarded.dispose();
  }
}
