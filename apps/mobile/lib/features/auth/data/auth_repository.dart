import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/utils/profile_emojis.dart';
import '../domain/auth_state.dart' as local_auth;

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(Supabase.instance.client);
});

final authStateProvider = StateNotifierProvider<AuthController, local_auth.AuthState>((ref) {
  return AuthController(ref.read(authRepositoryProvider));
});

class AuthRepository {
  AuthRepository(this._client);

  final SupabaseClient _client;

  SupabaseClient get _supabase => _client;

  Stream<User?> currentUserStream() {
    return _supabase.auth.onAuthStateChange.map((event) => event.session?.user);
  }

  Future<AuthResponse> signInWithEmail({
    required String email,
    required String password,
  }) {
    return _supabase.auth.signInWithPassword(
      email: email,
      password: password,
    ).then((response) async {
      final user = response.user;
      if (user != null) {
        final existingProfile = await _supabase
            .from('users')
            .select('display_name, emoji')
            .eq('id', user.id)
            .maybeSingle();
        await _ensureProfile(
          user,
          displayName: (existingProfile?['display_name']?.toString() ??
                  user.userMetadata?['display_name']?.toString() ??
                  email.split('@').first)
              .trim(),
          emoji: existingProfile?['emoji']?.toString() ??
              user.userMetadata?['emoji']?.toString() ??
              emojiForSeed(user.id),
        );
      }
      return response;
    });
  }

  Future<AuthResponse> signUpWithEmail({
    required String name,
    required String email,
    required String password,
    String? emoji,
  }) async {
    final response = await _supabase.auth.signUp(
      email: email,
      password: password,
      data: {
        'display_name': name,
        if (emoji != null) 'emoji': emoji,
      },
    );

    final user = response.user;
    if (user != null && response.session != null) {
      await _ensureProfile(
        user,
        displayName: name,
        emoji: emoji ?? emojiForSeed(user.id),
      );
    }

    return response;
  }

  Future<AuthResponse> signInAnonymously() {
    return _supabase.auth.signInAnonymously();
  }

  Future<void> signOut() {
    return _supabase.auth.signOut();
  }

  User? get currentUser => _supabase.auth.currentUser;

  Future<void> upsertProfile({
    required String displayName,
    String? avatarUrl,
    String? emoji,
  }) async {
    final user = currentUser;
    if (user == null) {
      throw AuthException('No hay una sesion activa.');
    }
    await _ensureProfile(
      user,
      displayName: displayName,
      avatarUrl: avatarUrl,
      emoji: emoji,
    );
  }

  Future<Map<String, dynamic>?> fetchCurrentProfile() async {
    final user = currentUser;
    if (user == null) {
      return null;
    }

    return _supabase
        .from('users')
        .select('display_name, avatar_url, emoji')
        .eq('id', user.id)
        .maybeSingle();
  }

  Future<void> updateEmoji(String emoji) async {
    final user = currentUser;
    if (user == null) {
      throw AuthException('No hay una sesion activa.');
    }

    final profile = await fetchCurrentProfile();
    await _ensureProfile(
      user,
      displayName: profile?['display_name']?.toString() ??
          user.userMetadata?['display_name']?.toString() ??
          user.email?.split('@').first ??
          'user',
      avatarUrl: profile?['avatar_url']?.toString(),
      emoji: emoji,
    );
  }

  Future<void> _ensureProfile(
    User user, {
    required String displayName,
    String? avatarUrl,
    String? emoji,
  }) async {
    final usernameBase = displayName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9_]+'), '_');
    final username = '${usernameBase}_${user.id.substring(0, 8)}';
    final existingProfile = await _supabase
        .from('users')
        .select('emoji')
        .eq('id', user.id)
        .maybeSingle();
    await _supabase.from('users').upsert({
      'id': user.id,
      'username': username,
      'display_name': displayName,
      'avatar_url': avatarUrl,
      'emoji': emoji ?? existingProfile?['emoji']?.toString() ?? emojiForSeed(user.id),
    });
  }
}

class AuthController extends StateNotifier<local_auth.AuthState> {
  AuthController(this._repository) : super(const local_auth.AuthState.loading()) {
    _subscription = _repository.currentUserStream().listen(
      (user) {
        state = user == null ? const local_auth.AuthState.unauthenticated() : local_auth.AuthState.authenticated(user);
      },
      onError: (_) {
        state = const local_auth.AuthState.unauthenticated();
      },
    );
  }

  final AuthRepository _repository;
  StreamSubscription<User?>? _subscription;

  Future<void> signInWithEmail(String email, String password) async {
    await _repository.signInWithEmail(email: email, password: password);
  }

  Future<void> signUpWithEmail(String name, String email, String password) async {
    await _repository.signUpWithEmail(name: name, email: email, password: password);
  }

  Future<void> signInAnonymously() async {
    await _repository.signInAnonymously();
  }

  Future<void> signOut() async {
    await _repository.signOut();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
