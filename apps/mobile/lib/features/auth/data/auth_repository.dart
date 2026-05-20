import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
        await _ensureProfile(
          user,
          displayName: user.userMetadata?['display_name']?.toString() ?? email.split('@').first,
        );
      }
      return response;
    });
  }

  Future<AuthResponse> signUpWithEmail({
    required String name,
    required String email,
    required String password,
  }) async {
    final functionResponse = await _supabase.functions.invoke(
      'register-user',
      body: {
        'email': email,
        'password': password,
        'displayName': name,
      },
    );

    final functionData = functionResponse.data;
    if (functionData is Map && functionData['error'] != null) {
      throw StateError(functionData['error'].toString());
    }

    final response = await _supabase.auth.signInWithPassword(
      email: email,
      password: password,
    );

    final user = response.user;
    if (user != null) {
      await _ensureProfile(user, displayName: name);
    }

    return response;
  }

  Future<void> signOut() {
    return _supabase.auth.signOut();
  }

  User? get currentUser => _supabase.auth.currentUser;

  Future<void> upsertProfile({
    required String displayName,
    String? avatarUrl,
  }) async {
    final user = currentUser;
    if (user == null) {
      throw AuthException('No hay una sesion activa.');
    }
    await _ensureProfile(
      user,
      displayName: displayName,
      avatarUrl: avatarUrl,
    );
  }

  Future<void> _ensureProfile(
    User user, {
    required String displayName,
    String? avatarUrl,
  }) async {
    final usernameBase = displayName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9_]+'), '_');
    final username = '${usernameBase}_${user.id.substring(0, 8)}';
    await _supabase.from('users').upsert({
      'id': user.id,
      'username': username,
      'display_name': displayName,
      'avatar_url': avatarUrl,
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

  Future<void> signOut() async {
    await _repository.signOut();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
