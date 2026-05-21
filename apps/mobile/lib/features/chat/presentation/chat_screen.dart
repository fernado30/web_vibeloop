import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../groups/data/groups_repository.dart';
import '../data/chat_repository.dart';
import '../domain/message_model.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key, required this.groupId});

  final String groupId;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  late final Stream<List<MessageModel>> _messagesStream;
  late final RealtimeChannel _presenceChannel;
  late final Future<InviteLinks> _inviteLinksFuture;
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  final _focusNode = FocusNode();
  final Set<String> _otherTypingUsers = <String>{};
  Timer? _typingTimer;
  bool _isTyping = false;

  @override
  void initState() {
    super.initState();
    _messagesStream = ref.read(chatRepositoryProvider).watchMessages(widget.groupId);
    _inviteLinksFuture = ref.read(groupsRepositoryProvider).generateInviteLinks(widget.groupId);
    _presenceChannel = Supabase.instance.client.channel('chat-presence-${widget.groupId}');
    _setupPresence();
    _focusNode.addListener(_handleFocusChange);
    _textController.addListener(_handleTyping);
  }

  void _setupPresence() {
    final user = Supabase.instance.client.auth.currentUser;

    _presenceChannel.onPresenceSync((_) {
      final state = _presenceChannel.presenceState();
      final typingUsers = <String>{};

      for (final client in state) {
        for (final presence in client.presences) {
          final payload = presence.payload;
          final userId = payload['user_id']?.toString();
          final typing = payload['typing'] == true;

          if (typing && userId != null && userId != user?.id) {
            typingUsers.add(userId);
          }
        }
      }

      if (mounted) {
        setState(() {
          _otherTypingUsers
            ..clear()
            ..addAll(typingUsers);
        });
      }
    });

    () async {
      _presenceChannel.subscribe();
      if (user != null) {
        await _presenceChannel.track({
          'user_id': user.id,
          'typing': false,
          'updated_at': DateTime.now().toIso8601String(),
        });
      }
    }();
  }

  void _handleFocusChange() {
    if (!_focusNode.hasFocus) {
      _setTyping(false);
    }
  }

  void _handleTyping() {
    _typingTimer?.cancel();
    final hasText = _textController.text.trim().isNotEmpty;
    _setTyping(hasText);

    _typingTimer = Timer(const Duration(milliseconds: 1200), () {
      if (mounted) {
        _setTyping(false);
      }
    });
  }

  Future<void> _setTyping(bool value) async {
    if (_isTyping == value) return;
    _isTyping = value;

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    await _presenceChannel.track({
      'user_id': user.id,
      'typing': value,
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

  @override
  void dispose() {
    _typingTimer?.cancel();
    _presenceChannel.unsubscribe();
    _textController.dispose();
    _scrollController.dispose();
    _focusNode.removeListener(_handleFocusChange);
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    await ref.read(chatRepositoryProvider).sendMessage(widget.groupId, text, 'text');
    _textController.clear();
    await _setTyping(false);
  }

  Future<void> _reactToMessage(String messageId, String emoji) async {
    await ref.read(chatRepositoryProvider).reactToMessage(messageId, emoji);
  }

  Future<void> _copyInviteLink({
    required String label,
    required String Function(InviteLinks links) pickLink,
  }) async {
    final links = await _inviteLinksFuture;
    await Clipboard.setData(ClipboardData(text: pickLink(links)));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label copiado al portapapeles')),
    );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.minScrollExtent,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    const reactions = [
      '\u{1F44D}',
      '\u{2764}\u{FE0F}',
      '\u{1F602}',
      '\u{1F62E}',
      '\u{1F622}',
      '\u{1F525}',
    ];

    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text('Grupo ${widget.groupId.substring(0, 6)}'),
        actions: [
          IconButton(
            tooltip: 'Copiar link de la app',
            onPressed: () => _copyInviteLink(
              label: 'Link de la app',
              pickLink: (links) => links.appLink,
            ),
            icon: const Icon(Icons.phone_android),
          ),
          IconButton(
            tooltip: 'Copiar link web',
            onPressed: () => _copyInviteLink(
              label: 'Link web',
              pickLink: (links) => links.webLink,
            ),
            icon: const Icon(Icons.language),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_otherTypingUsers.isNotEmpty)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.82),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: colorScheme.outline.withValues(alpha: 0.35)),
              ),
              child: Text(
                'Escribiendo...',
                textAlign: TextAlign.center,
                style: TextStyle(color: colorScheme.onSurfaceVariant),
              ),
            ),
          Expanded(
            child: StreamBuilder<List<MessageModel>>(
              stream: _messagesStream,
              builder: (context, snapshot) {
                final messages = snapshot.data ?? const <MessageModel>[];

                if (messages.isNotEmpty) {
                  _scrollToBottom();
                }

                if (snapshot.connectionState == ConnectionState.waiting && messages.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }

                return ListView.separated(
                  controller: _scrollController,
                  reverse: true,
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
                  itemCount: messages.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    final isMine = message.senderId == currentUserId;

                    return Align(
                      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
                      child: GestureDetector(
                        onLongPress: () async {
                          final reaction = await showModalBottomSheet<String>(
                            context: context,
                            backgroundColor: colorScheme.surface,
                            builder: (context) {
                              return Padding(
                                padding: const EdgeInsets.all(16),
                                child: Wrap(
                                  spacing: 12,
                                  runSpacing: 12,
                                  children: reactions
                                      .map(
                                        (emoji) => ActionChip(
                                          label: Text(emoji, style: const TextStyle(fontSize: 20)),
                                          onPressed: () => Navigator.of(context).pop(emoji),
                                        ),
                                      )
                                      .toList(),
                                ),
                              );
                            },
                          );

                          if (reaction != null) {
                            await _reactToMessage(message.id, reaction);
                          }
                        },
                        child: Container(
                          constraints: const BoxConstraints(maxWidth: 320),
                          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
                          decoration: BoxDecoration(
                            gradient: isMine
                                ? const LinearGradient(
                                    colors: [
                                      Color(0xFF2EA8FF),
                                      Color(0xFF8AD8FF),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  )
                                : null,
                            color: isMine ? null : Colors.white.withValues(alpha: 0.92),
                            border: Border.all(
                              color: isMine ? Colors.transparent : colorScheme.outline.withValues(alpha: 0.32),
                            ),
                            borderRadius: BorderRadius.only(
                              topLeft: const Radius.circular(22),
                              topRight: const Radius.circular(22),
                              bottomLeft: Radius.circular(isMine ? 22 : 8),
                              bottomRight: Radius.circular(isMine ? 8 : 22),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.08),
                                blurRadius: 18,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isMine ? 'Tu' : message.senderName,
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: isMine ? Colors.white.withValues(alpha: 0.95) : colorScheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                message.content,
                                style: TextStyle(
                                  color: isMine ? Colors.white : colorScheme.onSurface,
                                ),
                              ),
                              if (message.reactions.isNotEmpty) ...[
                                const SizedBox(height: 10),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: message.reactions.entries
                                      .map(
                                        (entry) => Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: isMine
                                                ? Colors.white.withValues(alpha: 0.16)
                                                : colorScheme.primary.withValues(alpha: 0.06),
                                            borderRadius: BorderRadius.circular(999),
                                          ),
                                          child: Text(
                                            '${entry.key} ${entry.value}',
                                            style: TextStyle(
                                              color: isMine ? Colors.white : colorScheme.onSurfaceVariant,
                                            ),
                                          ),
                                        ),
                                      )
                                      .toList(),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.82),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: colorScheme.outline.withValues(alpha: 0.35)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _textController,
                        focusNode: _focusNode,
                        minLines: 1,
                        maxLines: 4,
                        decoration: InputDecoration(
                          hintText: 'Escribe un mensaje...',
                          fillColor: colorScheme.surface,
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                        ),
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    FilledButton(
                      onPressed: _sendMessage,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(52, 52),
                        padding: EdgeInsets.zero,
                      ),
                      child: const Icon(Icons.send),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
