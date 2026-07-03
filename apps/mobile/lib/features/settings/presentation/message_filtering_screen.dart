import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/vibe_ui.dart';
import '../data/safety_repository.dart';

class MessageFilteringScreen extends ConsumerStatefulWidget {
  const MessageFilteringScreen({super.key});

  @override
  ConsumerState<MessageFilteringScreen> createState() => _MessageFilteringScreenState();
}

class _MessageFilteringScreenState extends ConsumerState<MessageFilteringScreen> {
  bool _loading = true;
  bool _hideHiddenWords = true;
  bool _hideBlockedUsers = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final settings = await ref.read(safetyRepositoryProvider).fetchFilterSettings();
    if (!mounted) return;
    setState(() {
      _hideHiddenWords = settings.hideHiddenWords;
      _hideBlockedUsers = settings.hideBlockedUsers;
      _loading = false;
    });
  }

  Future<void> _save() async {
    await ref.read(safetyRepositoryProvider).updateFilterSettings(
          hideHiddenWords: _hideHiddenWords,
          hideBlockedUsers: _hideBlockedUsers,
        );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Preferencias de filtrado actualizadas')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return VibeScaffold(
      appBar: AppBar(title: const Text('Filtrado avanzado')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          const SectionIntroCard(
            title: 'Define cómo quieres ver el chat',
            body: 'Estos controles ayudan a mantener el entorno más cómodo para ti sin alterar la lógica de mensajes del grupo.',
            badge: SafetyBadge(label: 'Moderación'),
          ),
          const SizedBox(height: 16),
          if (_loading)
            const LoadingStateCard(label: 'Cargando filtros...')
          else
            GlassCard(
              child: Column(
                children: [
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    value: _hideHiddenWords,
                    onChanged: (value) => setState(() => _hideHiddenWords = value),
                    title: const Text('Ocultar mensajes con palabras filtradas'),
                    subtitle: const Text('Reemplaza los mensajes que coincidan con tu lista de palabras ocultas.'),
                  ),
                  const Divider(),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    value: _hideBlockedUsers,
                    onChanged: (value) => setState(() => _hideBlockedUsers = value),
                    title: const Text('Ocultar mensajes de usuarios bloqueados'),
                    subtitle: const Text('Elimina de tu vista los mensajes de usuarios que bloqueaste.'),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 16),
          GradientButton(
            onPressed: _loading ? null : _save,
            label: 'Guardar preferencias',
            icon: const Icon(Icons.save_outlined),
          ),
        ],
      ),
    );
  }
}
