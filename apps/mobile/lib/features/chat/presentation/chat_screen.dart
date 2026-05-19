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

  Future<void> _shareInviteLink() async {
    final inviteLink = await ref.read(groupsRepositoryProvider).generateInviteLink(widget.groupId);
    await Clipboard.setData(ClipboardData(text: inviteLink));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Link web copiado: $inviteLink'),
        duration: const Duration(seconds: 3),
      ),
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

    return Scaffold(
      appBar: AppBar(
        title: Text('Chat del grupo ${widget.groupId.substring(0, 6)}'),
        actions: [
          IconButton(
            tooltip: 'Compartir enlace de invitación',
            onPressed: _shareInviteLink,
            icon: const Icon(Icons.share),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_otherTypingUsers.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.white10,
              child: const Text('Escribiendo...'),
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
                  padding: const EdgeInsets.all(16),
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
                            backgroundColor: Theme.of(context).colorScheme.surface,
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
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: isMine ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.surface,
                            borderRadius: BorderRadius.only(
                              topLeft: const Radius.circular(18),
                              topRight: const Radius.circular(18),
                              bottomLeft: Radius.circular(isMine ? 18 : 4),
                              bottomRight: Radius.circular(isMine ? 4 : 18),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isMine ? 'Tu' : message.senderName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white70,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(message.content),
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
                                            color: Colors.white10,
                                            borderRadius: BorderRadius.circular(999),
                                          ),
                                          child: Text('${entry.key} ${entry.value}'),
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
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      focusNode: _focusNode,
                      minLines: 1,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        hintText: 'Escribe un mensaje...',
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton(
                    onPressed: _sendMessage,
                    child: const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
