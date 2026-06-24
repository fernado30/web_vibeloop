import 'dart:ui';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../../core/ads/vibe_loop_banner_ad.dart';
import '../../../core/theme/vibe_tokens.dart';
import '../../../core/widgets/vibe_svg_icon.dart';
import '../../../core/widgets/vibe_ui.dart';
import '../../auth/data/auth_repository.dart';
import '../data/groups_repository.dart';
import '../domain/group_model.dart';

class GroupsListScreen extends ConsumerStatefulWidget {
  const GroupsListScreen({super.key});

  @override
  ConsumerState<GroupsListScreen> createState() => _GroupsListScreenState();
}

class _GroupsListScreenState extends ConsumerState<GroupsListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(groupsControllerProvider.notifier).loadMyGroups();
    });
  }

  Future<void> _handleCreateGroupTap() async {
    final authState = ref.read(authStateProvider);
    final user = authState.maybeWhen(authenticated: (user) => user, orElse: () => null);
    final isAuthed = user != null;
    final isAnonymous = user?.isAnonymous ?? false;

    if (!isAuthed || isAnonymous) {
      if (!mounted) return;
      context.go('/login');
      return;
    }

    if (!mounted) return;
    context.push('/groups/create');
  }

  @override
  Widget build(BuildContext context) {
    final groupsState = ref.watch(groupsControllerProvider);
    final groups = groupsState.maybeWhen(data: (groups) => groups, orElse: () => null);
    final showEmptyState = groups != null && groups.isEmpty;

    return VibeScaffold(
      appBar: showEmptyState
          ? null
          : _GroupsTopBar(
              onRefresh: () => ref.read(groupsControllerProvider.notifier).loadMyGroups(),
              onOpenSettings: () => context.push('/groups/settings'),
            ),
      bottomNavigationBar: showEmptyState ? null : const GlassBottomNavigation(child: VibeLoopBannerAd()),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: showEmptyState
          ? null
          : Padding(
              padding: const EdgeInsets.only(bottom: 76),
              child: FloatingCreateButton(
                onPressed: _handleCreateGroupTap,
                tooltip: 'Crear grupo',
              ),
            ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(groupsControllerProvider.notifier).loadMyGroups(),
        child: groupsState.when(
          loading: () => const _LoadingGroupsView(),
          error: (error, stack) => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
            children: [
              ErrorStateCard(
                title: 'No pudimos cargar tus grupos',
                body: '$error',
                onRetry: () => ref.read(groupsControllerProvider.notifier).loadMyGroups(),
              ),
            ],
          ),
          data: (groups) {
            if (groups.isEmpty) {
              return _EmptyGroupsView(
                onCreateGroup: _handleCreateGroupTap,
                onOpenSettings: () => context.push('/groups/settings'),
                onRefresh: () => ref.read(groupsControllerProvider.notifier).loadMyGroups(),
              );
            }

            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
              children: [
                for (final group in groups) ...[
                  _GroupCard(
                    group: group,
                    onOpenChat: () => context.push('/groups/${group.id}/chat'),
                    onOpenAnonymous: () => context.push('/groups/${group.id}/anonymous'),
                  ),
                  const SizedBox(height: 12),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _LoadingGroupsView extends StatelessWidget {
  const _LoadingGroupsView();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
      children: const [
        LoadingStateCard(label: 'Cargando tus grupos...'),
      ],
    );
  }
}

class _EmptyGroupsView extends StatefulWidget {
  const _EmptyGroupsView({
    required this.onCreateGroup,
    required this.onOpenSettings,
    required this.onRefresh,
  });

  final VoidCallback onCreateGroup;
  final VoidCallback onOpenSettings;
  final VoidCallback onRefresh;

  @override
  State<_EmptyGroupsView> createState() => _EmptyGroupsViewState();
}

class _EmptyGroupsViewState extends State<_EmptyGroupsView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 48, 20, 24),
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Tus grupos',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? const Color(0xFFF8FAFC)
                            : VibeColors.textPrimary,
                      ),
                ),
                Row(
                  children: [
                    _TopCircleButton(
                      iconAsset: VibeAssetIcons.refresh,
                      tooltip: 'Actualizar',
                      onPressed: widget.onRefresh,
                    ),
                    const SizedBox(width: 12),
                    _TopCircleButton(
                      iconData: Icons.settings,
                      tooltip: 'Ajustes',
                      onPressed: widget.onOpenSettings,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: constraints.maxHeight > 620 ? constraints.maxHeight - 260 : 400,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 24),
                    child: Stack(
                      alignment: Alignment.center,
                      clipBehavior: Clip.none,
                      children: [
                        Positioned(
                          top: -16,
                          left: -14,
                          child: _MiniSpark(size: 24, color: const Color(0xFFDDD6FE)),
                        ),
                        Positioned(
                          top: -10,
                          right: -18,
                          child: _MiniSpark(size: 20, color: const Color(0xFFDDD6FE)),
                        ),
                        Positioned(
                          bottom: -12,
                          right: -14,
                          child: _MiniSpark(size: 16, color: const Color(0xFFDDD6FE)),
                        ),
                        AnimatedBuilder(
                          animation: _controller,
                          builder: (context, child) {
                            final floatOffset = math.sin(_controller.value * math.pi * 2) * 8;
                            final pulse = 0.98 + (_controller.value * 0.04);
                            return Transform.translate(
                              offset: Offset(0, floatOffset),
                              child: Transform.scale(scale: pulse, child: child),
                            );
                          },
                          child: const _PeopleGroupIcon(),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    'Crea tu primer grupo',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: Theme.of(context).brightness == Brightness.dark
                              ? const Color(0xFFF8FAFC)
                              : VibeColors.textPrimary,
                          fontSize: 20,
                        ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Empieza una conversación increíble con las personas que más te importan.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? const Color(0xFFB0BECE)
                              : VibeColors.textSecondary,
                          fontSize: 14,
                          height: 1.35,
                        ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Builder(
              builder: (context) {
                final isDark = Theme.of(context).brightness == Brightness.dark;
                final bottomInset = MediaQuery.of(context).padding.bottom;
                return Container(
                  decoration: BoxDecoration(
                    color: isDark
                        ? VibeColors.darkSurfaceSoft.withValues(alpha: 0.96)
                        : Colors.white.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(32),
                    border: Border.all(
                      color: isDark
                          ? VibeColors.darkStroke
                          : const Color(0xFFF3F4F6),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.04),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  padding: EdgeInsets.fromLTRB(16, 18, 16, 18 + bottomInset),
                  child: Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 48,
                          child: ElevatedButton.icon(
                            onPressed: widget.onCreateGroup,
                            icon: const Icon(Icons.add_rounded, size: 20),
                            label: const Text('Crear grupo'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF6366F1),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(24),
                              ),
                              textStyle: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: SizedBox(
                          height: 48,
                          child: OutlinedButton.icon(
                            onPressed: widget.onOpenSettings,
                            icon: const Icon(Icons.settings, size: 20),
                            label: const Text('Ajustes'),
                            style: OutlinedButton.styleFrom(
                              backgroundColor: isDark
                                  ? VibeColors.darkSurface
                                  : Colors.white,
                              foregroundColor: isDark
                                  ? const Color(0xFFCBD5E1)
                                  : const Color(0xFF334155),
                              side: BorderSide(
                                color: isDark
                                    ? VibeColors.darkStroke
                                    : const Color(0xFFE5E7EB),
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(24),
                              ),
                              textStyle: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }
}

class _MiniSpark extends StatelessWidget {
  const _MiniSpark({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }
}

class _PeopleGroupIcon extends StatelessWidget {
  const _PeopleGroupIcon();

  @override
  Widget build(BuildContext context) {
    return SvgPicture.string(
      '''<svg viewBox="0 0 100 100" fill="none" xmlns="http://www.w3.org/2000/svg">
        <defs>
          <linearGradient id="people-gradient" x1="0%" y1="0%" x2="100%" y2="100%">
            <stop offset="0%" stop-color="#6366f1"/>
            <stop offset="100%" stop-color="#a855f7"/>
          </linearGradient>
        </defs>
        <circle cx="30" cy="45" r="10" fill="url(#people-gradient)" opacity="0.7"/>
        <path d="M15 75C15 65 20 60 30 60C40 60 45 65 45 75" stroke="url(#people-gradient)" stroke-width="8" stroke-linecap="round" opacity="0.7" fill="none"/>
        <circle cx="70" cy="45" r="10" fill="url(#people-gradient)" opacity="0.7"/>
        <path d="M55 75C55 65 60 60 70 60C80 60 85 65 85 75" stroke="url(#people-gradient)" stroke-width="8" stroke-linecap="round" opacity="0.7" fill="none"/>
        <circle cx="50" cy="35" r="12" fill="url(#people-gradient)"/>
        <path d="M30 75C30 62 38 55 50 55C62 55 70 62 70 75" stroke="url(#people-gradient)" stroke-width="10" stroke-linecap="round" fill="none"/>
      </svg>''',
      width: 96,
      height: 96,
    );
  }
}

class _GroupCard extends StatelessWidget {
  const _GroupCard({
    required this.group,
    required this.onOpenChat,
    required this.onOpenAnonymous,
  });

  final GroupModel group;
  final VoidCallback onOpenChat;
  final VoidCallback onOpenAnonymous;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark
        ? const Color(0xFF182033).withValues(alpha: 0.85)
        : Colors.white.withValues(alpha: 0.72);
    final cardBorder = isDark
        ? const Color(0xFF2D3F5C).withValues(alpha: 0.7)
        : Colors.white.withValues(alpha: 0.55);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onOpenChat,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: cardBorder),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.22 : 0.06),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                children: [
                  _GroupAvatar(imageUrl: group.imageUrl),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          group.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            height: 1.15,
                            color: isDark ? const Color(0xFFF0F4FF) : VibeColors.textPrimary,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          group.description?.trim().isNotEmpty == true ? group.description! : 'Sin descripcion',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: colorScheme.onSurfaceVariant.withValues(alpha: 0.78),
                            fontSize: 15,
                            fontWeight: FontWeight.w400,
                            height: 1.35,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _GroupMetaPill(label: '${group.memberCount} miembros'),
                            _GroupMetaPill(label: group.inviteCode, icon: Icons.link_rounded),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _GroupActionButton(
                        icon: Icons.chat_bubble_outline_rounded,
                        onPressed: onOpenChat,
                      ),
                      const SizedBox(height: 14),
                      _GroupActionButton(
                        icon: Icons.visibility_off_outlined,
                        onPressed: onOpenAnonymous,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GroupsTopBar extends StatelessWidget implements PreferredSizeWidget {
  const _GroupsTopBar({
    required this.onRefresh,
    required this.onOpenSettings,
  });

  final VoidCallback onRefresh;
  final VoidCallback onOpenSettings;

  @override
  Size get preferredSize => const Size.fromHeight(76);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scaffoldColor = Theme.of(context).scaffoldBackgroundColor;
    final titleColor = isDark ? const Color(0xFFF0F4FF) : VibeColors.textPrimary;
    final borderColor = isDark
        ? const Color(0xFF3A4560).withValues(alpha: 0.5)
        : const Color(0xFFC0C6D6).withValues(alpha: 0.28);

    // Hace que la status bar sea transparente y sus iconos se adapten al tema
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: isDark
          ? SystemUiOverlayStyle.light.copyWith(
              statusBarColor: Colors.transparent,
              statusBarBrightness: Brightness.dark,
              statusBarIconBrightness: Brightness.light,
            )
          : SystemUiOverlayStyle.dark.copyWith(
              statusBarColor: Colors.transparent,
              statusBarBrightness: Brightness.light,
              statusBarIconBrightness: Brightness.dark,
            ),
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
          child: Container(
            decoration: BoxDecoration(
              // Se integra con el fondo del scaffold en lugar de usar blanco fijo
              color: scaffoldColor.withValues(alpha: isDark ? 0.82 : 0.82),
              border: Border(
                bottom: BorderSide(color: borderColor),
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Tus grupos',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.3,
                          color: titleColor,
                        ),
                      ),
                    ),
                    _TopCircleButton(
                      iconAsset: VibeAssetIcons.refresh,
                      tooltip: 'Actualizar',
                      onPressed: onRefresh,
                    ),
                    const SizedBox(width: 10),
                    _TopCircleButton(
                      iconData: Icons.settings_outlined,
                      tooltip: 'Ajustes',
                      onPressed: onOpenSettings,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GroupAvatar extends StatelessWidget {
  const _GroupAvatar({this.imageUrl});

  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: VibeGradients.cyanViolet,
        boxShadow: [
          BoxShadow(
            color: VibeColors.primaryViolet.withValues(alpha: 0.12),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: imageUrl == null
          ? const Icon(Icons.groups_rounded, size: 26, color: Colors.white)
          : Image.network(
              imageUrl!,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return const Icon(Icons.groups_rounded, size: 26, color: Colors.white);
              },
            ),
    );
  }
}

class _GroupMetaPill extends StatelessWidget {
  const _GroupMetaPill({
    required this.label,
    this.icon,
  });

  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pillBg = isDark
        ? const Color(0xFF1E2D45).withValues(alpha: 0.9)
        : const Color(0xFFF0EDEF).withValues(alpha: 0.92);
    final pillBorder = isDark
        ? const Color(0xFF3A4D6A)
        : const Color(0xFFE4E2E4);
    final textColor = isDark
        ? const Color(0xFFB8C8E0)
        : VibeColors.primaryDeepBlue;
    final iconColor = isDark
        ? const Color(0xFF9BB0CC)
        : VibeColors.primaryDeepBlue.withValues(alpha: 0.82);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: pillBg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: pillBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 15, color: iconColor),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: TextStyle(
              color: textColor,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}

class _GroupActionButton extends StatelessWidget {
  const _GroupActionButton({
    required this.icon,
    required this.onPressed,
  });

  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: 36,
      height: 36,
      child: IconButton(
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints.tightFor(width: 36, height: 36),
        splashRadius: 18,
        visualDensity: VisualDensity.compact,
        onPressed: onPressed,
        icon: Icon(
          icon,
          size: 22,
          color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
        ),
      ),
    );
  }
}

class _TopCircleButton extends StatelessWidget {
  const _TopCircleButton({
    this.iconAsset,
    this.iconData,
    required this.onPressed,
    this.tooltip,
  }) : assert(iconAsset != null || iconData != null, 'TopCircleButton requires an icon asset or icon data.');

  final String? iconAsset;
  final IconData? iconData;
  final VoidCallback onPressed;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final iconColor = isDark
        ? const Color(0xFFCBD5E1)
        : const Color(0xFF4B5563);
    final bgColor = isDark
        ? VibeColors.darkSurfaceSoft.withValues(alpha: 0.85)
        : const Color(0xFFF0EDEF).withValues(alpha: 0.85);
    final borderColor = isDark
        ? VibeColors.darkStroke
        : const Color(0xFFE4E2E4).withValues(alpha: 0.8);
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkResponse(
          onTap: onPressed,
          radius: 24,
          borderRadius: BorderRadius.circular(999),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: bgColor,
              shape: BoxShape.circle,
              border: Border.all(color: borderColor),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.24 : 0.06),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Center(
              child: iconData != null
                  ? Icon(
                      iconData,
                      size: 18,
                      color: iconColor,
                    )
                  : VibeSvgIcon(
                      iconAsset!,
                      size: 18,
                      color: iconColor,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

