import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
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
  bool _canRequestAds = false;

  bool get isEnabled => AdConfig.isAdsEnabled;
  bool get canRequestAds => _canRequestAds;

  Future<void> initialize({bool isUnderAgeOfConsent = false}) {
    _initializing ??= _initialize(isUnderAgeOfConsent: isUnderAgeOfConsent);
    return _initializing!;
  }

  Future<void> _initialize({bool isUnderAgeOfConsent = false}) async {
    if (_initialized) return;

    if (!AdConfig.shouldLoadAds) {
      _initialized = true;
      _canRequestAds = false;
      debugPrint('AdMob disabled for this build. Using placeholders.');
      return;
    }

    if (isUnderAgeOfConsent) {
      await MobileAds.instance.updateRequestConfiguration(
        RequestConfiguration(
          tagForUnderAgeOfConsent: TagForUnderAgeOfConsent.yes,
          maxAdContentRating: MaxAdContentRating.pg,
        ),
      );
    }

    final completer = Completer<void>();
    final params = ConsentRequestParameters(
      tagForUnderAgeOfConsent: isUnderAgeOfConsent,
    );

    ConsentInformation.instance.requestConsentInfoUpdate(
      params,
      () async {
        ConsentForm.loadAndShowConsentFormIfRequired((FormError? formError) async {
          if (formError != null) {
            debugPrint('Consent form error: ${formError.message}');
          }

          final canRequest = await ConsentInformation.instance.canRequestAds();
          _canRequestAds = canRequest;

          if (canRequest) {
            await MobileAds.instance.initialize();
            _initialized = true;
            unawaited(interstitial.preload());
            unawaited(rewarded.preload());
          } else {
            debugPrint('UMP Consent not granted. Ad requests blocked.');
            _initialized = true;
          }

          if (!completer.isCompleted) completer.complete();
        });
      },
      (FormError error) async {
        debugPrint('Consent info update failed: ${error.message}');
        final canRequest = await ConsentInformation.instance.canRequestAds();
        _canRequestAds = canRequest;
        if (canRequest) {
          await MobileAds.instance.initialize();
          _initialized = true;
          unawaited(interstitial.preload());
          unawaited(rewarded.preload());
        } else {
          _initialized = true;
        }
        if (!completer.isCompleted) completer.complete();
      },
    );

    return completer.future;
  }

  Future<void> showPrivacyOptionsForm(BuildContext context) async {
    final completer = Completer<void>();
    ConsentForm.showPrivacyOptionsForm((FormError? formError) async {
      if (formError != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudieron abrir las opciones de privacidad: ${formError.message}')),
        );
      }
      final canRequest = await ConsentInformation.instance.canRequestAds();
      _canRequestAds = canRequest;
      if (!completer.isCompleted) completer.complete();
    });
    return completer.future;
  }

  Future<bool> showInterstitialAfterGroupCreated({bool waitForDismissal = false}) {
    if (!_canRequestAds) return Future.value(false);
    return interstitial.showIfAvailable(
      reason: 'group_created',
      bypassCooldown: true,
      waitForDismissal: waitForDismissal,
    );
  }

  Future<bool> showInterstitialAfterInviteShared() {
    if (!_canRequestAds) return Future.value(false);
    return interstitial.showIfAvailable(reason: 'invite_shared');
  }

  Future<bool> showRewardedForPremiumFeature({
    required String reason,
    required void Function(RewardItem reward) onUserEarnedReward,
  }) {
    if (!_canRequestAds) return Future.value(false);
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
