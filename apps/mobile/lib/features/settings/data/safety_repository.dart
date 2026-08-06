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

  static List<String>? _cachedHiddenWords;
  static Set<String>? _cachedBlockedIds;
  static SafetyMessageFilterSettings? _cachedSettings;

  Future<String?> _currentUserId() async {
    return _supabase.auth.currentUser?.id;
  }

  Future<bool> isCurrentUserAdmin() async {
    try {
      final userId = await _currentUserId();
      if (userId == null) return false;
      final row = await _supabase.from('users').select('is_admin').eq('id', userId).maybeSingle();
      return row?['is_admin'] as bool? ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<UserSanctionModel?> fetchMyActiveSanction() async {
    try {
      final userId = await _currentUserId();
      if (userId == null) return null;

      final rows = await _supabase
          .from('user_sanctions')
          .select('id, user_id, sanction_type, reason, expires_at, created_at')
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      for (final row in rows as List<dynamic>) {
        final sanction = UserSanctionModel.fromJson(Map<String, dynamic>.from(row as Map));
        if (sanction.sanctionType == 'ban') return sanction;
        if (sanction.expiresAt != null && sanction.expiresAt!.isAfter(DateTime.now())) {
          return sanction;
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<List<ContentReportModel>> fetchModerationReports({
    String? statusFilter,
    bool onlyMyReports = true,
  }) async {
    try {
      var query = _supabase.from('content_reports').select();
      if (onlyMyReports) {
        final userId = await _currentUserId();
        if (userId != null) {
          query = query.eq('reporter_id', userId);
        }
      }
      if (statusFilter != null && statusFilter.isNotEmpty) {
        query = query.eq('status', statusFilter);
      }
      final rows = await query.order('created_at', ascending: false);
      final rawReports = (rows as List<dynamic>)
          .map((row) => ContentReportModel.fromJson(Map<String, dynamic>.from(row as Map)))
          .toList();

      if (rawReports.isEmpty) return const [];

      final groupIdsToFetch = <String>{};
      final messageIds = <String>[];
      final anonymousMessageIds = <String>[];
      final groupPhotoIds = <String>[];
      final userIds = <String>[];

      for (final report in rawReports) {
        if (report.targetType == 'group') {
          groupIdsToFetch.add(report.targetId);
        } else if (report.targetType == 'message') {
          messageIds.add(report.targetId);
        } else if (report.targetType == 'anonymous_message') {
          anonymousMessageIds.add(report.targetId);
        } else if (report.targetType == 'group_photo') {
          groupPhotoIds.add(report.targetId);
        } else if (report.targetType == 'user') {
          userIds.add(report.targetId);
        }
      }

      final reportGroupNames = <String, String>{};
      final reportPreviews = <String, String>{};

      if (groupIdsToFetch.isNotEmpty) {
        final groupsRows = await _supabase
            .from('groups')
            .select('id, name')
            .inFilter('id', groupIdsToFetch.toList());
        for (final row in groupsRows as List<dynamic>) {
          final id = row['id']?.toString();
          final name = row['name']?.toString();
          if (id != null && name != null) {
            for (final report in rawReports) {
              if (report.targetType == 'group' && report.targetId == id) {
                reportGroupNames[report.id] = name;
              }
            }
          }
        }
      }

      if (messageIds.isNotEmpty) {
        final msgRows = await _supabase
            .from('messages')
            .select('id, content, group_id, groups:groups(name)')
            .inFilter('id', messageIds);
        for (final row in msgRows as List<dynamic>) {
          final id = row['id']?.toString();
          final content = row['content']?.toString();
          final groupObj = row['groups'] as Map<String, dynamic>?;
          final groupName = groupObj?['name']?.toString();
          if (id != null) {
            for (final report in rawReports) {
              if (report.targetType == 'message' && report.targetId == id) {
                if (groupName != null) reportGroupNames[report.id] = groupName;
                if (content != null) reportPreviews[report.id] = content;
              }
            }
          }
        }
      }

      if (anonymousMessageIds.isNotEmpty) {
        final anonRows = await _supabase
            .from('anonymous_messages')
            .select('id, content, group_id, groups:groups(name)')
            .inFilter('id', anonymousMessageIds);
        for (final row in anonRows as List<dynamic>) {
          final id = row['id']?.toString();
          final content = row['content']?.toString();
          final groupObj = row['groups'] as Map<String, dynamic>?;
          final groupName = groupObj?['name']?.toString();
          if (id != null) {
            for (final report in rawReports) {
              if (report.targetType == 'anonymous_message' && report.targetId == id) {
                if (groupName != null) reportGroupNames[report.id] = groupName;
                if (content != null) reportPreviews[report.id] = content;
              }
            }
          }
        }
      }

      if (groupPhotoIds.isNotEmpty) {
        final photoRows = await _supabase
            .from('group_photos')
            .select('id, group_id, groups:groups(name)')
            .inFilter('id', groupPhotoIds);
        for (final row in photoRows as List<dynamic>) {
          final id = row['id']?.toString();
          final groupObj = row['groups'] as Map<String, dynamic>?;
          final groupName = groupObj?['name']?.toString();
          if (id != null) {
            for (final report in rawReports) {
              if (report.targetType == 'group_photo' && report.targetId == id) {
                if (groupName != null) reportGroupNames[report.id] = groupName;
              }
            }
          }
        }
      }

      if (userIds.isNotEmpty) {
        final userRows = await _supabase
            .from('users')
            .select('id, display_name, username')
            .inFilter('id', userIds);
        for (final row in userRows as List<dynamic>) {
          final id = row['id']?.toString();
          final dName = row['display_name']?.toString() ?? row['username']?.toString();
          if (id != null && dName != null) {
            for (final report in rawReports) {
              if (report.targetType == 'user' && report.targetId == id) {
                reportGroupNames[report.id] = 'Usuario: @$dName';
              }
            }
          }
        }
      }

      return rawReports.map((report) {
        final resolvedGroupName = reportGroupNames[report.id] ?? 'Grupo no disponible';
        final resolvedPreview = reportPreviews[report.id];
        return report.copyWith(
          groupName: resolvedGroupName,
          targetPreview: resolvedPreview,
        );
      }).toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> resolveReport({
    required String reportId,
    required String action,
    String? notes,
    int muteHours = 24,
  }) async {
    final userId = await _currentUserId();
    if (userId == null) {
      throw const AuthException('Debes iniciar sesión como administrador.');
    }

    await _supabase.rpc('resolve_content_report', params: {
      'p_report_id': reportId,
      'p_action': action,
      'p_notes': notes,
      'p_mute_hours': muteHours,
    });
  }

  Future<List<String>> fetchHiddenWords() async {
    try {
      final userId = await _currentUserId();
      if (userId == null) return _cachedHiddenWords ?? const [];

      final rows = await _supabase
          .from('user_hidden_words')
          .select('word')
          .eq('user_id', userId)
          .order('created_at', ascending: true);

      final words = (rows as List<dynamic>)
          .map((row) => (row as Map)['word']?.toString().trim() ?? '')
          .where((word) => word.isNotEmpty)
          .toList();

      _cachedHiddenWords = words;
      return words;
    } catch (_) {
      return _cachedHiddenWords ?? const [];
    }
  }

  Future<void> addHiddenWord(String word) async {
    final userId = await _currentUserId();
    if (userId == null) {
      throw const AuthException('Debes iniciar sesión para guardar palabras ocultas.');
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
    _cachedHiddenWords = null;
  }

  Future<void> removeHiddenWord(String word) async {
    final userId = await _currentUserId();
    if (userId == null) {
      throw const AuthException('Debes iniciar sesión para eliminar palabras.');
    }

    final normalized = _normalize(word);
    if (normalized.isEmpty) return;

    await _supabase.from('user_hidden_words').delete().eq('user_id', userId).eq('word', normalized);
    _cachedHiddenWords = null;
  }

  Future<SafetyMessageFilterSettings> fetchFilterSettings() async {
    try {
      final userId = await _currentUserId();
      if (userId == null) {
        return _cachedSettings ?? const SafetyMessageFilterSettings();
      }

      final row = await _supabase
          .from('user_message_filter_settings')
          .select('hide_hidden_words, hide_blocked_users')
          .eq('user_id', userId)
          .maybeSingle();

      if (row == null) {
        const defaultSettings = SafetyMessageFilterSettings();
        _cachedSettings = defaultSettings;
        return defaultSettings;
      }

      final settings = SafetyMessageFilterSettings(
        hideHiddenWords: row['hide_hidden_words'] as bool? ?? true,
        hideBlockedUsers: row['hide_blocked_users'] as bool? ?? true,
      );
      _cachedSettings = settings;
      return settings;
    } catch (_) {
      return _cachedSettings ?? const SafetyMessageFilterSettings();
    }
  }

  Future<void> updateFilterSettings({
    required bool hideHiddenWords,
    required bool hideBlockedUsers,
  }) async {
    final userId = await _currentUserId();
    if (userId == null) {
      throw const AuthException('Debes iniciar sesión para cambiar los filtros.');
    }

    await _supabase.from('user_message_filter_settings').upsert({
      'user_id': userId,
      'hide_hidden_words': hideHiddenWords,
      'hide_blocked_users': hideBlockedUsers,
      'updated_at': DateTime.now().toIso8601String(),
    });
    _cachedSettings = SafetyMessageFilterSettings(
      hideHiddenWords: hideHiddenWords,
      hideBlockedUsers: hideBlockedUsers,
    );
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

      _cachedBlockedIds = blockedIds.toSet();

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
      throw const AuthException('Debes iniciar sesión para bloquear usuarios.');
    }

    if (blockedUserId.trim().isEmpty || blockedUserId == userId) return;

    await _supabase.from('user_blocked_users').upsert({
      'user_id': userId,
      'blocked_user_id': blockedUserId,
    }, onConflict: 'user_id,blocked_user_id');

    if (_cachedBlockedIds != null) {
      _cachedBlockedIds!.add(blockedUserId);
    }
  }

  Future<void> unblockUser(String blockedUserId) async {
    final userId = await _currentUserId();
    if (userId == null) {
      throw const AuthException('Debes iniciar sesión para desbloquear usuarios.');
    }

    await _supabase
        .from('user_blocked_users')
        .delete()
        .eq('user_id', userId)
        .eq('blocked_user_id', blockedUserId);

    if (_cachedBlockedIds != null) {
      _cachedBlockedIds!.remove(blockedUserId);
    }
  }

  Future<void> submitReport({
    required String targetType,
    required String targetId,
    required String reason,
    String? details,
    String? contentSnapshot,
  }) async {
    final userId = await _currentUserId();
    if (userId == null) {
      throw const AuthException('Debes iniciar sesión para enviar una denuncia.');
    }

    final trimmedReason = reason.trim();
    if (trimmedReason.isEmpty) {
      throw const FormatException('Debes seleccionar un motivo para la denuncia.');
    }

    final payload = <String, dynamic>{
      'reporter_id': userId,
      'target_type': targetType,
      'target_id': targetId,
      'reason': trimmedReason,
      if (details != null && details.trim().isNotEmpty) 'details': details.trim(),
      if (contentSnapshot != null && contentSnapshot.trim().isNotEmpty) 'content_snapshot': contentSnapshot.trim(),
    };

    await _supabase.from('content_reports').insert(payload);
  }

  Future<List<MessageModel>> filterMessages(List<MessageModel> messages) async {
    if (messages.isEmpty) return messages;
    try {
      final settings = await fetchFilterSettings();
      final hiddenWords = settings.hideHiddenWords ? await fetchHiddenWords() : const <String>[];
      final blockedIds = settings.hideBlockedUsers
          ? (await fetchBlockedUsers()).map((item) => item.id).toSet()
          : <String>{};

      return _applyMessageFilter(messages, settings, hiddenWords, blockedIds);
    } catch (_) {
      final settings = _cachedSettings ?? const SafetyMessageFilterSettings();
      final hiddenWords = _cachedHiddenWords ?? const <String>[];
      final blockedIds = _cachedBlockedIds ?? <String>{};
      return _applyMessageFilter(messages, settings, hiddenWords, blockedIds);
    }
  }

  Future<List<AnonymousMessageModel>> filterAnonymousMessages(List<AnonymousMessageModel> messages) async {
    if (messages.isEmpty) return messages;
    try {
      final settings = await fetchFilterSettings();
      final hiddenWords = settings.hideHiddenWords ? await fetchHiddenWords() : const <String>[];
      return _applyAnonymousMessageFilter(messages, settings, hiddenWords);
    } catch (_) {
      final settings = _cachedSettings ?? const SafetyMessageFilterSettings();
      final hiddenWords = _cachedHiddenWords ?? const <String>[];
      return _applyAnonymousMessageFilter(messages, settings, hiddenWords);
    }
  }

  List<MessageModel> _applyMessageFilter(
    List<MessageModel> messages,
    SafetyMessageFilterSettings settings,
    List<String> hiddenWords,
    Set<String> blockedIds,
  ) {
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
  }

  List<AnonymousMessageModel> _applyAnonymousMessageFilter(
    List<AnonymousMessageModel> messages,
    SafetyMessageFilterSettings settings,
    List<String> hiddenWords,
  ) {
    final filtered = <AnonymousMessageModel>[];
    for (final message in messages) {
      if (settings.hideHiddenWords && _matchesHiddenWord(message.content, hiddenWords)) {
        filtered.add(message.copyWith(content: 'Mensaje oculto por tus filtros'));
        continue;
      }

      filtered.add(message);
    }

    return filtered;
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

class ContentReportModel {
  const ContentReportModel({
    required this.id,
    this.reporterId,
    required this.targetType,
    required this.targetId,
    required this.reason,
    this.details,
    this.contentSnapshot,
    required this.status,
    required this.createdAt,
    this.moderatorId,
    this.moderatorNotes,
    this.resolvedAt,
    this.groupName,
    this.targetPreview,
  });

  final String id;
  final String? reporterId;
  final String targetType;
  final String targetId;
  final String reason;
  final String? details;
  final String? contentSnapshot;
  final String status;
  final DateTime createdAt;
  final String? moderatorId;
  final String? moderatorNotes;
  final DateTime? resolvedAt;
  final String? groupName;
  final String? targetPreview;

  ContentReportModel copyWith({
    String? groupName,
    String? targetPreview,
  }) {
    return ContentReportModel(
      id: id,
      reporterId: reporterId,
      targetType: targetType,
      targetId: targetId,
      reason: reason,
      details: details,
      contentSnapshot: contentSnapshot,
      status: status,
      createdAt: createdAt,
      moderatorId: moderatorId,
      moderatorNotes: moderatorNotes,
      resolvedAt: resolvedAt,
      groupName: groupName ?? this.groupName,
      targetPreview: targetPreview ?? this.targetPreview,
    );
  }

  factory ContentReportModel.fromJson(Map<String, dynamic> json) {
    return ContentReportModel(
      id: json['id'].toString(),
      reporterId: json['reporter_id']?.toString(),
      targetType: json['target_type'].toString(),
      targetId: json['target_id'].toString(),
      reason: json['reason'].toString(),
      details: json['details']?.toString(),
      contentSnapshot: json['content_snapshot']?.toString(),
      status: json['status']?.toString() ?? 'pending',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'].toString())
          : DateTime.now(),
      moderatorId: json['moderator_id']?.toString(),
      moderatorNotes: json['moderator_notes']?.toString(),
      resolvedAt: json['resolved_at'] != null
          ? DateTime.parse(json['resolved_at'].toString())
          : null,
      groupName: json['group_name']?.toString(),
      targetPreview: json['target_preview']?.toString() ?? json['content_snapshot']?.toString(),
    );
  }
}

class UserSanctionModel {
  const UserSanctionModel({
    required this.id,
    required this.userId,
    required this.sanctionType,
    required this.reason,
    this.expiresAt,
    required this.createdAt,
  });

  final String id;
  final String userId;
  final String sanctionType;
  final String reason;
  final DateTime? expiresAt;
  final DateTime createdAt;

  factory UserSanctionModel.fromJson(Map<String, dynamic> json) {
    return UserSanctionModel(
      id: json['id'].toString(),
      userId: json['user_id'].toString(),
      sanctionType: json['sanction_type'].toString(),
      reason: json['reason'].toString(),
      expiresAt: json['expires_at'] != null ? DateTime.parse(json['expires_at'].toString()) : null,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at'].toString()) : DateTime.now(),
    );
  }
}
