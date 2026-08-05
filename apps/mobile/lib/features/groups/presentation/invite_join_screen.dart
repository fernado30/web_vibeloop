import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/utils/profile_emojis.dart';
import '../../auth/data/auth_repository.dart';
import '../data/groups_repository.dart';
import '../../../core/widgets/vibe_ui.dart';
import '../../../core/utils/error_helper.dart';
import '../../../core/theme/vibe_tokens.dart';
import '../../stitch/presentation/stitch_onboarding_flow.dart';
import '../../auth/domain/age_eligibility.dart';

class InviteJoinScreen extends ConsumerStatefulWidget {
  const InviteJoinScreen({super.key, required this.inviteCode});

  final String inviteCode;

  @override
  ConsumerState<InviteJoinScreen> createState() => _InviteJoinScreenState();
}

class _InviteJoinScreenState extends ConsumerState<InviteJoinScreen> {
  static const _privacyPolicyVersion = '2026-07-22';
  static const _termsVersion = '2026-07-22';
  static final _privacyUrl = Uri.parse('https://web-legal-nadie.vercel.app/privacy');
  static final _termsUrl = Uri.parse('https://web-legal-nadie.vercel.app/terms');
  bool _loading = false;
  bool _confirmed13Plus = false;
  bool _privacyAccepted = false;
  bool _termsAccepted = false;
  DateTime? _birthDate;
  String? _error;

  Future<void> _bootstrap() async {
    if (_birthDate == null) { setState(() => _error = 'Selecciona tu fecha de nacimiento.'); return; }
    if (!_confirmed13Plus) { setState(() => _error = 'Debes confirmar que tienes 13 años o más.'); return; }
    if (!_privacyAccepted) { setState(() => _error = 'Debes autorizar el tratamiento de tus datos personales.'); return; }
    if (!_termsAccepted) { setState(() => _error = 'Debes leer y aceptar expresamente los Términos de Servicio.'); return; }
    if (isUnder13(_birthDate!)) { setState(() => _error = ageGateMessage()); return; }
    try {
      if (mounted) {
        setState(() { _error = null; _loading = true; });
      }

      final authRepo = ref.read(authRepositoryProvider);
      if (authRepo.currentUser == null) {
        await _signInGuestAccount(authRepo);
      }
      await authRepo.completeAgeVerification(
        birthDate: _birthDate!,
        privacyPolicyVersion: _privacyPolicyVersion,
        termsVersion: _termsVersion,
        termsAccepted: _termsAccepted,
      );

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
    if (isNetworkError(error)) {
      return getFriendlyNetworkError(actionContext: 'acceder al grupo');
    }
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return OnboardingShell(
      backgroundSeed: 3,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Center(
              child: _loading
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const CircularProgressIndicator(
                          color: VibeColors.primaryViolet,
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Abriendo el chat...',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : VibeColors.textPrimary,
                          ),
                        ),
                      ],
                    )
                  : ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 560),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Antes de entrar', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 12),
                          const Text('Usamos tu fecha únicamente para verificar que cumples la edad mínima. No la guardamos.'),
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.cake_outlined),
                            title: Text(_birthDate == null ? 'Fecha de nacimiento' : 'Fecha de nacimiento: ${_birthDate!.day}/${_birthDate!.month}/${_birthDate!.year}'),
                            onTap: () async {
                              final date = await showDatePicker(context: context, firstDate: DateTime(1900), lastDate: DateTime.now(), initialDate: _birthDate ?? DateTime(DateTime.now().year - 13));
                              if (date != null && mounted) setState(() => _birthDate = date);
                            },
                          ),
                          CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            controlAffinity: ListTileControlAffinity.leading,
                            value: _confirmed13Plus,
                            onChanged: (value) => setState(() => _confirmed13Plus = value ?? false),
                            title: const Text('Confirmo que tengo 13 años o más.'),
                          ),
                          CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            controlAffinity: ListTileControlAffinity.leading,
                            value: _privacyAccepted,
                            onChanged: (value) => setState(() => _privacyAccepted = value ?? false),
                            title: Wrap(
                              children: [
                                const Text('Autorizo el tratamiento de mis datos personales según la '),
                                GestureDetector(
                                  onTap: () => launchUrl(_privacyUrl, mode: LaunchMode.externalApplication),
                                  child: const Text(
                                    'Política de Privacidad',
                                    style: TextStyle(decoration: TextDecoration.underline, fontWeight: FontWeight.w700),
                                  ),
                                ),
                                const Text('.'),
                              ],
                            ),
                          ),
                          CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            controlAffinity: ListTileControlAffinity.leading,
                            value: _termsAccepted,
                            onChanged: (value) => setState(() => _termsAccepted = value ?? false),
                            title: Wrap(
                              children: [
                                const Text('He leído y acepto expresamente los '),
                                GestureDetector(
                                  onTap: () => launchUrl(_termsUrl, mode: LaunchMode.externalApplication),
                                  child: const Text(
                                    'Términos de Servicio',
                                    style: TextStyle(decoration: TextDecoration.underline, fontWeight: FontWeight.w700),
                                  ),
                                ),
                                const Text(' de Nadie.'),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          FilledButton(onPressed: _bootstrap, child: const Text('Entrar al grupo')),
                          if (_error != null) ...[
                            const SizedBox(height: 16),
                            ErrorStateCard(
                              title: 'No pudimos acceder al grupo',
                              body: _error!,
                              onRetry: () => _bootstrap(),
                            ),
                          ],
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
