import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'ad_config.dart';

class VibeLoopBannerAd extends StatefulWidget {
  const VibeLoopBannerAd({
    super.key,
    this.placeholderLabel = 'Espacio publicitario',
  });

  final String placeholderLabel;

  @override
  State<VibeLoopBannerAd> createState() => _VibeLoopBannerAdState();
}

class _VibeLoopBannerAdState extends State<VibeLoopBannerAd> {
  BannerAd? _bannerAd;
  AdSize? _adSize;
  int? _lastRequestedWidth;
  bool _loading = false;

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  Future<void> _loadBanner(int width) async {
    if (!mounted || !AdConfig.shouldLoadBannerAds || width <= 0) {
      return;
    }

    if (_loading || (_lastRequestedWidth == width && _bannerAd != null)) {
      return;
    }

    _lastRequestedWidth = width;
    _loading = true;

    final size = await AdSize.getLargeAnchoredAdaptiveBannerAdSize(width);
    if (!mounted) return;

    _bannerAd?.dispose();
    _bannerAd = null;
    _adSize = null;

    if (size == null) {
      setState(() {
        _lastRequestedWidth = null;
        _loading = false;
      });
      return;
    }

    final ad = BannerAd(
      adUnitId: AdConfig.bannerUnitId,
      size: size,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (!mounted) {
            ad.dispose();
            return;
          }
          setState(() {
            _bannerAd = ad as BannerAd;
            _adSize = size;
            _loading = false;
          });
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          if (!mounted) return;
          setState(() {
            _lastRequestedWidth = null;
            _bannerAd = null;
            _adSize = null;
            _loading = false;
          });
        },
      ),
    );

    ad.load();
  }

  Widget _buildPlaceholder(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 64),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.campaign_outlined, size: 18, color: theme.colorScheme.primary.withValues(alpha: 0.75)),
          const SizedBox(width: 8),
          Text(
            widget.placeholderLabel,
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.truncate();
        if (AdConfig.shouldLoadBannerAds && width > 0 && _lastRequestedWidth != width && !_loading) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _loadBanner(width);
            }
          });
        }

        final adWidth = _adSize?.width.toDouble();
        final adHeight = _adSize?.height.toDouble();
        final showAd = _bannerAd != null && adHeight != null;
        final child = showAd
            ? Center(
                child: SizedBox(
                  width: adWidth,
                  height: adHeight,
                  child: AdWidget(ad: _bannerAd!),
                ),
              )
            : _buildPlaceholder(context);

        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: SizedBox(
            key: ValueKey(showAd ? 'ad' : 'placeholder-${AdConfig.shouldLoadBannerAds}'),
            width: double.infinity,
            height: showAd ? adHeight : 64,
            child: Center(child: child),
          ),
        );
      },
    );
  }
}
