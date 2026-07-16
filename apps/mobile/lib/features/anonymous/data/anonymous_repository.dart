import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../settings/data/safety_repository.dart';
import '../domain/anonymous_message_model.dart';

final anonymousRepositoryProvider = Provider<AnonymousRepository>((ref) {
  return AnonymousRepository(Supabase.instance.client);
});

class AnonymousRepository {
  AnonymousRepository(this._client);

  final SupabaseClient _client;

  SupabaseClient get _supabase => _client;

  Future<List<AnonymousMessageModel>> fetchAnonymousMessages(String groupId) async {
    final rows = await _supabase
        .from('anonymous_messages')
        .select('id, group_id, content, reactions, created_at')
        .eq('group_id', groupId)
        .order('created_at', ascending: false);

    final messages = (rows as List<dynamic>).map((row) {
      final json = Map<String, dynamic>.from(row as Map);
      json['reactions'] = _reactionCounts(json['reactions']);
      return AnonymousMessageModel.fromJson(json);
    }).toList();

    try {
      return await SafetyRepository(_supabase).filterAnonymousMessages(messages);
    } catch (_) {
      return messages;
    }
  }

  Future<void> reactToAnonymousMessage(String messageId, String reaction) async {
    final row = await _supabase.from('anonymous_messages').select('reactions').eq('id', messageId).single();
    final current = Map<String, dynamic>.from(row['reactions'] as Map? ?? {});
    final updated = <String, int>{};
    for (final entry in current.entries) {
      updated[entry.key.toString()] = (entry.value as num).toInt();
    }
    updated[reaction] = (updated[reaction] ?? 0) + 1;
    await _supabase.from('anonymous_messages').update({'reactions': updated}).eq('id', messageId);
  }

  Future<void> publishAnonymousMessage(AnonymousMessageModel message) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      throw const AuthException('Debes iniciar sesion para publicar un mensaje.');
    }

    await _supabase.from('messages').insert({
      'group_id': message.groupId,
      'sender_id': user.id,
      'content': message.content,
      'type': 'anonymous',
    });

    await _supabase.from('anonymous_messages').delete().eq('id', message.id);
  }

  Stream<List<AnonymousMessageModel>> watchAnonymousMessages(String groupId) {
    final controller = StreamController<List<AnonymousMessageModel>>.broadcast();
    final channel = _supabase.channel('anonymous-messages-$groupId');
    var cache = <AnonymousMessageModel>[];
    var loaded = false;

    Future<void> emit() async {
      if (controller.isClosed) return;
      cache = await fetchAnonymousMessages(groupId);
      loaded = true;
      controller.add(cache);
    }

    Future<AnonymousMessageModel?> parseFilteredMessage(Map<String, dynamic> json) async {
      final message = AnonymousMessageModel.fromJson(json);
      final filtered = await SafetyRepository(_supabase).filterAnonymousMessages([message]);
      return filtered.isEmpty ? null : filtered.first;
    }

    Future<void> upsertFromRecord(Map<String, dynamic> record, {bool placeAtFront = true}) async {
      if (!loaded || controller.isClosed) {
        await emit();
        return;
      }

      final json = Map<String, dynamic>.from(record);
      json['reactions'] = _reactionCounts(json['reactions']);
      final message = await parseFilteredMessage(json);

      if (message == null) {
        cache = cache.where((item) => item.id != json['id']?.toString()).toList();
      } else {
        final existingIndex = cache.indexWhere((item) => item.id == message.id);
        if (existingIndex == -1) {
          cache = placeAtFront ? [message, ...cache] : [...cache, message];
        } else {
          cache = [
            ...cache.take(existingIndex),
            message,
            ...cache.skip(existingIndex + 1),
          ];
        }
      }

      if (!controller.isClosed) {
        controller.add(cache);
      }
    }

    Future<void> removeFromCache(String? messageId) async {
      if (!loaded || controller.isClosed) {
        await emit();
        return;
      }

      if (messageId == null || messageId.isEmpty) {
        await emit();
        return;
      }

      final nextCache = cache.where((item) => item.id != messageId).toList();
      if (nextCache.length == cache.length) {
        await emit();
        return;
      }

      cache = nextCache;
      if (!controller.isClosed) {
        controller.add(cache);
      }
    }

    channel.onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'anonymous_messages',
      filter: PostgresChangeFilter(column: 'group_id', value: groupId, type: PostgresChangeFilterType.eq),
      callback: (payload) {
        final record = payload.newRecord;
        if (record.isEmpty) {
          emit();
          return;
        }
        upsertFromRecord(Map<String, dynamic>.from(record));
      },
    );

    channel.onPostgresChanges(
      event: PostgresChangeEvent.update,
      schema: 'public',
      table: 'anonymous_messages',
      filter: PostgresChangeFilter(column: 'group_id', value: groupId, type: PostgresChangeFilterType.eq),
      callback: (payload) {
        final record = payload.newRecord;
        if (record.isEmpty) {
          emit();
          return;
        }
        upsertFromRecord(Map<String, dynamic>.from(record), placeAtFront: false);
      },
    );

    channel.onPostgresChanges(
      event: PostgresChangeEvent.delete,
      schema: 'public',
      table: 'anonymous_messages',
      filter: PostgresChangeFilter(column: 'group_id', value: groupId, type: PostgresChangeFilterType.eq),
      callback: (payload) {
        final record = payload.oldRecord;
        final messageId = record['id']?.toString();
        if (messageId == null || messageId.isEmpty) {
          emit();
          return;
        }
        removeFromCache(messageId);
      },
    );

    channel.subscribe();
    emit();

    controller.onCancel = () async {
      channel.unsubscribe();
      await controller.close();
    };

    return controller.stream;
  }
}

Map<String, int> _reactionCounts(dynamic raw) {
  final counts = <String, int>{};
  if (raw is Map) {
    raw.forEach((key, value) {
      counts[key.toString()] = (value as num).toInt();
    });
  }
  return counts;
}
