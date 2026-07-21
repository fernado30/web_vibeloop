import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/vibe_tokens.dart';
import '../../../core/widgets/vibe_ui.dart';
import '../../auth/data/auth_repository.dart';

class DeleteAccountScreen extends ConsumerStatefulWidget {
  const DeleteAccountScreen({super.key});

  @override
  ConsumerState<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends ConsumerState<DeleteAccountScreen> {
  final TextEditingController _confirmController = TextEditingController();
  bool _isDeleting = false;

  @override
  void dispose() {
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _deleteAccount() async {
    final confirm = _confirmController.text.trim();
    if (confirm.toUpperCase() != 'ELIMINAR') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Escribe ELIMINAR para continuar.')),
      );
      return;
    }

    setState(() {
      _isDeleting = true;
    });

    try {
      await ref.read(authRepositoryProvider).deleteAccount(
            confirmationText: confirm,
          );
      if (!mounted) return;
      context.go('/login');
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo eliminar la cuenta: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isDeleting = false;
        });
      }
    }
  }

  Future<void> _requestChildDeletion() async {
    try {
      await ref.read(authRepositoryProvider).requestChildDataDeletion();
      if (mounted) context.go('/login');
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No se pudo registrar la solicitud: $error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return VibeScaffold(
      appBar: AppBar(title: const Text('Eliminar cuenta')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const ModerationWarningCard(
            title: 'Salida definitiva',
            body: 'Esta acción cierra tu sesión, elimina datos asociados y mantiene la integridad de los grupos para no romper la experiencia de otros miembros.',
          ),
          const SizedBox(height: 16),
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Antes de continuar',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 12),
                const _InfoRow(icon: Icons.lock_outline_rounded, text: 'Se cerrará tu sesión en todos los dispositivos.'),
                const SizedBox(height: 10),
                const _InfoRow(icon: Icons.delete_outline_rounded, text: 'Se eliminarán fotos, notificaciones, filtros y bloqueos vinculados a tu cuenta.'),
                const SizedBox(height: 10),
                const _InfoRow(icon: Icons.people_outline_rounded, text: 'Se retirarán tus membresías y tu perfil quedará desactivado o anonimizado.'),
                const SizedBox(height: 18),
                TextField(
                  controller: _confirmController,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(labelText: 'Escribe ELIMINAR para confirmar'),
                ),
                const SizedBox(height: 16),
                FilledButton.tonal(
                  onPressed: _isDeleting ? null : _deleteAccount,
                  style: FilledButton.styleFrom(
                    backgroundColor: VibeColors.dangerRed.withValues(alpha: 0.12),
                    foregroundColor: VibeColors.dangerRed,
                    minimumSize: const Size.fromHeight(54),
                  ),
                  child: _isDeleting
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Eliminar mi cuenta'),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: _isDeleting ? null : _requestChildDeletion,
                  child: const Text('Solicitar eliminación por protección de menores'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.text,
  });

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: Theme.of(context).colorScheme.onSurfaceVariant),
        const SizedBox(width: 10),
        Expanded(child: Text(text)),
      ],
    );
  }
}
