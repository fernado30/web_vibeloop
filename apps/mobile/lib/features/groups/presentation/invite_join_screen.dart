import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth/data/auth_repository.dart';
import '../data/groups_repository.dart';
import '../domain/group_model.dart';

class InviteJoinScreen extends ConsumerStatefulWidget {
  const InviteJoinScreen({super.key, required this.inviteCode});

  final String inviteCode;

  @override
  ConsumerState<InviteJoinScreen> createState() => _InviteJoinScreenState();
}

class _InviteJoinScreenState extends ConsumerState<InviteJoinScreen> {
  final _picker = ImagePicker();
  GroupModel? _group;
  XFile? _pickedImage;
  bool _loading = true;
  bool _joining = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    try {
      final authRepo = ref.read(authRepositoryProvider);
      if (authRepo.currentUser == null) {
        await authRepo.signInAnonymously();
      }
      final group = await ref.read(groupsRepositoryProvider).getGroupByInviteCode(widget.inviteCode);
      if (mounted) {
        setState(() {
          _group = group;
        });
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

  Future<void> _pickPhoto() async {
    final image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1024,
    );
    if (image == null) return;
    setState(() {
      _pickedImage = image;
    });
  }

  Future<String> _uploadPhoto(XFile image) async {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) {
      throw AuthException('No hay una sesion activa.');
    }

    final bytes = await image.readAsBytes();
    final ext = image.name.split('.').last.toLowerCase();
    final path = '${user.id}/${DateTime.now().millisecondsSinceEpoch}.$ext';

    await client.storage.from('avatars').uploadBinary(
          path,
          Uint8List.fromList(bytes),
          fileOptions: FileOptions(
            contentType: 'image/${ext == 'png' ? 'png' : 'jpeg'}',
            upsert: true,
          ),
        );

    return client.storage.from('avatars').getPublicUrl(path);
  }

  Future<void> _join() async {
    final group = _group;
    if (group == null) return;

    setState(() {
      _joining = true;
      _error = null;
    });

    try {
      final authRepo = ref.read(authRepositoryProvider);
      if (authRepo.currentUser == null) {
        await authRepo.signInAnonymously();
      }

      String? avatarUrl;
      if (_pickedImage != null) {
        avatarUrl = await _uploadPhoto(_pickedImage!);
      }

      await authRepo.upsertProfile(
        displayName: 'Invitado',
        avatarUrl: avatarUrl,
      );

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
        setState(() => _joining = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final group = _group;

    return Scaffold(
      appBar: AppBar(title: const Text('Entrar sin cuenta')),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  if (_error != null) ...[
                    Text(_error!, style: const TextStyle(color: Colors.redAccent)),
                    const SizedBox(height: 12),
                  ],
                  Text(
                    group?.name ?? 'Invitacion no valida',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    group?.description ?? 'No necesitas registrarte. Sube una foto y entra al grupo.',
                    style: const TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 24),
                  Text('Tu foto', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text(
                    'Solo usamos tu foto para armar tu acceso temporal al grupo.',
                    style: const TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: _joining ? null : _pickPhoto,
                    child: Container(
                      height: 180,
                      decoration: BoxDecoration(
                        color: Colors.white10,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: _pickedImage == null
                          ? const Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.add_a_photo_outlined, size: 36),
                                  SizedBox(height: 8),
                                  Text('Toca para subir tu foto'),
                                ],
                              ),
                            )
                          : ClipRRect(
                              borderRadius: BorderRadius.circular(24),
                              child: Image.file(
                                File(_pickedImage!.path),
                                fit: BoxFit.cover,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: _joining ? null : _join,
                    child: Text(_joining ? 'Entrando...' : 'Entrar sin cuenta'),
                  ),
                ],
              ),
      ),
    );
  }
}
