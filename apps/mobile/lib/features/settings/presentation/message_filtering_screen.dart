import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text('Filtrado avanzado de mensajes'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          const _IntroCard(
            title: 'Define cómo quieres ver el chat',
            body:
                'Esta sección controla cómo VIBELOOP oculta contenido sensible o mensajes de personas que ya bloqueaste. Tus cambios afectan el chat y el buzón anónimo cuando la app vuelve a cargar los mensajes.',
          ),
          const SizedBox(height: 16),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator()),
            )
          else
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.78),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Column(
                children: [
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    value: _hideHiddenWords,
                    onChanged: (value) => setState(() => _hideHiddenWords = value),
                    title: const Text('Ocultar mensajes con palabras filtradas'),
                    subtitle: const Text('Reemplaza los mensajes que coincidan con tu lista de palabras ocultas.'),
                  ),
                  const Divider(height: 1),
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
          FilledButton.icon(
            onPressed: _loading ? null : _save,
            icon: const Icon(Icons.save_outlined),
            label: const Text('Guardar preferencias'),
          ),
        ],
      ),
    );
  }
}

class _IntroCard extends StatelessWidget {
  const _IntroCard({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF111827),
                ),
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: const TextStyle(
              height: 1.45,
              color: Color(0xFF4B5563),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
