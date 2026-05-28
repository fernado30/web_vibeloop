import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'ad_config.dart';

class InterstitialAdManager {
  static const Duration _cooldown = Duration(minutes: 8);

  InterstitialAd? _ad;
  bool _loading = false;
  bool _showing = false;
  DateTime? _lastShownAt;
  Completer<void>? _showCompleter;

  bool get _isOnCooldown {
    final lastShownAt = _lastShownAt;
    if (lastShownAt == null) return false;
    return DateTime.now().difference(lastShownAt) < _cooldown;
  }

  Future<void> preload({bool bypassCooldown = false}) async {
    if (!AdConfig.shouldLoadAds || _loading || _showing || _ad != null || (!bypassCooldown && _isOnCooldown)) {
      return;
    }

    _loading = true;
    InterstitialAd.load(
      adUnitId: AdConfig.interstitialUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _loading = false;
          _ad = ad;
          _wireCallbacks(ad);
        },
        onAdFailedToLoad: (error) {
          _loading = false;
          _ad = null;
          debugPrint('Interstitial failed to load: $error');
        },
      ),
    );
  }

  Future<bool> showIfAvailable({
    required String reason,
    bool bypassCooldown = false,
    bool waitForDismissal = false,
  }) async {
    if (!AdConfig.shouldLoadAds) {
      return false;
    }

    if (!bypassCooldown && _isOnCooldown) {
      unawaited(preload());
      return false;
    }

    final ad = _ad;
    if (ad == null) {
      unawaited(preload(bypassCooldown: bypassCooldown));
      return false;
    }

    _ad = null;
    _showing = true;
    _showCompleter = waitForDismissal ? Completer<void>() : null;
    debugPrint('Showing interstitial for: $reason');
    ad.show();

    if (waitForDismissal) {
      await _showCompleter!.future;
    }

    return true;
  }

  void _wireCallbacks(InterstitialAd ad) {
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (_) {
        _showing = true;
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _showing = false;
        _lastShownAt = DateTime.now();
        _showCompleter?.complete();
        _showCompleter = null;
        unawaited(preload());
      },
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _showing = false;
        _lastShownAt = DateTime.now();
        _showCompleter?.complete();
        _showCompleter = null;
        unawaited(preload());
      },
    );
  }

  void dispose() {
    _ad?.dispose();
    _ad = null;
  }
}
