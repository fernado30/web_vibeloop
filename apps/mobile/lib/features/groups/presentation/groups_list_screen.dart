import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
    final isAuthed = authState.maybeWhen(authenticated: (_) => true, orElse: () => false);

    if (!isAuthed) {
      if (!mounted) return;
      context.go('/register');
      return;
    }

    if (!mounted) return;
    context.push('/groups/create');
  }

  @override
  Widget build(BuildContext context) {
    final groupsState = ref.watch(groupsControllerProvider);
    final authState = ref.watch(authStateProvider);
    final isAuthed = authState.maybeWhen(authenticated: (_) => true, orElse: () => false);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tus grupos'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(groupsControllerProvider.notifier).loadMyGroups(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _handleCreateGroupTap,
        icon: const Icon(Icons.add),
        label: const Text('Crear grupo'),
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(groupsControllerProvider.notifier).loadMyGroups(),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: [
            _HeroSection(onCreateGroup: _handleCreateGroupTap),
            const SizedBox(height: 24),
            _FeatureGrid(),
            const SizedBox(height: 24),
            _StatsStrip(),
            const SizedBox(height: 28),
            if (isAuthed) ...[
              Text('Tus grupos', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              groupsState.when(
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 48),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (error, stack) => _StateMessage(
                  title: 'No pudimos cargar tus grupos.',
                  subtitle: '$error',
                ),
                data: (groups) {
                  if (groups.isEmpty) {
                    return _StateMessage(
                      title: 'Aún no tienes grupos.',
                      subtitle: 'Crea el primero y empieza a chatear con tu comunidad.',
                      actionLabel: 'Crear grupo',
                      onAction: _handleCreateGroupTap,
                    );
                  }

                  return Column(
                    children: groups
                        .map(
                          (group) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _GroupCard(
                              group: group,
                              onOpenChat: () => context.push('/groups/${group.id}/chat'),
                              onOpenAnonymous: () => context.push('/groups/${group.id}/anonymous'),
                            ),
                          ),
                        )
                        .toList(),
                  );
                },
              ),
            ] else ...[
              _StateMessage(
                title: 'Entra sin cuenta cuando te inviten.',
                subtitle:
                    'Si solo quieres unirte a un grupo, basta con abrir el link y subir tu foto. Regístrate solo cuando quieras crear el tuyo.',
                actionLabel: 'Crear grupo',
                onAction: _handleCreateGroupTap,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _HeroSection extends StatelessWidget {
  const _HeroSection({required this.onCreateGroup});

  final VoidCallback onCreateGroup;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A1A1A), Color(0xFF0F0F0F)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white10,
              borderRadius: BorderRadius.circular(999),
            ),
            child: const Text('Social chat groups'),
          ),
          const SizedBox(height: 16),
          Text(
            'VIBELOOP',
            style: Theme.of(context).textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          Text(
            'Crea grupos, comparte invitaciones sin cuenta y mantén el chat vivo en tiempo real.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.white70),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: const [
              _Pill(label: 'Realtime chat'),
              _Pill(label: 'Anonymous inbox'),
              _Pill(label: 'Entrada sin cuenta'),
            ],
          ),
          const SizedBox(height: 22),
          FilledButton.icon(
            onPressed: onCreateGroup,
            icon: const Icon(Icons.add),
            label: const Text('Crear grupo'),
          ),
        ],
      ),
    );
  }
}

class _FeatureGrid extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 700;
        final children = [
          _FeatureCard(
            icon: Icons.forum_outlined,
            title: 'Chat grupal',
            subtitle: 'Mensajes en tiempo real con presencia y reacciones.',
          ),
          _FeatureCard(
            icon: Icons.visibility_off_outlined,
            title: 'Mensajes anónimos',
            subtitle: 'Abre un buzón privado para feedback sin identidad visible.',
          ),
          _FeatureCard(
            icon: Icons.lock_outline,
            title: 'Entrada sin cuenta',
            subtitle: 'Los invitados abren el link, suben su foto y entran directo.',
          ),
        ];

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: children
              .map(
                (child) => SizedBox(
                  width: isWide ? (constraints.maxWidth - 24) / 3 : constraints.maxWidth,
                  child: child,
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _StatsStrip extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white10),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: const [
          _StatChip(label: 'Grupo privado'),
          _StatChip(label: 'Mensajes anónimos'),
          _StatChip(label: 'Invitaciones por link'),
        ],
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.secondary, size: 30),
          const SizedBox(height: 14),
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 6),
          Text(subtitle, style: const TextStyle(color: Colors.white70)),
        ],
      ),
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
    return Card(
      color: Theme.of(context).colorScheme.surface,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onOpenChat,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  width: 72,
                  height: 72,
                  color: Colors.white10,
                  child: group.imageUrl == null
                      ? const Icon(Icons.group, size: 32)
                      : Image.network(group.imageUrl!, fit: BoxFit.cover),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(group.name, style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 4),
                    Text(
                      group.description ?? 'Sin descripción',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _MetaChip(label: '${group.memberCount} miembros'),
                        _MetaChip(label: group.inviteCode),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                children: [
                  IconButton(
                    onPressed: onOpenChat,
                    icon: const Icon(Icons.chat_bubble_outline),
                  ),
                  IconButton(
                    onPressed: onOpenAnonymous,
                    icon: const Icon(Icons.visibility_off_outlined),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StateMessage extends StatelessWidget {
  const _StateMessage({
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(subtitle, style: const TextStyle(color: Colors.white70)),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 16),
            FilledButton(
              onPressed: onAction,
              child: Text(actionLabel!),
            ),
          ],
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 12),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 12),
      ),
    );
  }
}
