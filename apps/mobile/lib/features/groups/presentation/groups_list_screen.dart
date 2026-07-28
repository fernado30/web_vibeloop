import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/vibe_tokens.dart';
import '../../../core/widgets/vibe_svg_icon.dart';
import '../../../core/widgets/vibe_ui.dart';
import '../../../core/settings/app_preferences_repository.dart';
import '../../auth/data/auth_repository.dart';
import '../data/groups_repository.dart';
import '../domain/group_model.dart';

class GroupsListScreen extends ConsumerStatefulWidget {
  const GroupsListScreen({super.key});

  @override
  ConsumerState<GroupsListScreen> createState() => _GroupsListScreenState();
}

class _GroupsListScreenState extends ConsumerState<GroupsListScreen> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(groupsControllerProvider.notifier).loadMyGroups();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _handleCreateGroupTap() async {
    final authState = ref.read(authStateProvider);
    final user = authState.maybeWhen(authenticated: (user) => user, orElse: () => null);
    final isAuthed = user != null;
    final isAnonymous = user?.isAnonymous ?? false;

    if (!isAuthed || isAnonymous) {
      if (!mounted) return;
      context.push('/login');
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
    final user = ref.watch(authStateProvider).maybeWhen(authenticated: (user) => user, orElse: () => null);
    final savedUsername = ref.watch(appPreferencesControllerProvider).username;
    final greetingName = _resolveGreetingName(user, savedUsername);

    return VibeScaffold(
      appBar: null,
      bottomNavigationBar: showEmptyState ? null : null,
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
              );
            }

            final filteredGroups = _filterGroups(groups, _query);
            final topInset = MediaQuery.of(context).padding.top;

            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(16, 18 + topInset, 16, 40 + MediaQuery.of(context).padding.bottom),
              children: [
                _GroupsRichHeader(
                  greetingName: greetingName,
                  activeCount: groups.length,
                  onRefresh: () => ref.read(groupsControllerProvider.notifier).loadMyGroups(),
                  onOpenSettings: () => context.push('/groups/settings'),
                ),
                const SizedBox(height: 18),
                _GroupsSearchField(
                  controller: _searchController,
                  onChanged: (value) => setState(() => _query = value),
                ),
                const SizedBox(height: 18),
                if (filteredGroups.isEmpty)
                  const _NoResultsGroupsView()
                else
                  for (final group in filteredGroups) ...[
                    _GroupCard(
                      group: group,
                      currentUserId: user?.id ?? '',
                      onOpenChat: () => context.push('/groups/${group.id}/chat'),
                      onOpenAnonymous: () => context.push('/groups/${group.id}/anonymous'),
                      onDeleteGroup: () => _showDeleteConfirmation(context, group),
                      ref: ref,
                    ),
                    const SizedBox(height: 12),
                  ],
                const SizedBox(height: 80),
              ],
            );
          },
        ),
      ),
    );
  }

  List<GroupModel> _filterGroups(List<GroupModel> groups, String query) {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) return groups;

    return groups.where((group) {
      return group.name.toLowerCase().contains(normalized) ||
          (group.description ?? '').toLowerCase().contains(normalized) ||
          group.inviteCode.toLowerCase().contains(normalized);
    }).toList();
  }

  String _resolveGreetingName(dynamic user, String? savedUsername) {
    // Priority 1: username chosen during onboarding
    if (savedUsername != null && savedUsername.isNotEmpty) {
      return savedUsername;
    }

    // Priority 2: display_name from auth metadata
    final displayName = user?.userMetadata?['display_name']?.toString().trim();
    if (displayName != null && displayName.isNotEmpty) {
      return displayName;
    }

    // Priority 3: derive from email
    final emailName = user?.email?.split('@').first.trim();
    if (emailName != null && emailName.isNotEmpty) {
      return emailName[0].toUpperCase() + emailName.substring(1);
    }

    return 'Nadiener';
  }

  Future<void> _showDeleteConfirmation(BuildContext context, GroupModel group) async {
    final shouldDelete = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) {
            return AlertDialog(
              title: const Text('Eliminar grupo'),
              content: Text(
                'Vas a eliminar "${group.name}".\nSe borrarán el chat, las fotos y la membresía de todos los miembros.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  style: FilledButton.styleFrom(
                    backgroundColor: VibeColors.dangerRed,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Eliminar'),
                ),
              ],
            );
          },
        ) ??
        false;

    if (!shouldDelete || !mounted) {
      return;
    }

    try {
      await ref.read(groupsRepositoryProvider).deleteGroup(group.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${group.name} fue eliminado')),
      );
      ref.read(groupsControllerProvider.notifier).loadMyGroups();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo eliminar el grupo: $error')),
      );
    }
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
  });

  final VoidCallback onCreateGroup;

  @override
  State<_EmptyGroupsView> createState() => _EmptyGroupsViewState();
}

class _EmptyGroupsViewState extends State<_EmptyGroupsView> with SingleTickerProviderStateMixin {
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
        final bottomInset = MediaQuery.of(context).padding.bottom;
        const buttonGradient = LinearGradient(
          colors: [
            Color(0xFF2E7DFF),
            Color(0xFF6D4DFF),
            Color(0xFFFF4B95),
          ],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        );

        return ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(20, 28, 20, 24 + bottomInset),
          children: [
            SizedBox(
              height: math.max(520.0, constraints.maxHeight * 0.78),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  SizedBox(height: constraints.maxHeight * 0.25),
                  Stack(
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
                  Text(
                    'Crea tu primer grupo',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFFF8FAFC) : VibeColors.textPrimary,
                          fontSize: 22,
                        ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Empieza una conversación increíble con las personas que más te importan.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFFB0BECE) : VibeColors.textSecondary,
                          fontSize: 15,
                          height: 1.38,
                        ),
                  ),
                  const Spacer(),
                  SizedBox(height: constraints.maxHeight * 0.08),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 360),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: buttonGradient,
                        borderRadius: BorderRadius.circular(32),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF5C67E8).withValues(alpha: 0.28),
                            blurRadius: 24,
                            offset: const Offset(0, 12),
                          ),
                        ],
                      ),
                      child: SizedBox(
                        width: double.infinity,
                        height: 66,
                        child: FilledButton.icon(
                          onPressed: widget.onCreateGroup,
                          icon: const Icon(Icons.add_rounded, size: 24),
                          label: const Text(
                            'Crear grupo',
                            style: TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.2,
                            ),
                          ),
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            surfaceTintColor: Colors.transparent,
                            overlayColor: Colors.transparent,
                            elevation: 0,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(32),
                            ),
                            minimumSize: const Size.fromHeight(66),
                          ).copyWith(
                            iconColor: const WidgetStatePropertyAll<Color>(Colors.white),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
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
      width: 125,
      height: 125,
    );
  }
}

class _GroupsRichHeader extends StatelessWidget {
  const _GroupsRichHeader({
    required this.greetingName,
    required this.activeCount,
    required this.onRefresh,
    required this.onOpenSettings,
  });

  final String greetingName;
  final int activeCount;
  final VoidCallback onRefresh;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDark ? const Color(0xFFF4F7FF) : VibeColors.primaryDeepBlue;
    final subtitleColor = isDark ? const Color(0xFFADB7D3) : VibeColors.textSecondary;
    final accentColor = isDark ? const Color(0xFFA855F7) : const Color(0xFF6D4CFF);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _GreetingBadge(isDark: isDark),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Hola, $greetingName 👋',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: subtitleColor,
                  height: 1.2,
                ),
              ),
            ),
            _TopCircleButton(
              iconAsset: VibeAssetIcons.refresh,
              tooltip: 'Actualizar',
              onPressed: onRefresh,
            ),
            const SizedBox(width: 12),
            _TopCircleButton(
              iconData: Icons.settings,
              tooltip: 'Ajustes',
              onPressed: onOpenSettings,
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Tus grupos',
          style: TextStyle(
            fontSize: 34,
            fontWeight: FontWeight.w800,
            height: 1.0,
            letterSpacing: -1.1,
            color: titleColor,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          '$activeCount grupos activos',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: accentColor,
            height: 1.2,
          ),
        ),
      ],
    );
  }
}

class _GroupsSearchField extends StatelessWidget {
  const _GroupsSearchField({
    required this.controller,
    required this.onChanged,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF1A2034).withValues(alpha: 0.92) : Colors.white.withValues(alpha: 0.9);
    final border = isDark ? const Color(0xFF2A3550) : const Color(0xFFE6E8F0);
    final shadow = isDark
        ? Colors.black.withValues(alpha: 0.3)
        : const Color(0xFF7680A8).withValues(alpha: 0.12);

    return Container(
      height: 54,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: border),
        boxShadow: [
          BoxShadow(
            color: shadow,
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        style: TextStyle(
          color: isDark ? const Color(0xFFF4F7FF) : VibeColors.primaryDeepBlue,
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          hintText: 'Buscar grupo...',
          hintStyle: TextStyle(
            color: isDark ? const Color(0xFF7B86A6) : const Color(0xFF8B93A7),
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
          prefixIcon: Icon(
            Icons.search_rounded,
            size: 22,
            color: isDark ? const Color(0xFF7B86A6) : const Color(0xFF7A8199),
          ),
          prefixIconConstraints: const BoxConstraints(minWidth: 52),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
        ),
      ),
    );
  }
}

class _NoResultsGroupsView extends StatelessWidget {
  const _NoResultsGroupsView();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDark ? const Color(0xFFF4F7FF) : VibeColors.primaryDeepBlue;
    final bodyColor = isDark ? const Color(0xFFADB7D3) : VibeColors.textSecondary;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF182033).withValues(alpha: 0.9) : Colors.white.withValues(alpha: 0.86),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: isDark ? const Color(0xFF2D3F5C) : const Color(0xFFE7E9F1)),
      ),
      child: Column(
        children: [
          Icon(Icons.search_off_rounded, size: 52, color: isDark ? const Color(0xFFA855F7) : const Color(0xFF6D4CFF)),
          const SizedBox(height: 14),
          Text(
            'No encontramos resultados',
            style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: titleColor),
          ),
          const SizedBox(height: 8),
          Text(
            'Prueba con otro nombre de grupo o código de invitación.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, height: 1.35, color: bodyColor),
          ),
        ],
      ),
    );
  }
}

class _GroupCard extends StatelessWidget {
  const _GroupCard({
    required this.group,
    required this.currentUserId,
    required this.onOpenChat,
    required this.onOpenAnonymous,
    required this.onDeleteGroup,
    required this.ref,
  });

  final GroupModel group;
  final String currentUserId;
  final VoidCallback onOpenChat;
  final VoidCallback onOpenAnonymous;
  final VoidCallback onDeleteGroup;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final status = _resolveStatus(group);
    final cardBg = isDark ? const Color(0xFF191D31).withValues(alpha: 0.92) : Colors.white.withValues(alpha: 0.86);
    final cardBorder = isDark ? const Color(0xFF2A3550).withValues(alpha: 0.9) : const Color(0xFFE7E9F1);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onOpenChat,
        onLongPress: onOpenAnonymous,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: isDark ? 20 : 18, sigmaY: isDark ? 20 : 18),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: cardBorder),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.30 : 0.06),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Row(
                children: [
                  _GroupPreview(imageUrl: group.imageUrl, statusColor: status.color),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          group.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            height: 1.15,
                            color: isDark ? const Color(0xFFF4F7FF) : VibeColors.primaryDeepBlue,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${group.memberCount} miembros',
                          style: TextStyle(
                            color: isDark ? const Color(0xFFADB7D3) : VibeColors.textSecondary,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 7),
                        Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: status.color,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 7),
                            Expanded(
                              child: Text(
                                status.label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: status.color,
                                  height: 1.1,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (group.createdBy == currentUserId)
                    Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: IconButton(
                        icon: Icon(
                          Icons.delete_outline_rounded,
                          color: VibeColors.dangerRed,
                          size: 22,
                        ),
                        onPressed: onDeleteGroup,
                        tooltip: 'Eliminar grupo',
                        constraints: const BoxConstraints(
                          minWidth: 40,
                          minHeight: 40,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  _GroupStatus _resolveStatus(GroupModel group) {
    final ageDays = DateTime.now().difference(group.createdAt).inDays;
    if (group.memberCount >= 25 || ageDays <= 7) {
      return const _GroupStatus('Activo ahora', Color(0xFF22C55E));
    }

    if (group.memberCount >= 12 || ageDays <= 30) {
      return const _GroupStatus('Actividad media', Color(0xFFF59E0B));
    }

    return const _GroupStatus('Sin actividad reciente', Color(0xFF8E97AE));
  }
}

class _GroupStatus {
  const _GroupStatus(this.label, this.color);

  final String label;
  final Color color;
}

class _GroupPreview extends StatelessWidget {
  const _GroupPreview({
    required this.imageUrl,
    required this.statusColor,
  });

  final String? imageUrl;
  final Color statusColor;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 74,
          height: 74,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: const LinearGradient(
              colors: [
                Color(0xFF1E6DFF),
                Color(0xFF6D4CFF),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: statusColor.withValues(alpha: 0.15),
                blurRadius: 14,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: imageUrl == null || imageUrl!.trim().isEmpty
              ? const Center(
                  child: Icon(Icons.groups_rounded, size: 30, color: Colors.white),
                )
              : Image.network(
                  imageUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return const Center(
                      child: Icon(Icons.groups_rounded, size: 30, color: Colors.white),
                    );
                  },
                ),
        ),
        Positioned(
          right: -1,
          bottom: -1,
          child: Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              color: statusColor,
              shape: BoxShape.circle,
              border: Border.all(
                color: Theme.of(context).scaffoldBackgroundColor,
                width: 2.2,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _GreetingBadge extends StatelessWidget {
  const _GreetingBadge({required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF11172A).withValues(alpha: 0.9) : Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? const Color(0xFF2B3350) : const Color(0xFFE8EAF0)),
      ),
      child: const Center(
        child: Text('👋', style: TextStyle(fontSize: 18)),
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
    final borderColor = isDark ? const Color(0xFF3A4560).withValues(alpha: 0.5) : const Color(0xFFC0C6D6).withValues(alpha: 0.28);

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
    final pillBg = isDark ? const Color(0xFF1E2D45).withValues(alpha: 0.9) : const Color(0xFFF0EDEF).withValues(alpha: 0.92);
    final pillBorder = isDark ? const Color(0xFF3A4D6A) : const Color(0xFFE4E2E4);
    final textColor = isDark ? const Color(0xFFB8C8E0) : VibeColors.primaryDeepBlue;
    final iconColor = isDark ? const Color(0xFF9BB0CC) : VibeColors.primaryDeepBlue.withValues(alpha: 0.82);

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
    final iconColor = isDark ? const Color(0xFFCBD5E1) : const Color(0xFF4B5563);
    final bgColor = isDark ? VibeColors.darkSurfaceSoft.withValues(alpha: 0.85) : const Color(0xFFF0EDEF).withValues(alpha: 0.85);
    final borderColor = isDark ? VibeColors.darkStroke : const Color(0xFFE4E2E4).withValues(alpha: 0.8);
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
