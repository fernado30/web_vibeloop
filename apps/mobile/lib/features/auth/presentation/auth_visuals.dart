import 'package:flutter/material.dart';

import '../../../core/theme/vibe_tokens.dart';
import '../../../core/utils/error_helper.dart';

class AuthScreenShell extends StatelessWidget {
  const AuthScreenShell({
    super.key,
    required this.title,
    required this.subtitle,
    required this.fields,
    required this.primaryLabel,
    required this.onPrimaryPressed,
    required this.googleLabel,
    required this.onGooglePressed,
    required this.footer,
    this.errorText,
    this.primaryIcon,
    this.loading = false,
  });

  final String title;
  final String subtitle;
  final List<Widget> fields;
  final String primaryLabel;
  final VoidCallback? onPrimaryPressed;
  final String googleLabel;
  final VoidCallback? onGooglePressed;
  final Widget footer;
  final String? errorText;
  final Widget? primaryIcon;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          const _AuthBackdrop(),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(24, 18, 24, 24),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: constraints.maxHeight - 42),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 560),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const SizedBox(height: 8),
                            const _LogoBlock(),
                            const SizedBox(height: 30),
                            Text(
                              title,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 40,
                                height: 1.02,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -1.1,
                                color: VibeColors.primaryDeepBlue,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              subtitle,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 20,
                                height: 1.32,
                                fontWeight: FontWeight.w500,
                                color: VibeColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 34),
                            ..._buildFields(),
                            if (errorText != null) ...[
                              const SizedBox(height: 12),
                              _AuthErrorBanner(message: errorText!),
                            ],
                            const SizedBox(height: 22),
                            _AuthGradientButton(
                              label: primaryLabel,
                              icon: loading
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.1,
                                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                      ),
                                    )
                                  : primaryIcon,
                              onPressed: loading ? null : onPrimaryPressed,
                            ),
                            const SizedBox(height: 30),
                            const _AuthDivider(),
                            const SizedBox(height: 24),
                            _AuthGoogleButton(
                              label: googleLabel,
                              onPressed: loading ? null : onGooglePressed,
                            ),
                            const SizedBox(height: 28),
                            footer,
                            const SizedBox(height: 8),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildFields() {
    final widgets = <Widget>[];
    for (var i = 0; i < fields.length; i++) {
      widgets.add(fields[i]);
      if (i != fields.length - 1) {
        widgets.add(const SizedBox(height: 16));
      }
    }
    return widgets;
  }
}

class AuthTextField extends StatefulWidget {
  const AuthTextField({
    super.key,
    required this.controller,
    required this.label,
    required this.icon,
    this.keyboardType,
    this.validator,
    this.obscureText = false,
    this.textInputAction,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final bool obscureText;
  final TextInputAction? textInputAction;
  final VoidCallback? onSubmitted;

  @override
  State<AuthTextField> createState() => _AuthTextFieldState();
}

class _AuthTextFieldState extends State<AuthTextField> {
  bool _isObscured = true;

  @override
  void initState() {
    super.initState();
    _isObscured = widget.obscureText;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final showToggle = widget.obscureText;

    return TextFormField(
      controller: widget.controller,
      keyboardType: widget.keyboardType,
      validator: widget.validator,
      obscureText: _isObscured,
      textInputAction: widget.textInputAction,
      onFieldSubmitted: (_) => widget.onSubmitted?.call(),
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: VibeColors.primaryDeepBlue,
      ),
      decoration: InputDecoration(
        hintText: widget.label,
        hintStyle: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: Color(0xFF8B93A7),
        ),
        prefixIcon: Padding(
          padding: const EdgeInsets.only(left: 22, right: 14),
          child: Icon(widget.icon, color: colorScheme.primary, size: 31),
        ),
        prefixIconConstraints: const BoxConstraints(minWidth: 58, minHeight: 60),
        suffixIcon: showToggle
            ? IconButton(
                onPressed: () => setState(() => _isObscured = !_isObscured),
                icon: Icon(
                  _isObscured ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  color: const Color(0xFF8B93A7),
                  size: 27,
                ),
              )
            : null,
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.88),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: const BorderSide(color: Color(0xFFE7E9F1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: const BorderSide(color: Color(0xFFE7E9F1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: BorderSide(color: colorScheme.primary.withValues(alpha: 0.55), width: 1.4),
        ),
      ),
    );
  }
}

class AuthFooterLink extends StatelessWidget {
  const AuthFooterLink({
    super.key,
    required this.prompt,
    required this.actionLabel,
    required this.onPressed,
  });

  final String? prompt;
  final String actionLabel;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final promptText = prompt?.trim() ?? '';
    final hasPrompt = promptText.isNotEmpty;
    final actionStyle = TextStyle(
      color: Theme.of(context).colorScheme.secondary,
      fontSize: 18,
      fontWeight: FontWeight.w700,
    );

    if (!hasPrompt) {
      return Center(
        child: TextButton(
          onPressed: onPressed,
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: Text(actionLabel, style: actionStyle),
        ),
      );
    }

    return Center(
      child: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        children: [
          Text(
            promptText,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w500,
              color: VibeColors.textSecondary,
            ),
          ),
          TextButton(
            onPressed: onPressed,
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(actionLabel, style: actionStyle),
          ),
        ],
      ),
    );
  }
}

class _LogoBlock extends StatelessWidget {
  const _LogoBlock();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 164,
        height: 164,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(40),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF4F7DFF).withValues(alpha: 0.18),
              blurRadius: 42,
              offset: const Offset(0, 22),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(40),
          child: Transform.scale(
            scale: 1.34,
            child: Image.asset(
              'assets/icon/vibeloop_icon.png',
              fit: BoxFit.cover,
            ),
          ),
        ),
      ),
    );
  }
}

class _AuthBackdrop extends StatelessWidget {
  const _AuthBackdrop();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0xFFFBFBFE),
            Color(0xFFF7F8FD),
            Color(0xFFF7F4FB),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -120,
            left: -90,
            child: _GlowOrb(
              diameter: 260,
              colors: [
                const Color(0xFFB7D8FF).withValues(alpha: 0.70),
                Colors.transparent,
              ],
            ),
          ),
          Positioned(
            top: 130,
            left: -40,
            child: _GlowOrb(
              diameter: 240,
              colors: [
                const Color(0xFF9EDBFF).withValues(alpha: 0.30),
                Colors.transparent,
              ],
            ),
          ),
          Positioned(
            top: 290,
            right: -90,
            child: _GlowOrb(
              diameter: 260,
              colors: [
                const Color(0xFFE9B3F7).withValues(alpha: 0.24),
                Colors.transparent,
              ],
            ),
          ),
          Positioned(
            bottom: -100,
            left: 10,
            child: _GlowOrb(
              diameter: 300,
              colors: [
                const Color(0xFFFFC0DD).withValues(alpha: 0.22),
                Colors.transparent,
              ],
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0.0, -0.35),
                    radius: 1.15,
                    colors: [
                      Colors.white.withValues(alpha: 0.58),
                      Colors.white.withValues(alpha: 0.38),
                      Colors.white.withValues(alpha: 0.92),
                    ],
                    stops: const [0.0, 0.65, 1.0],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GlowOrb extends StatelessWidget {
  const _GlowOrb({
    required this.diameter,
    required this.colors,
  });

  final double diameter;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: diameter,
        height: diameter,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: colors),
        ),
      ),
    );
  }
}

class _AuthGradientButton extends StatelessWidget {
  const _AuthGradientButton({
    required this.label,
    required this.onPressed,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final Widget? icon;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: onPressed == null
            ? LinearGradient(
                colors: [
                  const Color(0xFF8CA7FF).withValues(alpha: 0.42),
                  const Color(0xFFE06AE0).withValues(alpha: 0.42),
                ],
              )
            : const LinearGradient(
                colors: [
                  Color(0xFF2E7DFF),
                  Color(0xFF6D4DFF),
                  Color(0xFFFF4B95),
                ],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
        borderRadius: BorderRadius.circular(30),
        boxShadow: onPressed == null
            ? const []
            : [
                BoxShadow(
                  color: const Color(0xFF5C67E8).withValues(alpha: 0.28),
                  blurRadius: 24,
                  offset: const Offset(0, 12),
                ),
              ],
      ),
      child: FilledButton.icon(
        onPressed: onPressed,
        icon: icon ?? const SizedBox.shrink(),
        label: Text(
          label,
          style: const TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
          ),
        ),
        style: FilledButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(64),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        ).copyWith(
          iconColor: const WidgetStatePropertyAll<Color>(Colors.white),
        ),
      ),
    );
  }
}

class _AuthDivider extends StatelessWidget {
  const _AuthDivider();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 1,
            margin: const EdgeInsets.only(right: 18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  const Color(0xFFCBD1E5).withValues(alpha: 0.95),
                ],
              ),
            ),
          ),
        ),
        const Text(
          'o continuar con',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w500,
            color: VibeColors.textSecondary,
          ),
        ),
        Expanded(
          child: Container(
            height: 1,
            margin: const EdgeInsets.only(left: 18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFFCBD1E5).withValues(alpha: 0.95),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _AuthGoogleButton extends StatelessWidget {
  const _AuthGoogleButton({
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFE7E9F1)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF19306C).withValues(alpha: 0.08),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: SizedBox(
        height: 66,
        child: FilledButton.icon(
          onPressed: onPressed,
          icon: const _GoogleMark(),
          label: Text(
            label,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: VibeColors.primaryDeepBlue,
            ),
          ),
          style: FilledButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            foregroundColor: VibeColors.primaryDeepBlue,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
            minimumSize: const Size.fromHeight(66),
          ).copyWith(
            iconColor: const WidgetStatePropertyAll<Color>(VibeColors.primaryDeepBlue),
          ),
        ),
      ),
    );
  }
}

class _GoogleMark extends StatelessWidget {
  const _GoogleMark();

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/icons/google_logo.png',
      width: 30,
      height: 30,
      fit: BoxFit.contain,
    );
  }
}


class _AuthErrorBanner extends StatelessWidget {
  const _AuthErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final isOffline = isNetworkError(message);
    final bgColor = isOffline ? const Color(0xFFEEF6FF) : const Color(0xFFFFEEF4);
    final borderColor = isOffline ? const Color(0xFFC6E0FF) : const Color(0xFFFFC6D9);
    final textColor = isOffline ? const Color(0xFF2E7DFF) : const Color(0xFFD63B6F);
    final displayText = isOffline ? getFriendlyNetworkError() : message;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          if (isOffline) ...[
            Icon(Icons.wifi_off_rounded, color: textColor, size: 22),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Text(
              displayText,
              style: TextStyle(
                color: textColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
