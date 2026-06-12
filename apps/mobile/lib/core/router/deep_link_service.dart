import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';

/// Handles incoming deep links for both cold-start and warm-start scenarios.
///
/// - Cold start: app launched via a deep link intent.
/// - Warm start: app already running, user taps a deep link.
class DeepLinkService {
  DeepLinkService._();

  static final DeepLinkService instance = DeepLinkService._();

  final _appLinks = AppLinks();
  StreamSubscription<Uri>? _subscription;
  GoRouter? _router;

  /// Call this once after the router is ready. It will consume the initial link
  /// (cold-start) and then subscribe for subsequent links (warm-start).
  Future<void> init(GoRouter router) async {
    _router = router;
    await _handleColdStart();
    _subscribeToStream();
  }

  Future<void> _handleColdStart() async {
    try {
      final uri = await _appLinks.getInitialLink();
      if (uri != null) {
        _navigate(uri);
      }
    } catch (e) {
      debugPrint('[DeepLinkService] Cold-start error: $e');
    }
  }

  void _subscribeToStream() {
    _subscription?.cancel();
    _subscription = _appLinks.uriLinkStream.listen(
      _navigate,
      onError: (e) => debugPrint('[DeepLinkService] Stream error: $e'),
    );
  }

  void _navigate(Uri uri) {
    debugPrint('[DeepLinkService] Received URI: $uri');
    final router = _router;
    if (router == null) return;

    String? path;

    if (uri.scheme == 'vibeloop') {
      if (uri.host == 'invite') {
        // vibeloop://invite/<token>
        final token = uri.pathSegments.isNotEmpty ? uri.pathSegments.join('/') : '';
        if (token.isNotEmpty) {
          path = '/invite/$token';
        }
      } else if (uri.host == 'auth-callback') {
        path = '/auth-callback';
      }
    }

    if (path != null) {
      debugPrint('[DeepLinkService] Navigating to: $path');
      router.go(path);
    }
  }

  void dispose() {
    _subscription?.cancel();
    _subscription = null;
    _router = null;
  }
}
