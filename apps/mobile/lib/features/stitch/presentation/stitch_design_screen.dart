import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'stitch_onboarding_flow.dart';

class StitchDesignScreen extends ConsumerStatefulWidget {
  const StitchDesignScreen({super.key});

  static const String routeName = '/stitch-design';
  static const String projectTitle = 'Diseño de Interfaz';
  static const String projectId = '13482308829084867585';
  static const String screenId = '02457901b9ed4adca136b659f29e6f4e';

  @override
  ConsumerState<StitchDesignScreen> createState() => _StitchDesignScreenState();
}

class _StitchDesignScreenState extends ConsumerState<StitchDesignScreen> {
  late final WebViewController _controller;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..addJavaScriptChannel(
        'VibeLoop',
        onMessageReceived: (message) async {
          final action = message.message.trim();
          if (action == 'continue' || action == 'explore') {
            await _continue();
          } else if (action == 'privacy') {
            await launchUrl(
              Uri.parse('https://web-vibeloop-legal-1cu5ygsqc-fernando-s-projects-4ac4887a.vercel.app/'),
              mode: LaunchMode.externalApplication,
            );
          } else if (action == 'terms') {
            await launchUrl(
              Uri.parse('https://web-vibeloop-legal-1cu5ygsqc-fernando-s-projects-4ac4887a.vercel.app/'),
              mode: LaunchMode.externalApplication,
            );
          }
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) async {
            await _injectBridge();
            if (mounted) {
              setState(() => _loaded = true);
            }
          },
        ),
      );
    _loadHtml();
  }

  Future<void> _loadHtml() async {
    final rawHtml = await rootBundle.loadString('assets/stitch/loop_onboarding.html');
    final normalizedHtml = rawHtml.replaceAll('Pol\u00c3\u00adtica', 'Política');
    await _controller.loadHtmlString(normalizedHtml);
  }

  Future<void> _injectBridge() async {
    const script = '''
      (function() {
        function bind(id, action) {
          var el = document.getElementById(id);
          if (!el) return;
          el.addEventListener('click', function(event) {
            event.preventDefault();
            if (window.VibeLoop && window.VibeLoop.postMessage) {
              window.VibeLoop.postMessage(action);
            }
          });
        }
        bind('explore-button', 'explore');
      })();
    ''';
    await _controller.runJavaScript(script);
  }

  Future<void> _continue() async {
    if (!mounted) return;
    context.go(StitchPlatformOnboardingScreen.routeName);
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarBrightness: Brightness.light,
        statusBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFF0B0A1F),
        body: Stack(
          children: [
            Positioned.fill(
              child: WebViewWidget(controller: _controller),
            ),
            if (!_loaded)
              const Positioned.fill(
                child: ColoredBox(
                  color: Color(0xFF0B0A1F),
                  child: Center(child: CircularProgressIndicator()),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
