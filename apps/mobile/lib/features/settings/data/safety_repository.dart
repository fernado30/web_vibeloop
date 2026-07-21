import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../anonymous/domain/anonymous_message_model.dart';
import '../../chat/domain/message_model.dart';

final safetyRepositoryProvider = Provider<SafetyRepository>((ref) {
  return SafetyRepository(Supabase.instance.client);
});

/// Increments whenever a personal safety filter changes so active feeds can
/// re-apply the filter without requiring the user to leave and reopen them.
final safetyFiltersRevisionProvider = StateProvider<int>((ref) => 0);

class SafetyRepository {
  SafetyRepository(this._client);

  final SupabaseClient _client;

  SupabaseClient get _supabase => _client;

  Future<String?> _currentUserId() async {
    return _supabase.auth.currentUser?.id;
  }

  Future<List<String>> fetchHiddenWords() async {
    try {
      final userId = await _currentUserId();
      if (userId == null) return const [];

      final rows = await _supabase
          .from('user_hidden_words')
          .select('word')
          .eq('user_id', userId)
          .order('created_at', ascending: true);

      return (rows as List<dynamic>)
          .map((row) => (row as Map)['word']?.toString().trim() ?? '')
          .where((word) => word.isNotEmpty)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> addHiddenWord(String word) async {
    final userId = await _currentUserId();
    if (userId == null) {
      throw AuthException('Debes iniciar sesión para guardar palabras ocultas.');
    }

    final normalized = _normalize(word);
    if (normalized.isEmpty) return;

    await _supabase.from('user_hidden_words').upsert(
      {
        'user_id': userId,
        'word': normalized,
      },
      onConflict: 'user_id,word',
    );
  }

  Future<void> removeHiddenWord(String word) async {
    final userId = await _currentUserId();
    if (userId == null) {
      throw AuthException('Debes iniciar sesión para eliminar palabras.');
    }

    final normalized = _normalize(word);
    if (normalized.isEmpty) return;

    await _supabase.from('user_hidden_words').delete().eq('user_id', userId).eq('word', normalized);
  }

  Future<SafetyMessageFilterSettings> fetchFilterSettings() async {
    try {
      final userId = await _currentUserId();
      if (userId == null) {
        return const SafetyMessageFilterSettings();
      }

      final row = await _supabase
          .from('user_message_filter_settings')
          .select('hide_hidden_words, hide_blocked_users')
          .eq('user_id', userId)
          .maybeSingle();

      if (row == null) {
        return const SafetyMessageFilterSettings();
      }

      return SafetyMessageFilterSettings(
        hideHiddenWords: row['hide_hidden_words'] as bool? ?? true,
        hideBlockedUsers: row['hide_blocked_users'] as bool? ?? true,
      );
    } catch (_) {
      return const SafetyMessageFilterSettings();
    }
  }

  Future<void> updateFilterSettings({
    required bool hideHiddenWords,
    required bool hideBlockedUsers,
  }) async {
    final userId = await _currentUserId();
    if (userId == null) {
      throw AuthException('Debes iniciar sesión para cambiar los filtros.');
    }

    await _supabase.from('user_message_filter_settings').upsert({
      'user_id': userId,
      'hide_hidden_words': hideHiddenWords,
      'hide_blocked_users': hideBlockedUsers,
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

  Future<List<BlockedUserProfile>> fetchBlockedUsers() async {
    try {
      final userId = await _currentUserId();
      if (userId == null) return const [];

      final rows = await _supabase
          .from('user_blocked_users')
          .select('blocked_user_id')
          .eq('user_id', userId)
          .order('created_at', ascending: true);

      final blockedIds = (rows as List<dynamic>)
          .map((row) => (row as Map)['blocked_user_id']?.toString() ?? '')
          .where((id) => id.isNotEmpty)
          .toList();

      if (blockedIds.isEmpty) {
        return const [];
      }

      final usersRows = await _supabase.from('users').select('id, display_name, emoji').inFilter('id', blockedIds);
      final usersById = <String, BlockedUserProfile>{};
      for (final row in usersRows as List<dynamic>) {
        final json = Map<String, dynamic>.from(row as Map);
        final id = json['id']?.toString();
        if (id == null || id.isEmpty) continue;
        usersById[id] = BlockedUserProfile(
          id: id,
          displayName: json['display_name']?.toString(),
          emoji: json['emoji']?.toString() ?? '🙂',
        );
      }

      return blockedIds.map((id) => usersById[id]).whereType<BlockedUserProfile>().toList();
    } catch (_) {
      return const [];
    }
  }

  Future<List<BlockedUserProfile>> fetchGroupMemberProfiles() async {
    try {
      final userId = await _currentUserId();
      if (userId == null) return const [];

      final myGroupsRows = await _supabase.from('group_members').select('group_id').eq('user_id', userId);
      final groupIds = (myGroupsRows as List<dynamic>)
          .map((row) => (row as Map)['group_id']?.toString() ?? '')
          .where((id) => id.isNotEmpty)
          .toSet()
          .toList();

      if (groupIds.isEmpty) return const [];

      final memberRows = await _supabase
          .from('group_members')
          .select('user_id')
          .inFilter('group_id', groupIds);
      final memberIds = (memberRows as List<dynamic>)
          .map((row) => (row as Map)['user_id']?.toString() ?? '')
          .where((id) => id.isNotEmpty && id != userId)
          .toSet()
          .toList();

      if (memberIds.isEmpty) return const [];

      final usersRows = await _supabase.from('users').select('id, display_name, emoji').inFilter('id', memberIds);
      final profiles = <BlockedUserProfile>[];
      for (final row in usersRows as List<dynamic>) {
        final json = Map<String, dynamic>.from(row as Map);
        final id = json['id']?.toString();
        if (id == null || id.isEmpty) continue;
        profiles.add(
          BlockedUserProfile(
            id: id,
            displayName: json['display_name']?.toString(),
            emoji: json['emoji']?.toString() ?? '🙂',
          ),
        );
      }

      profiles.sort((a, b) => (a.displayName ?? a.id).compareTo(b.displayName ?? b.id));
      return profiles;
    } catch (_) {
      return const [];
    }
  }

  Future<void> blockUser(String blockedUserId) async {
    final userId = await _currentUserId();
    if (userId == null) {
      throw AuthException('Debes iniciar sesión para bloquear usuarios.');
    }

    if (blockedUserId.trim().isEmpty || blockedUserId == userId) return;

    await _supabase.from('user_blocked_users').upsert({
      'user_id': userId,
      'blocked_user_id': blockedUserId,
    }, onConflict: 'user_id,blocked_user_id');
  }

  Future<void> unblockUser(String blockedUserId) async {
    final userId = await _currentUserId();
    if (userId == null) {
      throw AuthException('Debes iniciar sesión para desbloquear usuarios.');
    }

    await _supabase
        .from('user_blocked_users')
        .delete()
        .eq('user_id', userId)
        .eq('blocked_user_id', blockedUserId);
  }

  Future<List<MessageModel>> filterMessages(List<MessageModel> messages) async {
    if (messages.isEmpty) return messages;
    try {
      final settings = await fetchFilterSettings();
      final hiddenWords = settings.hideHiddenWords ? await fetchHiddenWords() : const <String>[];
      final blockedIds = settings.hideBlockedUsers ? (await fetchBlockedUsers()).map((item) => item.id).toSet() : <String>{};

      final filtered = <MessageModel>[];
      for (final message in messages) {
        if (settings.hideBlockedUsers && blockedIds.contains(message.senderId)) {
          continue;
        }

        if (settings.hideHiddenWords && _matchesHiddenWord(message.content, hiddenWords)) {
          filtered.add(message.copyWith(content: 'Mensaje oculto por tus filtros'));
          continue;
        }

        filtered.add(message);
      }

      return filtered;
    } catch (_) {
      return messages;
    }
  }

  Future<List<AnonymousMessageModel>> filterAnonymousMessages(List<AnonymousMessageModel> messages) async {
    if (messages.isEmpty) return messages;
    try {
      final settings = await fetchFilterSettings();
      final hiddenWords = settings.hideHiddenWords ? await fetchHiddenWords() : const <String>[];

      final filtered = <AnonymousMessageModel>[];
      for (final message in messages) {
        if (settings.hideHiddenWords && _matchesHiddenWord(message.content, hiddenWords)) {
          filtered.add(message.copyWith(content: 'Mensaje oculto por tus filtros'));
          continue;
        }

        filtered.add(message);
      }

      return filtered;
    } catch (_) {
      return messages;
    }
  }

  bool _matchesHiddenWord(String content, List<String> hiddenWords) {
    final normalizedContent = _normalize(content);
    if (normalizedContent.isEmpty || hiddenWords.isEmpty) return false;

    for (final word in hiddenWords) {
      if (word.isEmpty) continue;
      if (normalizedContent.contains(word)) return true;
    }
    return false;
  }

  String _normalize(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), ' ');
  }
}

class SafetyMessageFilterSettings {
  const SafetyMessageFilterSettings({
    this.hideHiddenWords = true,
    this.hideBlockedUsers = true,
  });

  final bool hideHiddenWords;
  final bool hideBlockedUsers;
}

class BlockedUserProfile {
  const BlockedUserProfile({
    required this.id,
    required this.emoji,
    this.displayName,
  });

  final String id;
  final String emoji;
  final String? displayName;
}
