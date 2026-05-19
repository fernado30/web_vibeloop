import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

    return (rows as List<dynamic>).map((row) {
      final json = Map<String, dynamic>.from(row as Map);
      json['reactions'] = _reactionCounts(json['reactions']);
      return AnonymousMessageModel.fromJson(json);
    }).toList();
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
