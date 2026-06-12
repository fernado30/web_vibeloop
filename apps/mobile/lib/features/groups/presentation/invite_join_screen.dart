import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/ads/vibe_loop_banner_ad.dart';
import '../../../core/utils/profile_emojis.dart';
import '../../auth/data/auth_repository.dart';
import '../data/groups_repository.dart';

class InviteJoinScreen extends ConsumerStatefulWidget {
  const InviteJoinScreen({super.key, required this.inviteCode});

  final String inviteCode;

  @override
  ConsumerState<InviteJoinScreen> createState() => _InviteJoinScreenState();
}

class _InviteJoinScreenState extends ConsumerState<InviteJoinScreen> {
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    try {
      if (mounted) {
        setState(() => _error = null);
      }

      final authRepo = ref.read(authRepositoryProvider);
      if (authRepo.currentUser == null) {
        await _signInGuestAccount(authRepo);
      }

      final group = await ref.read(groupsRepositoryProvider).getGroupByInviteCode(widget.inviteCode);
      final invitePaused = await ref.read(groupsRepositoryProvider).isInvitePausedForCode(widget.inviteCode);
      if (invitePaused) {
        throw StateError('invite_paused');
      }
      await ref.read(groupsRepositoryProvider).joinGroup(group.id, inviteCode: widget.inviteCode);

      if (mounted) {
        context.go('/groups/${group.id}/chat');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = _friendlyError(e));
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _signInGuestAccount(AuthRepository authRepo) async {
    await authRepo.signInAnonymously();
    await authRepo.upsertProfile(
      displayName: 'Invitado',
      emoji: emojiForSeed(widget.inviteCode),
    );
  }

  String _friendlyError(Object error) {
    final message = error.toString();
    if (message.contains('anonymous_provider_disabled')) {
      return 'Activa Anonymous Sign-ins en Supabase para permitir invitados sin correo.';
    }
    if (message.contains('over_email_send_rate_limit')) {
      return 'El acceso de invitado ya no usa correo. Revisa que Anonymous Sign-ins esté activado.';
    }
    if (message.contains('invite_paused')) {
      return 'Este enlace de invitación está pausado por el creador del grupo.';
    }
    if (message.contains('rate_limited_cooldown')) {
      return 'Espera un momento antes de volver a intentar.';
    }
    if (message.contains('rate_limited')) {
      return 'Has intentado entrar demasiadas veces en poco tiempo.';
    }
    return message;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Accediendo al grupo')),
      bottomNavigationBar: const SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: VibeLoopBannerAd(),
        ),
      ),
      body: SafeArea(
        child: _loading
            ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Abriendo el chat...'),
                  ],
                ),
              )
            : Padding(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 560),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_error != null) ...[
                          Text(_error!, style: const TextStyle(color: Colors.redAccent)),
                          const SizedBox(height: 16),
                          FilledButton(
                            onPressed: () => _bootstrap(),
                            child: const Text('Reintentar'),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}
