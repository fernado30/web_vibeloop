import 'package:flutter/material.dart';

import '../../../core/theme/vibe_tokens.dart';
import '../../../core/utils/error_helper.dart';

class AuthScreenShell extends StatelessWidget {
  const AuthScreenShell({
    super.key,
    required this.title,
    required this.subtitle,
    required this.fields,
    this.primaryLabel,
    this.onPrimaryPressed,
    this.googleLabel,
    this.onGooglePressed,
    this.footer,
    this.errorText,
    this.primaryIcon,
    this.loading = false,
  });

  final String title;
  final String subtitle;
  final List<Widget> fields;
  final String? primaryLabel;
  final VoidCallback? onPrimaryPressed;
  final String? googleLabel;
  final VoidCallback? onGooglePressed;
  final Widget? footer;
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
                            const SizedBox(height: 4),
                            const _LogoBlock(),
                            const SizedBox(height: 20),
                            Text(
                              title,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 32,
                                height: 1.1,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.8,
                                color: VibeColors.primaryDeepBlue,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              subtitle,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 16,
                                height: 1.3,
                                fontWeight: FontWeight.w500,
                                color: VibeColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 22),
                            ..._buildFields(),
                            if (errorText != null) ...[
                              const SizedBox(height: 12),
                              _AuthErrorBanner(message: errorText!),
                            ],
                            if (primaryLabel != null) ...[
                              const SizedBox(height: 20),
                              _AuthGradientButton(
                                label: primaryLabel!,
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
                            ],
                            if (googleLabel != null) ...[
                              const SizedBox(height: 20),
                              const _AuthDivider(),
                              const SizedBox(height: 18),
                              _AuthGoogleButton(
                                label: googleLabel!,
                                onPressed: loading ? null : onGooglePressed,
                              ),
                            ],
                            if (footer != null) ...[
                              const SizedBox(height: 18),
                              footer!,
                            ],
                            const SizedBox(height: 4),
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
        widgets.add(const SizedBox(height: 12));
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
  final FocusNode _focusNode = FocusNode();
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _isObscured = widget.obscureText;
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (mounted) {
      setState(() {
        _isFocused = _focusNode.hasFocus;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final showToggle = widget.obscureText;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: _isFocused ? 0.98 : 0.92),
        borderRadius: BorderRadius.circular(26),
        boxShadow: _isFocused
            ? [
                BoxShadow(
                  color: VibeColors.primaryViolet.withValues(alpha: 0.18),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                  spreadRadius: 1,
                ),
                BoxShadow(
                  color: VibeColors.electricBlue.withValues(alpha: 0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : [
                BoxShadow(
                  color: const Color(0xFF101828).withValues(alpha: 0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: TextFormField(
        focusNode: _focusNode,
        controller: widget.controller,
        keyboardType: widget.keyboardType,
        validator: widget.validator,
        obscureText: _isObscured,
        textInputAction: widget.textInputAction,
        onFieldSubmitted: (_) => widget.onSubmitted?.call(),
        style: const TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: VibeColors.primaryDeepBlue,
        ),
        decoration: InputDecoration(
          hintText: widget.label,
          hintStyle: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w500,
            color: Color(0xFF8B93A7),
          ),
          prefixIcon: Padding(
            padding: const EdgeInsets.only(left: 20, right: 14),
            child: Icon(
              widget.icon,
              color: _isFocused ? VibeColors.primaryViolet : colorScheme.primary.withValues(alpha: 0.8),
              size: 26,
            ),
          ),
          prefixIconConstraints: const BoxConstraints(minWidth: 54, minHeight: 58),
          suffixIcon: showToggle
              ? Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: IconButton(
                    onPressed: () => setState(() => _isObscured = !_isObscured),
                    icon: Icon(
                      _isObscured ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                      color: _isObscured ? const Color(0xFF8B93A7) : VibeColors.primaryViolet,
                      size: 24,
                    ),
                  ),
                )
              : null,
          filled: true,
          fillColor: Colors.transparent,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(26),
            borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(26),
            borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(26),
            borderSide: BorderSide(color: VibeColors.primaryViolet.withValues(alpha: 0.75), width: 1.8),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(26),
            borderSide: const BorderSide(color: VibeColors.dangerRed, width: 1.4),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(26),
            borderSide: const BorderSide(color: VibeColors.dangerRed, width: 1.8),
          ),
        ),
      ),
    );
  }
}

class AuthDatePickerField extends StatelessWidget {
  const AuthDatePickerField({
    super.key,
    required this.selectedDate,
    required this.onTap,
    this.label = 'Fecha de nacimiento',
    this.subtitle = 'Solo verificamos que tengas al menos 13 años; no guardamos la fecha.',
    this.enabled = true,
  });

  final DateTime? selectedDate;
  final VoidCallback? onTap;
  final String label;
  final String subtitle;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final hasValue = selectedDate != null;
    final colorScheme = Theme.of(context).colorScheme;

    final dateText = hasValue
        ? '${selectedDate!.day.toString().padLeft(2, '0')} / ${selectedDate!.month.toString().padLeft(2, '0')} / ${selectedDate!.year}'
        : label;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: enabled ? onTap : null,
            borderRadius: BorderRadius.circular(26),
            child: Container(
              height: 58,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(26),
                border: Border.all(
                  color: hasValue ? VibeColors.primaryViolet.withValues(alpha: 0.45) : const Color(0xFFE5E7EB),
                  width: hasValue ? 1.4 : 1.0,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF101828).withValues(alpha: 0.04),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Icon(
                    Icons.cake_outlined,
                    color: hasValue ? VibeColors.primaryViolet : colorScheme.primary.withValues(alpha: 0.8),
                    size: 26,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      dateText,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: hasValue ? FontWeight.w600 : FontWeight.w500,
                        color: hasValue ? VibeColors.primaryDeepBlue : const Color(0xFF8B93A7),
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: VibeColors.primaryViolet.withValues(alpha: 0.08),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.calendar_month_rounded,
                      size: 20,
                      color: VibeColors.primaryViolet,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (subtitle.isNotEmpty) ...[
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 14),
            child: Row(
              children: [
                const Icon(
                  Icons.shield_outlined,
                  size: 14,
                  color: VibeColors.textSecondary,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: VibeColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class AuthConsentCheckbox extends StatelessWidget {
  const AuthConsentCheckbox({
    super.key,
    required this.value,
    required this.onChanged,
    required this.prefixText,
    required this.linkText,
    required this.onLinkTap,
    this.suffixText = '',
    this.enabled = true,
  });

  final bool value;
  final ValueChanged<bool?>? onChanged;
  final String prefixText;
  final String linkText;
  final VoidCallback onLinkTap;
  final String suffixText;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: enabled ? () => onChanged?.call(!value) : null,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              margin: const EdgeInsets.only(top: 2, right: 12),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: value ? VibeColors.primaryViolet : Colors.white,
                borderRadius: BorderRadius.circular(7),
                border: Border.all(
                  color: value ? VibeColors.primaryViolet : const Color(0xFFD0D5DD),
                  width: 1.8,
                ),
                boxShadow: value
                    ? [
                        BoxShadow(
                          color: VibeColors.primaryViolet.withValues(alpha: 0.3),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: value
                  ? const Icon(
                      Icons.check_rounded,
                      size: 16,
                      color: Colors.white,
                    )
                  : null,
            ),
            Expanded(
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: prefixText,
                      style: const TextStyle(
                        fontSize: 13.5,
                        height: 1.35,
                        color: VibeColors.textPrimary,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    WidgetSpan(
                      child: GestureDetector(
                        onTap: onLinkTap,
                        child: Text(
                          linkText,
                          style: const TextStyle(
                            fontSize: 13.5,
                            height: 1.35,
                            color: VibeColors.primaryViolet,
                            fontWeight: FontWeight.w700,
                            decoration: TextDecoration.underline,
                            decorationColor: VibeColors.primaryViolet,
                          ),
                        ),
                      ),
                    ),
                    if (suffixText.isNotEmpty)
                      TextSpan(
                        text: suffixText,
                        style: const TextStyle(
                          fontSize: 13.5,
                          height: 1.35,
                          color: VibeColors.textPrimary,
                          fontWeight: FontWeight.w400,
                        ),
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

class AuthAgeNoticeCard extends StatelessWidget {
  const AuthAgeNoticeCard({
    super.key,
    this.message = 'Nadie no está dirigido a menores de 13 años.',
  });

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: VibeColors.electricBlue.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: VibeColors.electricBlue.withValues(alpha: 0.18),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: VibeColors.electricBlue.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.verified_user_outlined,
              size: 18,
              color: VibeColors.electricBlue,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: VibeColors.primaryDeepBlue,
              ),
            ),
          ),
        ],
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
      fontSize: 17,
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
              fontSize: 16,
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
        width: 140,
        height: 140,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(36),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF4F7DFF).withValues(alpha: 0.18),
              blurRadius: 36,
              offset: const Offset(0, 18),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(36),
          child: Image.asset(
            'assets/icon/nadie_app_icon.png',
            fit: BoxFit.cover,
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
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
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
        borderRadius: BorderRadius.circular(26),
        boxShadow: onPressed == null
            ? const []
            : [
                BoxShadow(
                  color: const Color(0xFF6D4DFF).withValues(alpha: 0.35),
                  blurRadius: 22,
                  offset: const Offset(0, 10),
                ),
              ],
      ),
      child: FilledButton.icon(
        onPressed: onPressed,
        icon: icon ?? const SizedBox.shrink(),
        label: Text(
          label,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
          ),
        ),
        style: FilledButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(58),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
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
            margin: const EdgeInsets.only(right: 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  const Color(0xFFD0D5DD).withValues(alpha: 0.8),
                ],
              ),
            ),
          ),
        ),
        const Text(
          'o continuar con',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: VibeColors.textSecondary,
          ),
        ),
        Expanded(
          child: Container(
            height: 1,
            margin: const EdgeInsets.only(left: 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFFD0D5DD).withValues(alpha: 0.8),
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
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: const Color(0xFFE4E7EC)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF101828).withValues(alpha: 0.06),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: SizedBox(
        height: 58,
        child: FilledButton.icon(
          onPressed: onPressed,
          icon: const _GoogleMark(),
          label: Text(
            label,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: VibeColors.primaryDeepBlue,
            ),
          ),
          style: FilledButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            foregroundColor: VibeColors.primaryDeepBlue,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
            minimumSize: const Size.fromHeight(58),
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
      width: 26,
      height: 26,
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
