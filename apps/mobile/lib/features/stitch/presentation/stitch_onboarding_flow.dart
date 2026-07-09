import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/settings/app_preferences_repository.dart';
import '../../../core/theme/vibe_tokens.dart';

class StitchPlatformOnboardingScreen extends ConsumerStatefulWidget {
  const StitchPlatformOnboardingScreen({super.key});

  static const String routeName = '/onboarding/platform';

  @override
  ConsumerState<StitchPlatformOnboardingScreen> createState() => _StitchPlatformOnboardingScreenState();
}

class _StitchPlatformOnboardingScreenState extends ConsumerState<StitchPlatformOnboardingScreen> {
  _PlatformChoice _selectedChoice = _PlatformChoice.instagram;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  void _continue() {
    context.go(StitchUsernameOnboardingScreen.routeName);
  }


  @override
  Widget build(BuildContext context) {
    return OnboardingShell(
      backgroundSeed: 1,
      child: SafeArea(
        bottom: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight - MediaQuery.paddingOf(context).top),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 36),
                    _GradientHeadline(
                      firstLine: '¿Dónde quieres',
                      secondLine: 'utilizar ',
                      gradientWord: 'Vibeloop',
                      trailing: '?',
                    ),
                    const SizedBox(height: 14),
                    const _BodyCopy(
                      'Elige la plataforma donde quieres recibir mensajes.',
                      align: TextAlign.center,
                      width: 300,
                    ),
                    const SizedBox(height: 24),
                    _PlatformCard(
                      icon: const _InstagramMark(size: 50),
                      label: 'Instagram',
                      selected: _selectedChoice == _PlatformChoice.instagram,
                      onTap: () => setState(() => _selectedChoice = _PlatformChoice.instagram),
                    ),
                    const SizedBox(height: 18),
                    _PlatformCard(
                      icon: const _WhatsAppMark(size: 50),
                      label: 'WhatsApp',
                      selected: _selectedChoice == _PlatformChoice.whatsapp,
                      onTap: () => setState(() => _selectedChoice = _PlatformChoice.whatsapp),
                    ),
                    const SizedBox(height: 24),
                    _GradientActionButton(
                      label: 'Continuar',
                      onPressed: _continue,
                      icon: Icons.arrow_forward_ios_rounded,
                    ),
                    const SizedBox(height: 18),
                    const _PrivacyNote(
                      leading: 'Tu privacidad es nuestra prioridad.',
                      trailing: 'Conoce nuestra ',
                      highlighted: 'Política de privacidad.',
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class StitchUsernameOnboardingScreen extends ConsumerStatefulWidget {
  const StitchUsernameOnboardingScreen({super.key});

  static const String routeName = '/onboarding/username';

  @override
  ConsumerState<StitchUsernameOnboardingScreen> createState() => _StitchUsernameOnboardingScreenState();
}

class _StitchUsernameOnboardingScreenState extends ConsumerState<StitchUsernameOnboardingScreen> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _controller = TextEditingController();
    _focusNode = FocusNode();
  }

  void _continue() async {
    final username = _controller.text.trim();
    if (username.isEmpty) {
      _focusNode.requestFocus();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Escribe un nombre de usuario para continuar.')),
      );
      return;
    }

    await ref.read(appPreferencesControllerProvider.notifier).saveUsername(username);
    await ref.read(appPreferencesControllerProvider.notifier).markOnboardingSeen();
    if (!mounted) return;
    context.go('/groups');
  }


  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return OnboardingShell(
      backgroundSeed: 2,
      child: SafeArea(
        bottom: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight - MediaQuery.paddingOf(context).top),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 22),
                    const _UserIllustration(),
                    const SizedBox(height: 18),
                    _GradientHeadline(
                      firstLine: 'Elige tu nombre',
                      secondLine: 'de ',
                      gradientWord: 'usuario',
                      trailing: '',
                    ),
                    const SizedBox(height: 14),
                    const _BodyCopy(
                      'Este será tu alias en el grupo.\nPuedes cambiarlo después.',
                      align: TextAlign.center,
                      width: 300,
                    ),
                    const SizedBox(height: 24),
                    _UsernameField(
                      controller: _controller,
                      focusNode: _focusNode,
                    ),
                    const SizedBox(height: 22),
                    _GradientActionButton(
                      label: 'Continuar',
                      onPressed: _continue,
                      icon: Icons.arrow_forward_ios_rounded,
                    ),
                    const SizedBox(height: 24),
                    const _PrivacyNote(
                      leading: 'Al continuar, aceptas nuestras',
                      trailing: '',
                      highlighted: 'Condiciones y Política de privacidad.',
                      centerTopPadding: 0,
                    ),
                    const SizedBox(height: 14),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

enum _PlatformChoice { instagram, whatsapp }

class OnboardingShell extends StatelessWidget {
  const OnboardingShell({
    super.key,
    required this.child,
    required this.backgroundSeed,
  });

  final Widget child;
  final int backgroundSeed;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        systemNavigationBarColor: isDark ? const Color(0xFF070714) : const Color(0xFFF2F4F8),
        systemNavigationBarDividerColor: Colors.transparent,
        systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: isDark ? const Color(0xFF070714) : const Color(0xFFF2F4F8),
        body: Stack(
          children: [
            Positioned.fill(child: _OnboardingBackdrop(seed: backgroundSeed)),
            Positioned.fill(child: child),
          ],
        ),
      ),
    );
  }
}

class _OnboardingBackdrop extends StatelessWidget {
  const _OnboardingBackdrop({required this.seed});

  final int seed;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: const Alignment(0, -0.52),
          radius: 1.15,
          colors: isDark
              ? const [
                  Color(0xFF15123E),
                  Color(0xFF090816),
                ]
              : const [
                  Color(0xFFE8EBFC),
                  Color(0xFFF2F4F8),
                ],
          stops: const [0.0, 1.0],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: 110,
            left: 54 + (seed * 3),
            child: _GlowOrb(
              size: 26,
              color: isDark
                  ? const Color(0xFF8C5CFF).withValues(alpha: 0.35)
                  : const Color(0xFF8C5CFF).withValues(alpha: 0.12),
              blur: 22,
            ),
          ),
          Positioned(
            top: 170,
            right: 110,
            child: _GlowOrb(
              size: 18,
              color: isDark
                  ? const Color(0xFFFF55C8).withValues(alpha: 0.65)
                  : const Color(0xFFFF55C8).withValues(alpha: 0.15),
              blur: 18,
            ),
          ),
          Positioned(
            top: 260,
            left: 104,
            child: _GlowOrb(
              size: 10,
              color: isDark
                  ? const Color(0xFF7F51FF).withValues(alpha: 0.85)
                  : const Color(0xFF7F51FF).withValues(alpha: 0.18),
              blur: 10,
            ),
          ),
          Positioned(
            top: 220,
            right: 76,
            child: _GlowOrb(
              size: 12,
              color: isDark
                  ? const Color(0xFF79A5FF).withValues(alpha: 0.82)
                  : const Color(0xFF79A5FF).withValues(alpha: 0.18),
              blur: 10,
            ),
          ),
          Positioned(
            left: -80,
            right: -80,
            bottom: seed == 1 ? -220 : -160,
            child: const _FaintNebula(),
          ),
          Positioned.fill(
            child: CustomPaint(
              painter: _StarfieldPainter(seed: seed, isDark: isDark),
            ),
          ),
        ],
      ),
    );
  }
}

class _StarfieldPainter extends CustomPainter {
  const _StarfieldPainter({required this.seed, required this.isDark});

  final int seed;
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    if (!isDark) return;
    final paint = Paint()..style = PaintingStyle.fill;
    final stars = seed == 1
        ? const <_StarDot>[
            _StarDot(0.18, 0.28, 1.6, Color(0xFF8A4CFF), 0.85),
            _StarDot(0.39, 0.20, 2.0, Color(0xFFFF66C9), 0.82),
            _StarDot(0.66, 0.16, 2.2, Color(0xFF9163FF), 0.92),
            _StarDot(0.23, 0.38, 1.2, Color(0xFF7AB3FF), 0.62),
            _StarDot(0.80, 0.34, 1.6, Color(0xFF8A4CFF), 0.72),
            _StarDot(0.30, 0.66, 1.6, Color(0xFFFFFFFF), 0.50),
          ]
        : const <_StarDot>[
            _StarDot(0.22, 0.34, 2.4, Color(0xFF73B1FF), 0.95),
            _StarDot(0.39, 0.71, 1.9, Color(0xFFFFFFFF), 0.56),
            _StarDot(0.60, 0.48, 1.6, Color(0xFFFF5AD2), 0.80),
            _StarDot(0.71, 0.58, 2.0, Color(0xFF8A4CFF), 0.86),
            _StarDot(0.83, 0.29, 2.3, Color(0xFFFF5AD2), 0.94),
            _StarDot(0.26, 0.53, 1.2, Color(0xFFFFFFFF), 0.52),
          ];

    for (final star in stars) {
      final offset = Offset(size.width * star.dx, size.height * star.dy);
      paint.color = star.color.withValues(alpha: star.opacity);
      canvas.drawCircle(offset, star.radius, paint);
      canvas.drawCircle(
        offset,
        star.radius * 2.4,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.5
          ..color = star.color.withValues(alpha: star.opacity * 0.26),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _StarfieldPainter oldDelegate) =>
      oldDelegate.seed != seed || oldDelegate.isDark != isDark;
}

class _StarDot {
  const _StarDot(this.dx, this.dy, this.radius, this.color, this.opacity);

  final double dx;
  final double dy;
  final double radius;
  final Color color;
  final double opacity;
}

class _FaintNebula extends StatelessWidget {
  const _FaintNebula();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return IgnorePointer(
      child: Center(
        child: Container(
          width: 360,
          height: 180,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(180),
            gradient: RadialGradient(
              colors: isDark
                  ? const [
                      Color(0x802B72FF),
                      Color(0x402A13A5),
                      Colors.transparent,
                    ]
                  : const [
                      Color(0x202B72FF),
                      Color(0x102A13A5),
                      Colors.transparent,
                    ],
              stops: const [0.0, 0.42, 1.0],
            ),
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? const Color(0xFFB94BFF).withValues(alpha: 0.32)
                    : const Color(0xFFB94BFF).withValues(alpha: 0.12),
                blurRadius: 80,
                spreadRadius: 10,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UserIllustration extends StatelessWidget {
  const _UserIllustration();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      width: 140,
      height: 140,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const SweepGradient(
                colors: [
                  Color(0xFF3B7CFF),
                  Color(0xFF6B49FF),
                  Color(0xFFF75BC5),
                  Color(0xFF3B7CFF),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF7A41FF).withValues(alpha: isDark ? 0.35 : 0.15),
                  blurRadius: 18,
                ),
              ],
            ),
          ),
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isDark ? const Color(0xFF090816) : Colors.white,
            ),
          ),
          Icon(
            Icons.person_outline_rounded,
            color: isDark ? Colors.white : VibeColors.primaryViolet,
            size: 48,
          ),
          Positioned(
            left: 22,
            top: 60,
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF8F63FF),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF8F63FF).withValues(alpha: 0.9),
                    blurRadius: 10,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GradientHeadline extends StatelessWidget {
  const _GradientHeadline({
    required this.firstLine,
    required this.secondLine,
    required this.gradientWord,
    required this.trailing,
  });

  final String firstLine;
  final String secondLine;
  final String gradientWord;
  final String trailing;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final style = TextStyle(
      color: isDark ? Colors.white : VibeColors.textPrimary,
      fontSize: 32,
      height: 1.1,
      fontWeight: FontWeight.w800,
      letterSpacing: -1.0,
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(firstLine, textAlign: TextAlign.center, style: style),
        const SizedBox(height: 4),
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 0,
          children: [
            Text(secondLine, style: style),
            _GradientText(
              gradientWord,
              style: style,
              colors: const [Color(0xFF7F5BFF), Color(0xFFFF51C8)],
            ),
            Text(trailing, style: style),
          ],
        ),
      ],
    );
  }
}

class _GradientText extends StatelessWidget {
  const _GradientText(
    this.text, {
    required this.style,
    required this.colors,
  });

  final String text;
  final TextStyle style;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (bounds) => LinearGradient(
        colors: colors,
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
      ).createShader(bounds),
      child: Text(
        text,
        style: style.copyWith(color: Colors.white),
      ),
    );
  }
}

class _BodyCopy extends StatelessWidget {
  const _BodyCopy(
    this.text, {
    required this.align,
    required this.width,
  });

  final String text;
  final TextAlign align;
  final double width;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      width: width,
      child: Text(
        text,
        textAlign: align,
        style: TextStyle(
          color: isDark ? Colors.white.withValues(alpha: 0.62) : VibeColors.textSecondary,
          fontSize: 18,
          height: 1.45,
          fontWeight: FontWeight.w400,
          letterSpacing: -0.2,
        ),
      ),
    );
  }
}

class _PlatformCard extends StatelessWidget {
  const _PlatformCard({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final Widget icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderGradient = selected
        ? const LinearGradient(
            colors: [Color(0xFFBB63FF), Color(0xFFFF59D5)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          )
        : (isDark
            ? const LinearGradient(
                colors: [Color(0xFF36345F), Color(0xFF282648)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              )
            : const LinearGradient(
                colors: [Color(0xFFE2E4EC), Color(0xFFEDEFF5)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ));

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 104,
        decoration: BoxDecoration(
          gradient: borderGradient,
          borderRadius: BorderRadius.circular(32),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: isDark
                        ? const Color(0xFF7A41FF).withValues(alpha: 0.3)
                        : const Color(0xFF7A41FF).withValues(alpha: 0.15),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ]
              : [
                  if (!isDark)
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(2),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF141227) : Colors.white,
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                  color: isDark
                      ? Colors.black.withValues(alpha: 0.22)
                      : Colors.black.withValues(alpha: 0.02),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Row(
                children: [
                  _PlatformIconShell(selected: selected, child: icon),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        color: isDark ? Colors.white : VibeColors.textPrimary,
                        fontSize: 20,
                        height: 1.0,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.6,
                      ),
                    ),
                  ),
                  _PlatformCheck(selected: selected),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PlatformIconShell extends StatelessWidget {
  const _PlatformIconShell({
    required this.selected,
    required this.child,
  });

  final bool selected;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 58,
      height: 58,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: selected ? const Color(0xFFB44DFF).withValues(alpha: 0.22) : Colors.transparent,
            blurRadius: 14,
          ),
        ],
      ),
      child: child,
    );
  }
}

class _PlatformCheck extends StatelessWidget {
  const _PlatformCheck({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (selected) {
      return Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            colors: [Color(0xFF7F5BFF), Color(0xFFB94BFF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFB44DFF).withValues(alpha: 0.5),
              blurRadius: 18,
            ),
          ],
        ),
        child: const Icon(Icons.check_rounded, color: Colors.white, size: 32),
      );
    }

    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: isDark ? const Color(0xFF4A476F) : const Color(0xFFD0D5DD),
          width: 3,
        ),
      ),
    );
  }
}

class _InstagramMark extends StatelessWidget {
  const _InstagramMark({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.27),
        gradient: const LinearGradient(
          colors: [
            Color(0xFFFEDA75),
            Color(0xFFFA7E1E),
            Color(0xFFD62976),
            Color(0xFF962FBF),
            Color(0xFF4F5BD5),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Container(
          width: size * 0.54,
          height: size * 0.54,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(size * 0.16),
            border: Border.all(color: Colors.white, width: size * 0.10),
          ),
          child: Center(
            child: Container(
              width: size * 0.22,
              height: size * 0.22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: size * 0.10),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _WhatsAppMark extends StatelessWidget {
  const _WhatsAppMark({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFF25D366),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF25D366).withValues(alpha: 0.28),
            blurRadius: 12,
          ),
        ],
      ),
      child: Center(
        child: Container(
          width: size * 0.63,
          height: size * 0.63,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(size * 0.18),
            border: Border.all(color: Colors.white, width: size * 0.08),
          ),
          child: Stack(
            children: [
              Positioned(
                left: size * 0.13,
                top: size * 0.16,
                child: Transform.rotate(
                  angle: -0.65,
                  child: Container(
                    width: size * 0.18,
                    height: size * 0.12,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(size * 0.06),
                    ),
                  ),
                ),
              ),
              Positioned(
                right: size * 0.15,
                bottom: size * 0.15,
                child: Transform.rotate(
                  angle: -0.65,
                  child: Container(
                    width: size * 0.16,
                    height: size * 0.11,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(size * 0.06),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GradientActionButton extends StatelessWidget {
  const _GradientActionButton({
    required this.label,
    required this.onPressed,
    required this.icon,
  });

  final String label;
  final VoidCallback onPressed;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        height: 80,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(38),
          gradient: const LinearGradient(
            colors: [Color(0xFF6747FF), Color(0xFF7F5BFF), Color(0xFFFF4BB0)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF8B5BFF).withValues(alpha: isDark ? 0.42 : 0.22),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.6,
                ),
              ),
              const SizedBox(width: 10),
              Icon(icon, color: Colors.white, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _PrivacyNote extends StatelessWidget {
  const _PrivacyNote({
    required this.leading,
    required this.trailing,
    required this.highlighted,
    this.centerTopPadding = 0,
  });

  final String leading;
  final String trailing;
  final String highlighted;
  final double centerTopPadding;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseStyle = TextStyle(
      color: isDark ? Colors.white.withValues(alpha: 0.62) : VibeColors.textSecondary,
      fontSize: 17,
      height: 1.35,
      fontWeight: FontWeight.w500,
      letterSpacing: -0.2,
    );

    return Column(
      children: [
        Padding(
          padding: EdgeInsets.only(top: centerTopPadding),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock_outline_rounded, color: Color(0xFFB055FF), size: 24),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  leading,
                  textAlign: TextAlign.center,
                  style: baseStyle,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(trailing, textAlign: TextAlign.center, style: baseStyle),
            _GradientText(
              highlighted,
              style: baseStyle.copyWith(fontWeight: FontWeight.w700),
              colors: const [Color(0xFF7287FF), Color(0xFFB055FF), Color(0xFFFF55C8)],
            ),
          ],
        ),
      ],
    );
  }
}


class _UsernameField extends StatelessWidget {
  const _UsernameField({
    required this.controller,
    required this.focusNode,
  });

  final TextEditingController controller;
  final FocusNode focusNode;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      height: 92,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF457BFF), Color(0xFF8B50FF), Color(0xFFFF4BC7)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(34),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF5D68FF).withValues(alpha: isDark ? 0.25 : 0.10),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF151227) : Colors.white,
                borderRadius: BorderRadius.circular(32),
              ),
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                cursorColor: isDark ? Colors.white : VibeColors.primaryViolet,
                style: TextStyle(
                  color: isDark ? Colors.white : VibeColors.textPrimary,
                  fontSize: 19,
                  fontWeight: FontWeight.w500,
                  letterSpacing: -0.3,
                ),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 28),
                  prefixIcon: Padding(
                    padding: const EdgeInsets.only(left: 20, right: 14),
                    child: ShaderMask(
                      shaderCallback: (bounds) => const LinearGradient(
                        colors: [Color(0xFF7A5BFF), Color(0xFFFF55D6)],
                      ).createShader(bounds),
                      child: const Icon(Icons.alternate_email_rounded, color: Colors.white, size: 34),
                    ),
                  ),
                  prefixIconConstraints: const BoxConstraints(minWidth: 54, minHeight: 54),
                  hintText: 'Tu nombre de usuario',
                  hintStyle: TextStyle(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.48)
                        : const Color(0xFF98A2B3),
                    fontSize: 23,
                    fontWeight: FontWeight.w400,
                    letterSpacing: -0.3,
                  ),
                ),
              ),
            ),
            Positioned(
              top: -5,
              right: 8,
              child: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFFF4DD1),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF4DD1).withValues(alpha: 0.9),
                      blurRadius: 12,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


class _GlowOrb extends StatelessWidget {
  const _GlowOrb({
    required this.size,
    required this.color,
    required this.blur,
  });

  final double size;
  final Color color;
  final double blur;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
          boxShadow: [
            BoxShadow(
              color: color,
              blurRadius: blur,
              spreadRadius: 1,
            ),
          ],
        ),
      ),
    );
  }
}
