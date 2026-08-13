import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/vibe_ui.dart';
import '../../../core/utils/string_extensions.dart';
import '../../groups/data/groups_repository.dart';

class PauseLinkScreen extends ConsumerStatefulWidget {
  const PauseLinkScreen({super.key});

  @override
  ConsumerState<PauseLinkScreen> createState() => _PauseLinkScreenState();
}

class _PauseLinkScreenState extends ConsumerState<PauseLinkScreen> {
  bool _loading = true;
  List<GroupInviteSetting> _groups = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final groups = await ref.read(groupsRepositoryProvider).fetchOwnedGroupInviteSettings();
    if (!mounted) return;
    setState(() {
      _groups = groups;
      _loading = false;
    });
  }

  Future<void> _togglePaused(GroupInviteSetting group, bool paused) async {
    await ref.read(groupsRepositoryProvider).setGroupInvitePaused(
          groupId: group.id,
          paused: paused,
        );
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return VibeScaffold(
      appBar: AppBar(title: const Text('Pausar mi enlace')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          const SectionIntroCard(
            title: 'Pausa el acceso por invitación cuando lo necesites',
            body: 'Si dejas de querer recibir nuevos miembros por enlace, puedes pausar el enlace del grupo. Los miembros actuales no se ven afectados.',
            badge: SafetyBadge(label: 'Control de invitaciones'),
          ),
          const SizedBox(height: 16),
          if (_loading)
            const LoadingStateCard(label: 'Cargando grupos...')
          else if (_groups.isEmpty)
            const EmptyStateCard(
              title: 'No tienes grupos propios para administrar',
              body: 'Crea un grupo para poder pausar o reactivar su enlace de invitación.',
            )
          else
            ..._groups.map(
              (group) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: GlassCard(
                  borderRadius: 24,
                  child: SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    value: group.invitePaused,
                    onChanged: (value) => _togglePaused(group, value),
                    title: Text(
                      group.name.toTitleCase(),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    subtitle: Text(group.invitePaused ? 'El enlace está pausado' : 'El enlace está activo'),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
