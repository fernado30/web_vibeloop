import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
      await ref.read(groupsRepositoryProvider).joinGroup(group.id);

      if (mounted) {
        context.go('/groups/${group.id}/chat');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _signInGuestAccount(AuthRepository authRepo) async {
    final safeCode = widget.inviteCode.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toLowerCase();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final guestEmail = 'guest-$safeCode-$timestamp@example.com';
    final guestPassword = 'guest-${timestamp}-${widget.inviteCode.hashCode.abs()}';

    await authRepo.signUpWithEmail(
      name: 'Invitado',
      email: guestEmail,
      password: guestPassword,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Accediendo al grupo')),
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
