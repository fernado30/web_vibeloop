import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/vibe_tokens.dart';
import '../utils/error_helper.dart';

class VibeBackdrop extends StatelessWidget {
  const VibeBackdrop({super.key, this.child});

  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final base = isDark ? VibeColors.darkSurface : VibeColors.surfaceSoft;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: base,
        gradient: LinearGradient(
          colors: [
            base,
            isDark ? const Color(0xFF101A30) : const Color(0xFFFDFDFF),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            top: -80,
            left: -40,
            child: _orb(
              colors: isDark
                  ? [VibeColors.primaryViolet.withValues(alpha: 0.22), Colors.transparent]
                  : [VibeColors.cyan.withValues(alpha: 0.18), Colors.transparent],
              size: 220,
            ),
          ),
          Positioned(
            top: 120,
            right: -30,
            child: _orb(
              colors: isDark
                  ? [VibeColors.coralPink.withValues(alpha: 0.18), Colors.transparent]
                  : [VibeColors.primaryViolet.withValues(alpha: 0.16), Colors.transparent],
              size: 240,
            ),
          ),
          Positioned(
            bottom: -80,
            left: 20,
            child: _orb(
              colors: isDark
                  ? [VibeColors.electricBlue.withValues(alpha: 0.18), Colors.transparent]
                  : [VibeColors.softPink.withValues(alpha: 0.22), Colors.transparent],
              size: 260,
            ),
          ),
          if (child != null) child!,
        ],
      ),
    );
  }

  Widget _orb({required List<Color> colors, required double size}) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: colors),
        ),
      ),
    );
  }
}

class VibeScaffold extends StatelessWidget {
  const VibeScaffold({
    super.key,
    this.appBar,
    required this.body,
    this.floatingActionButton,
    this.floatingActionButtonLocation,
    this.bottomNavigationBar,
  });

  final PreferredSizeWidget? appBar;
  final Widget body;
  final Widget? floatingActionButton;
  final FloatingActionButtonLocation? floatingActionButtonLocation;
  final Widget? bottomNavigationBar;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      appBar: appBar,
      floatingActionButton: floatingActionButton,
      floatingActionButtonLocation: floatingActionButtonLocation,
      bottomNavigationBar: bottomNavigationBar,
      body: Stack(
        children: [
          const Positioned.fill(child: VibeBackdrop()),
          Positioned.fill(child: body),
        ],
      ),
    );
  }
}

class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.borderRadius = VibeRadii.card,
    this.blur = 10,
    this.color,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final double blur;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fill = color ??
        (isDark
            ? VibeColors.darkSurfaceSoft.withValues(alpha: 0.84)
            : VibeColors.glassWhite);
    final stroke = isDark ? VibeColors.darkStroke : VibeColors.strokeSoft.withValues(alpha: 0.8);

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(color: stroke),
            boxShadow: VibeShadows.soft,
          ),
          child: child,
        ),
      ),
    );
  }
}

class GradientHeroCard extends StatelessWidget {
  const GradientHeroCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(24),
    this.gradient = VibeGradients.hero,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Gradient gradient;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(VibeRadii.card + 2),
        boxShadow: VibeShadows.soft,
      ),
      child: child,
    );
  }
}

class GradientButton extends StatelessWidget {
  const GradientButton({
    super.key,
    required this.onPressed,
    required this.label,
    this.icon,
  });

  final VoidCallback? onPressed;
  final String label;
  final Widget? icon;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: onPressed == null
            ? LinearGradient(
                colors: [
                  Colors.grey.withValues(alpha: 0.35),
                  Colors.grey.withValues(alpha: 0.25),
                ],
              )
            : VibeGradients.hero,
        borderRadius: BorderRadius.circular(VibeRadii.button),
        boxShadow: onPressed == null ? const [] : VibeShadows.soft,
      ),
      child: FilledButton.icon(
        onPressed: onPressed,
        icon: icon ?? const SizedBox.shrink(),
        label: Text(label),
        style: FilledButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(56),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(VibeRadii.button),
          ),
        ).copyWith(
          iconColor: const WidgetStatePropertyAll<Color>(Colors.white),
        ),
      ),
    );
  }
}

class QuickActionPill extends StatelessWidget {
  const QuickActionPill({
    super.key,
    required this.label,
    this.icon,
    this.onTap,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(VibeRadii.pill),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: colorScheme.primary.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(VibeRadii.pill),
            border: Border.all(color: colorScheme.primary.withValues(alpha: 0.12)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 16, color: colorScheme.primary),
                const SizedBox(width: 8),
              ],
              Text(
                label,
                style: TextStyle(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SafetyBadge extends StatelessWidget {
  const SafetyBadge({
    super.key,
    required this.label,
    this.color = VibeColors.successGreen,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(VibeRadii.pill),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class EmptyStateCard extends StatelessWidget {
  const EmptyStateCard({
    super.key,
    required this.title,
    required this.body,
    this.action,
  });

  final String title;
  final String body;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text(body, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: VibeColors.textSecondary)),
          if (action != null) ...[
            const SizedBox(height: 16),
            action!,
          ],
        ],
      ),
    );
  }
}

class LoadingStateCard extends StatelessWidget {
  const LoadingStateCard({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Row(
        children: [
          const SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2.2),
          ),
          const SizedBox(width: 14),
          Expanded(child: Text(label)),
        ],
      ),
    );
  }
}

class ErrorStateCard extends StatelessWidget {
  const ErrorStateCard({
    super.key,
    required this.title,
    required this.body,
    this.onRetry,
  });

  final String title;
  final String body;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final isOffline = isNetworkError(body);
    final cardColor = isOffline
        ? VibeColors.electricBlue.withValues(alpha: 0.08)
        : VibeColors.coralPink.withValues(alpha: 0.10);
    final titleColor = isOffline ? VibeColors.electricBlue : VibeColors.dangerRed;
    final iconData = isOffline ? Icons.wifi_off_rounded : Icons.error_outline_rounded;

    String displayBody = body;
    if (isOffline) {
      final titleLower = title.toLowerCase();
      if (titleLower.contains('grupos')) {
        displayBody = getFriendlyNetworkError(actionContext: 'cargar tus grupos');
      } else if (titleLower.contains('acceder') || titleLower.contains('entrar') || titleLower.contains('unir')) {
        displayBody = getFriendlyNetworkError(actionContext: 'acceder al grupo');
      } else {
        displayBody = getFriendlyNetworkError();
      }
    }

    return GlassCard(
      color: cardColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                iconData,
                color: titleColor,
                size: 26,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: titleColor,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            displayBody,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFFADB7D3)
                      : VibeColors.textSecondary,
                ),
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: onRetry,
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: titleColor.withValues(alpha: 0.4)),
                foregroundColor: titleColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(VibeRadii.button),
                ),
              ),
              child: const Text('Reintentar'),
            ),
          ],
        ],
      ),
    );
  }
}

class SectionIntroCard extends StatelessWidget {
  const SectionIntroCard({
    super.key,
    required this.title,
    required this.body,
    this.badge,
  });

  final String title;
  final String body;
  final Widget? badge;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (badge != null) ...[badge!, const SizedBox(height: 12)],
          Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text(body, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: VibeColors.textSecondary)),
        ],
      ),
    );
  }
}

class ShareLinkCard extends StatelessWidget {
  const ShareLinkCard({
    super.key,
    required this.link,
    required this.onCopy,
    this.onShare,
  });

  final String link;
  final VoidCallback onCopy;
  final VoidCallback? onShare;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const SafetyBadge(label: 'Enlace'),
              const Spacer(),
              if (onShare != null)
                IconButton(
                  onPressed: onShare,
                  icon: const Icon(Icons.ios_share_rounded),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            link,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onCopy,
                  icon: const Icon(Icons.copy_rounded),
                  label: const Text('Copiar'),
                ),
              ),
              if (onShare != null) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: GradientButton(
                    onPressed: onShare,
                    label: 'Compartir',
                    icon: const Icon(Icons.send_rounded),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class FloatingCreateButton extends StatelessWidget {
  const FloatingCreateButton({
    super.key,
    required this.onPressed,
    this.tooltip,
  });

  final VoidCallback onPressed;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: VibeGradients.hero,
        shape: BoxShape.circle,
        boxShadow: VibeShadows.soft,
      ),
      child: FloatingActionButton(
        heroTag: 'groups-create-fab',
        tooltip: tooltip,
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        onPressed: onPressed,
        shape: const CircleBorder(),
        child: const Icon(Icons.add, size: 28),
      ),
    );
  }
}

class GlassBottomNavigation extends StatelessWidget {
  const GlassBottomNavigation({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
        child: GlassCard(
          borderRadius: VibeRadii.navigation,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: child,
        ),
      ),
    );
  }
}

class StoryPreviewCard extends StatelessWidget {
  const StoryPreviewCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: VibeGradients.story,
        borderRadius: BorderRadius.circular(VibeRadii.card),
        boxShadow: VibeShadows.soft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.white, size: 26),
          const SizedBox(height: 24),
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.86),
                ),
          ),
        ],
      ),
    );
  }
}

class ModerationWarningCard extends StatelessWidget {
  const ModerationWarningCard({
    super.key,
    required this.title,
    required this.body,
  });

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      color: VibeColors.warningAmber.withValues(alpha: 0.10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.shield_outlined, color: VibeColors.warningAmber),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Text(body),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ReactionBar extends StatelessWidget {
  const ReactionBar({
    super.key,
    required this.reactions,
    this.isMine = false,
  });

  final Map<String, int> reactions;
  final bool isMine;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: reactions.entries
            .map(
              (entry) => Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                  decoration: BoxDecoration(
                    color: isMine ? Colors.white.withValues(alpha: 0.16) : colorScheme.primary.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(VibeRadii.pill),
                  ),
                  child: Text(
                    '${entry.key} ${entry.value}',
                    style: TextStyle(
                      color: isMine ? Colors.white : colorScheme.onSurfaceVariant,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      height: 1,
                    ),
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

class AvatarStack extends StatelessWidget {
  const AvatarStack({
    super.key,
    required this.emojis,
  });

  final List<String> emojis;

  @override
  Widget build(BuildContext context) {
    final preview = emojis.take(3).toList();
    return SizedBox(
      height: 28,
      width: 28 + ((preview.length - 1).clamp(0, 2) * 18),
      child: Stack(
        children: [
          for (var i = 0; i < preview.length; i++)
            Positioned(
              left: i * 18,
              child: CircleAvatar(
                radius: 14,
                backgroundColor: Theme.of(context).colorScheme.surface,
                child: Text(preview[i], style: const TextStyle(fontSize: 14)),
              ),
            ),
        ],
      ),
    );
  }
}

class AnonymousMessageCard extends StatelessWidget {
  const AnonymousMessageCard({
    super.key,
    required this.content,
    required this.reactions,
  });

  final String content;
  final Map<String, int> reactions;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              SafetyBadge(label: 'Anónimo', color: VibeColors.coralPink),
            ],
          ),
          const SizedBox(height: 12),
          Text(content, style: Theme.of(context).textTheme.bodyLarge),
          if (reactions.isNotEmpty) ...[
            const SizedBox(height: 12),
            ReactionBar(reactions: reactions),
          ],
        ],
      ),
    );
  }
}

class MessageThreadPreview extends StatelessWidget {
  const MessageThreadPreview({
    super.key,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(VibeRadii.cardSmall),
        onTap: onTap,
        child: GlassCard(
          borderRadius: VibeRadii.cardSmall,
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: VibeGradients.cyanViolet,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.forum_outlined, color: Colors.white),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    Text(subtitle, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: VibeColors.textSecondary)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}
