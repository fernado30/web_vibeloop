import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/vibe_ui.dart';
import '../data/safety_repository.dart';

class BlockedUsersScreen extends ConsumerStatefulWidget {
  const BlockedUsersScreen({super.key});

  @override
  ConsumerState<BlockedUsersScreen> createState() => _BlockedUsersScreenState();
}

class _BlockedUsersScreenState extends ConsumerState<BlockedUsersScreen> {
  bool _loading = true;
  List<BlockedUserProfile> _members = const [];
  Set<String> _blockedIds = const {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final repo = ref.read(safetyRepositoryProvider);
    final members = await repo.fetchGroupMemberProfiles();
    final blocked = await repo.fetchBlockedUsers();
    if (!mounted) return;
    setState(() {
      _members = members;
      _blockedIds = blocked.map((item) => item.id).toSet();
      _loading = false;
    });
  }

  Future<void> _toggleBlocked(BlockedUserProfile profile) async {
    final repo = ref.read(safetyRepositoryProvider);
    if (_blockedIds.contains(profile.id)) {
      await repo.unblockUser(profile.id);
    } else {
      await repo.blockUser(profile.id);
    }
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return VibeScaffold(
      appBar: AppBar(title: const Text('Usuarios bloqueados')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          const SectionIntroCard(
            title: 'Gestiona quien puede aparecerte en el chat',
            body: 'Bloquear a un usuario oculta sus mensajes en tu vista y ayuda a mantener el chat más cómodo.',
            badge: SafetyBadge(label: 'Control'),
          ),
          const SizedBox(height: 16),
          if (_loading)
            const LoadingStateCard(label: 'Cargando miembros...')
          else if (_members.isEmpty)
            const EmptyStateCard(
              title: 'No encontramos personas para bloquear',
              body: 'Únete a grupos o espera a que aparezcan miembros para administrar esta lista.',
            )
          else
            ..._members.map(
              (member) {
                final blocked = _blockedIds.contains(member.id);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: GlassCard(
                    borderRadius: 24,
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 22,
                          child: Text(member.emoji, style: const TextStyle(fontSize: 18)),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                member.displayName?.isNotEmpty == true ? member.displayName! : member.id,
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                blocked ? 'Bloqueado en tu vista' : 'Visible en tus grupos',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                                    ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        FilledButton.tonal(
                          onPressed: () => _toggleBlocked(member),
                          child: Text(blocked ? 'Desbloquear' : 'Bloquear'),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}
