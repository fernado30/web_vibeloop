import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/backend/backend_config.dart';
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
            .select('display_name, emoji, account_status, is_under_13')
            .eq('id', user.id)
            .maybeSingle();
        if (existingProfile?['is_under_13'] == true || existingProfile?['account_status'] == 'blocked_under_13') {
          await _supabase.auth.signOut();
          throw AuthException('Esta cuenta está bloqueada por protección de menores. Solicita la eliminación de sus datos a emotivanadie@gmail.com.');
        }
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
    required DateTime birthDate,
    String? emoji,
    String? privacyPolicyVersion,
    required bool termsAccepted,
    String? termsVersion,
  }) async {
    if (!termsAccepted) {
      throw const FormatException('Debes leer y aceptar los Términos de Servicio para registrarte.');
    }
    final date = '${birthDate.year.toString().padLeft(4, '0')}-${birthDate.month.toString().padLeft(2, '0')}-${birthDate.day.toString().padLeft(2, '0')}';
    final result = await _supabase.functions.invoke('register-user', body: {
      'email': email, 'password': password, 'displayName': name, 'birthDate': date,
      'privacyPolicyVersion': privacyPolicyVersion ?? '2026-07-22',
      'termsAccepted': termsAccepted,
      'termsVersion': termsVersion ?? '2026-07-22',
    });
    if (result.status < 200 || result.status >= 300) {
      final data = result.data;
      throw AuthException(data is Map && data['error'] != null ? data['error'].toString() : 'No se pudo crear la cuenta.');
    }
    return _supabase.auth.signInWithPassword(email: email, password: password);
  }

  Future<void> recordPrivacyConsent({
    required String policyVersion,
    required User user,
    bool termsAccepted = true,
    String? termsVersion,
  }) async {
    if (!termsAccepted) {
      throw const FormatException('Debes aceptar los Términos de Servicio.');
    }
    await _ensureProfile(
      user,
      displayName: user.userMetadata?['display_name']?.toString() ?? user.email?.split('@').first ?? 'Usuario',
      privacyPolicyVersion: policyVersion,
    );
  }

  Future<AuthResponse> signInAnonymously() {
    return _supabase.auth.signInAnonymously();
  }

  Future<void> completeAgeVerification({
    required DateTime birthDate,
    required String privacyPolicyVersion,
    required String termsVersion,
    required bool termsAccepted,
  }) async {
    final user = currentUser;
    if (user == null) throw AuthException('No hay una sesion activa.');
    if (!termsAccepted) {
      throw const FormatException('Debes leer y aceptar los Términos de Servicio.');
    }
    await _ensureProfile(user, displayName: user.userMetadata?['display_name']?.toString() ?? 'Invitado', emoji: emojiForSeed(user.id));
    final date = '${birthDate.year.toString().padLeft(4, '0')}-${birthDate.month.toString().padLeft(2, '0')}-${birthDate.day.toString().padLeft(2, '0')}';
    await _supabase.rpc('complete_age_verification', params: {
      'p_birth_date': date,
      'p_privacy_policy_version': privacyPolicyVersion,
      'p_terms_accepted': termsAccepted,
      'p_terms_version': termsVersion,
    });
  }

  Future<bool> isAgeVerified() async {
    final user = currentUser;
    if (user == null) return false;

    try {
      final profile = await _supabase
          .from('users')
          .select('age_verified_13_plus, age_verified_at, account_status')
          .eq('id', user.id)
          .maybeSingle();

      if (profile == null) return false;
      final isVerified = profile['age_verified_13_plus'] == true;
      final verifiedAt = profile['age_verified_at'];
      final accountStatus = profile['account_status'];
      return isVerified && verifiedAt != null && accountStatus == 'active';
    } catch (_) {
      return false;
    }
  }

  Future<void> signOut() {
    return _supabase.auth.signOut();
  }

  Future<void> requestChildDataDeletion() async {
    final response = await _supabase.rpc('request_child_data_deletion');
    if (response == null) throw StateError('No se pudo registrar la solicitud de eliminación.');
    await signOut();
  }

  Future<void> deleteAccount({
    required String confirmationText,
  }) async {
    final user = currentUser;
    if (user == null) {
      throw AuthException('No hay una sesion activa.');
    }

    if (confirmationText.trim().toUpperCase() != 'ELIMINAR') {
      throw StateError('Debes escribir ELIMINAR para continuar.');
    }

    final backendConfig = await BackendConfig.load();
    final backendUrl = backendConfig.backendUrl;
    if (backendUrl != null) {
      final session = _supabase.auth.currentSession;
      final client = HttpClient();
      try {
        final request = await client.postUrl(Uri.parse('$backendUrl/functions/v1/delete-account'));
        request.headers.contentType = ContentType.json;
        if (session?.accessToken != null) {
          request.headers.set(HttpHeaders.authorizationHeader, 'Bearer ${session!.accessToken}');
        }
        request.write(jsonEncode({
          'confirmationText': confirmationText.trim(),
        }));

        final response = await request.close();
        final responseBody = await utf8.decoder.bind(response).join();
        Object? payload;
        if (responseBody.trim().isNotEmpty) {
          try {
            payload = jsonDecode(responseBody);
          } catch (_) {
            payload = null;
          }
        }

        if (response.statusCode < 200 || response.statusCode >= 300) {
          final message = payload is Map<String, dynamic> && payload['error'] != null
              ? payload['error'].toString()
              : 'No se pudo eliminar la cuenta de la base de datos de autenticación.';
          throw StateError(message);
        }

        await signOut();
        return;
      } finally {
        client.close(force: true);
      }
    }

    final response = await _supabase.functions.invoke(
      'delete-account',
      body: {
        'confirmationText': confirmationText.trim(),
      },
    );

    if (response.status < 200 || response.status >= 300) {
      final payload = response.data;
      final message = payload is Map<String, dynamic> && payload['error'] != null
          ? payload['error'].toString()
          : 'No se pudo eliminar la cuenta.';
      throw StateError(message);
    }

    await signOut();
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



  Future<void> _bestEffort(Future<void> Function() action) async {
    try {
      await action();
    } catch (_) {
      // Best-effort cleanup to keep the flow usable if the backend function is unavailable.
    }
  }

  Future<void> _ensureProfile(
    User user, {
    required String displayName,
    String? avatarUrl,
    String? emoji,
    String? privacyPolicyVersion,
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
      'is_under_13': false,
      if (privacyPolicyVersion != null) 'privacy_policy_version': privacyPolicyVersion,
      if (privacyPolicyVersion != null) 'privacy_consent_at': DateTime.now().toUtc().toIso8601String(),
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

  Future<void> signUpWithEmail(String name, String email, String password, DateTime birthDate, {bool termsAccepted = true}) async {
    await _repository.signUpWithEmail(name: name, email: email, password: password, birthDate: birthDate, termsAccepted: termsAccepted);
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
