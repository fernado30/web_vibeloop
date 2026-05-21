import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/message_model.dart';

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  return ChatRepository(Supabase.instance.client);
});

class ChatRepository {
  ChatRepository(this._client);

  final SupabaseClient _client;

  SupabaseClient get _supabase => _client;

  Future<MessageModel> _fetchMessageById(String messageId) async {
    final row = await _supabase
        .from('messages')
        .select('id, group_id, sender_id, content, type, created_at, sender:users(display_name), reactions:reactions(emoji)')
        .eq('id', messageId)
        .maybeSingle();

    if (row == null) {
      throw StateError('No se pudo cargar el mensaje.');
    }

    final json = Map<String, dynamic>.from(row as Map);
    final sender = json['sender'] as Map<String, dynamic>?;
    json['sender_name'] = sender?['display_name']?.toString() ?? 'Miembro';
    json['reactions'] = _reactionCounts(json['reactions']);
    return MessageModel.fromJson(json);
  }

  Future<List<MessageModel>> fetchMessages(String groupId) async {
    final rows = await _supabase
        .from('messages')
        .select('id, group_id, sender_id, content, type, created_at, sender:users(display_name), reactions:reactions(emoji)')
        .eq('group_id', groupId)
        .order('created_at', ascending: false);

    return (rows as List<dynamic>).map((row) {
      final json = Map<String, dynamic>.from(row as Map);
      final sender = json['sender'] as Map<String, dynamic>?;
      json['sender_name'] = sender?['display_name']?.toString() ?? 'Miembro';
      json['reactions'] = _reactionCounts(json['reactions']);
      return MessageModel.fromJson(json);
    }).toList();
  }

  Future<void> sendMessage(String groupId, String content, String type) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      throw AuthException('Debes iniciar sesión para enviar mensajes.');
    }

    await _supabase.from('messages').insert({
      'group_id': groupId,
      'sender_id': user.id,
      'content': content,
      'type': type,
    });
  }

  Future<void> reactToMessage(String messageId, String emoji) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      throw AuthException('Debes iniciar sesión para reaccionar.');
    }

    await _supabase.from('reactions').upsert({
      'message_id': messageId,
      'user_id': user.id,
      'emoji': emoji,
    });
  }

  Stream<List<MessageModel>> watchMessages(String groupId) {
    final controller = StreamController<List<MessageModel>>.broadcast();
    final channel = _supabase.channel('messages-$groupId');
    var cache = <MessageModel>[];
    var loaded = false;

    Future<void> emit() async {
      if (!controller.isClosed) {
        cache = await fetchMessages(groupId);
        loaded = true;
        controller.add(cache);
      }
    }

    Future<void> refreshSingleMessage(String messageId) async {
      if (!loaded || controller.isClosed) {
        await emit();
        return;
      }

      final message = await _fetchMessageById(messageId);
      final existingIndex = cache.indexWhere((item) => item.id == message.id);

      if (existingIndex == -1) {
        cache = [message, ...cache];
      } else {
        cache = [
          ...cache.take(existingIndex),
          message,
          ...cache.skip(existingIndex + 1),
        ];
      }

      if (!controller.isClosed) {
        controller.add(cache);
      }
    }

    channel.onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'messages',
      filter: PostgresChangeFilter(column: 'group_id', value: groupId, type: PostgresChangeFilterType.eq),
      callback: (payload) {
        final messageId = payload.newRecord['id']?.toString();
        if (messageId == null || messageId.isEmpty) {
          emit();
          return;
        }
        refreshSingleMessage(messageId);
      },
    );

    channel.onPostgresChanges(
      event: PostgresChangeEvent.update,
      schema: 'public',
      table: 'messages',
      filter: PostgresChangeFilter(column: 'group_id', value: groupId, type: PostgresChangeFilterType.eq),
      callback: (payload) {
        final messageId = payload.newRecord['id']?.toString();
        if (messageId == null || messageId.isEmpty) {
          emit();
          return;
        }
        refreshSingleMessage(messageId);
      },
    );

    channel.onPostgresChanges(
      event: PostgresChangeEvent.delete,
      schema: 'public',
      table: 'messages',
      filter: PostgresChangeFilter(column: 'group_id', value: groupId, type: PostgresChangeFilterType.eq),
      callback: (_) => emit(),
    );

    channel.onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'reactions',
      callback: (_) => emit(),
    );

    channel.onPostgresChanges(
      event: PostgresChangeEvent.delete,
      schema: 'public',
      table: 'reactions',
      callback: (_) => emit(),
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
  if (raw is List) {
    for (final item in raw) {
      if (item is Map && item['emoji'] != null) {
        final emoji = item['emoji'].toString();
        counts[emoji] = (counts[emoji] ?? 0) + 1;
      }
    }
  }
  return counts;
}
