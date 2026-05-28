import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'ad_config.dart';

class RewardedAdManager {
  static const Duration _cooldown = Duration(minutes: 20);

  RewardedAd? _ad;
  bool _loading = false;
  bool _showing = false;
  DateTime? _lastShownAt;

  bool get _isOnCooldown {
    final lastShownAt = _lastShownAt;
    if (lastShownAt == null) return false;
    return DateTime.now().difference(lastShownAt) < _cooldown;
  }

  Future<void> preload() async {
    if (!AdConfig.shouldLoadAds || _loading || _showing || _ad != null || _isOnCooldown) {
      return;
    }

    _loading = true;
    RewardedAd.load(
      adUnitId: AdConfig.rewardedUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _loading = false;
          _ad = ad;
          _wireCallbacks(ad);
        },
        onAdFailedToLoad: (error) {
          _loading = false;
          _ad = null;
          debugPrint('Rewarded failed to load: $error');
        },
      ),
    );
  }

  Future<bool> showIfAvailable({
    required String reason,
    required void Function(RewardItem reward) onUserEarnedReward,
  }) async {
    if (!AdConfig.shouldLoadAds) {
      return false;
    }

    if (_isOnCooldown) {
      unawaited(preload());
      return false;
    }

    final ad = _ad;
    if (ad == null) {
      unawaited(preload());
      return false;
    }

    _ad = null;
    _showing = true;
    debugPrint('Showing rewarded ad for: $reason');
    ad.show(
      onUserEarnedReward: (ad, reward) {
        onUserEarnedReward(reward);
      },
    );
    return true;
  }

  void _wireCallbacks(RewardedAd ad) {
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (_) {
        _showing = true;
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _showing = false;
        _lastShownAt = DateTime.now();
        unawaited(preload());
      },
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _showing = false;
        _lastShownAt = DateTime.now();
        unawaited(preload());
      },
    );
  }

  void dispose() {
    _ad?.dispose();
    _ad = null;
  }
}
