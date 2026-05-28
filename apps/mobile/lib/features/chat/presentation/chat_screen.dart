import 'dart:async';
import 'dart:io';

import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/ads/ad_service.dart';
import '../../../core/utils/profile_emojis.dart';
import '../../auth/data/auth_repository.dart';
import '../../anonymous/data/anonymous_repository.dart';
import '../../anonymous/domain/anonymous_message_model.dart';
import '../../groups/data/groups_repository.dart';
import '../data/chat_repository.dart';
import '../domain/message_model.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key, required this.groupId});

  final String groupId;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

enum _ChatFeedEntryType { message }

class _ChatFeedEntry {
  const _ChatFeedEntry.message(this.message)
      : type = _ChatFeedEntryType.message;

  final _ChatFeedEntryType type;
  final MessageModel message;
  DateTime get createdAt => message.createdAt;
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final GlobalKey _screenshotKey = GlobalKey();
  late Stream<List<MessageModel>> _messagesStream;
  late Stream<List<AnonymousMessageModel>> _anonymousMessagesStream;
  late final RealtimeChannel _presenceChannel;
  late final Future<InviteLinks> _inviteLinksFuture;
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  final _focusNode = FocusNode();
  final Set<String> _otherTypingUsers = <String>{};
  bool _anonymousBubbleOpen = false;
  DateTime? _lastAnonymousSeenAt;
  Timer? _typingTimer;
  bool _isTyping = false;
  String _currentUserEmoji = 'ðŸ™‚';

  @override
  void initState() {
    super.initState();
    _messagesStream = ref.read(chatRepositoryProvider).watchMessages(widget.groupId);
    _anonymousMessagesStream = ref.read(anonymousRepositoryProvider).watchAnonymousMessages(widget.groupId);
    _inviteLinksFuture = ref.read(groupsRepositoryProvider).generateInviteLinks(widget.groupId);
    _presenceChannel = Supabase.instance.client.channel('chat-presence-${widget.groupId}');
    _loadCurrentEmoji();
    _setupPresence();
    _focusNode.addListener(_handleFocusChange);
    _textController.addListener(_handleTyping);
  }

  Future<void> _loadCurrentEmoji() async {
    final profile = await ref.read(authRepositoryProvider).fetchCurrentProfile();
    if (!mounted) return;
    setState(() {
      _currentUserEmoji = profile?['emoji']?.toString() ?? 'ðŸ™‚';
    });
  }

  List<_ChatFeedEntry> _buildFeedEntries(
    List<MessageModel> messages,
  ) {
    return messages.map(_ChatFeedEntry.message).toList();
  }

  List<AnonymousMessageModel> _unseenAnonymousMessages(List<AnonymousMessageModel> anonymousMessages) {
    final lastSeenAt = _lastAnonymousSeenAt;
    if (lastSeenAt == null) {
      return anonymousMessages;
    }

    return anonymousMessages.where((message) => message.createdAt.isAfter(lastSeenAt)).toList();
  }

  void _toggleAnonymousBubble(List<AnonymousMessageModel> anonymousMessages) {
    setState(() {
      final opening = !_anonymousBubbleOpen;
      _anonymousBubbleOpen = opening;

      if (!opening && anonymousMessages.isNotEmpty) {
        _lastAnonymousSeenAt = anonymousMessages.first.createdAt;
      }
    });
  }

  Widget _buildAnonymousFloatingBubble(
    BuildContext context,
    List<AnonymousMessageModel> anonymousMessages,
  ) {
    if (anonymousMessages.isEmpty && !_anonymousBubbleOpen) {
      return const SizedBox.shrink();
    }

    final previewMessage = anonymousMessages.isNotEmpty ? anonymousMessages.first : null;
    final unseenCount = _unseenAnonymousMessages(anonymousMessages).length;
    final isOpen = _anonymousBubbleOpen;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(top: 8, right: 8),
        child: Align(
          alignment: Alignment.topRight,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 280),
            child: GestureDetector(
              onTap: () => _toggleAnonymousBubble(anonymousMessages),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 240),
                curve: Curves.easeOutCubic,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(isOpen ? 28 : 999),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 26,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(isOpen ? 28 : 999),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.white.withValues(alpha: 0.66),
                            Colors.white.withValues(alpha: 0.36),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        border: Border.all(
                          color: const Color(0xFF2EA8FF).withValues(alpha: isOpen ? 0.22 : 0.16),
                        ),
                      ),
                      child: AnimatedSize(
                        duration: const Duration(milliseconds: 260),
                        curve: Curves.easeOutCubic,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                              child: Row(
                                children: [
                                  Container(
                                    width: 28,
                                    height: 28,
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [
                                          Color(0xFF2EA8FF),
                                          Color(0xFF8AD8FF),
                                        ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(0xFF2EA8FF).withValues(alpha: 0.20),
                                          blurRadius: 12,
                                          offset: const Offset(0, 6),
                                        ),
                                      ],
                                    ),
                                    child: Center(
                                      child: Text(
                                        _anonymousBadgeEmoji(previewMessage?.id ?? ''),
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          'Buzón anónimo',
                                          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                                color: const Color(0xFF0F172A),
                                                fontWeight: FontWeight.w800,
                                              ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Text(
                                          '$unseenCount nuevos',
                                          style: TextStyle(
                                            color: Colors.black.withValues(alpha: 0.50),
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Icon(
                                    isOpen ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                                    color: const Color(0xFF0F172A).withValues(alpha: 0.70),
                                  ),
                                ],
                              ),
                            ),
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 200),
                              switchInCurve: Curves.easeOutCubic,
                              switchOutCurve: Curves.easeInCubic,
                              child: isOpen
                                  ? Padding(
                                      key: const ValueKey('anonymous_open'),
                                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.stretch,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                            decoration: BoxDecoration(
                                              color: Colors.white.withValues(alpha: 0.50),
                                              borderRadius: BorderRadius.circular(18),
                                              border: Border.all(
                                                color: const Color(0xFF2EA8FF).withValues(alpha: 0.10),
                                              ),
                                            ),
                                            child: Text(
                                              anonymousMessages.isEmpty
                                                  ? 'No hay mensajes nuevos'
                                                  : 'Toca un mensaje para publicarlo en el chat',
                                              style: TextStyle(
                                                color: const Color(0xFF0F172A).withValues(alpha: 0.76),
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 10),
                                          for (final message in anonymousMessages.take(6)) ...[
                                            Padding(
                                              padding: const EdgeInsets.only(bottom: 8),
                                              child: Material(
                                                color: Colors.white.withValues(alpha: 0.48),
                                                borderRadius: BorderRadius.circular(20),
                                                child: InkWell(
                                                  borderRadius: BorderRadius.circular(20),
                                                  onTap: () async {
                                                    await _publishAnonymousMessage(message);
                                                  },
                                                  child: Padding(
                                                    padding: const EdgeInsets.all(12),
                                                    child: Row(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                        Container(
                                                          width: 20,
                                                          height: 20,
                                                          decoration: BoxDecoration(
                                                            gradient: const LinearGradient(
                                                              colors: [
                                                                Color(0xFF2EA8FF),
                                                                Color(0xFF8AD8FF),
                                                              ],
                                                              begin: Alignment.topLeft,
                                                              end: Alignment.bottomRight,
                                                            ),
                                                            shape: BoxShape.circle,
                                                          ),
                                                          child: Center(
                                                            child: Text(
                                                              _anonymousBadgeEmoji(message.id),
                                                              style: const TextStyle(fontSize: 10),
                                                            ),
                                                          ),
                                                        ),
                                                        const SizedBox(width: 10),
                                                        Expanded(
                                                          child: Text(
                                                            message.content,
                                                            maxLines: 3,
                                                            overflow: TextOverflow.ellipsis,
                                                            style: const TextStyle(
                                                              color: Color(0xFF0F172A),
                                                              fontWeight: FontWeight.w600,
                                                              height: 1.25,
                                                            ),
                                                          ),
                                                        ),
                                                        const SizedBox(width: 8),
                                                        Icon(
                                                          Icons.send_rounded,
                                                          color: const Color(0xFF2EA8FF).withValues(alpha: 0.72),
                                                          size: 16,
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    )
                                  : Padding(
                                      key: const ValueKey('anonymous_closed'),
                                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(alpha: 0.44),
                                          borderRadius: BorderRadius.circular(18),
                                          border: Border.all(
                                            color: const Color(0xFF2EA8FF).withValues(alpha: 0.08),
                                          ),
                                        ),
                                        child: Text(
                                          previewMessage?.content ?? 'Sin mensajes nuevos',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: Color(0xFF0F172A),
                                            fontWeight: FontWeight.w600,
                                            height: 1.25,
                                          ),
                                        ),
                                      ),
                                    ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
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

  Future<void> _shareChatScreenshot() async {
    try {
      await WidgetsBinding.instance.endOfFrame;
      final boundary = _screenshotKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        throw StateError('No se pudo capturar la pantalla.');
      }

      final image = await boundary.toImage(pixelRatio: 3);
      final byteData = await image.toByteData(format: ImageByteFormat.png);
      if (byteData == null) {
        throw StateError('No se pudo generar la imagen.');
      }

      final file = File(
        '${Directory.systemTemp.path}/vibeloop_chat_${widget.groupId}_${DateTime.now().millisecondsSinceEpoch}.png',
      );
      await file.writeAsBytes(byteData.buffer.asUint8List(), flush: true);

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          text: 'Captura del chat de VIBELOOP',
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo generar la captura: $error')),
      );
    }
  }

  Widget _buildAnonymousPublishedBubble(
    BuildContext context,
    MessageModel message,
    ColorScheme colorScheme,
  ) {
    const reactionOptions = ['👍', '❤️', '😂', '😮', '😢', '🔥'];

    return GestureDetector(
      onLongPress: () async {
        final reaction = await showModalBottomSheet<String>(
          context: context,
          isScrollControlled: true,
          useSafeArea: true,
          backgroundColor: colorScheme.surface,
          builder: (context) {
            return SafeArea(
              top: false,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.55),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: reactionOptions
                        .map(
                          (emoji) => ActionChip(
                            label: Text(emoji, style: const TextStyle(fontSize: 20)),
                            onPressed: () => Navigator.of(context).pop(emoji),
                          ),
                        )
                        .toList(),
                  ),
                ),
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
          gradient: const LinearGradient(
            colors: [
              Color(0xFFFF4D8D),
              Color(0xFFFF7A45),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(22),
            topRight: Radius.circular(22),
            bottomLeft: Radius.circular(8),
            bottomRight: Radius.circular(22),
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
            Row(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      _anonymousBadgeEmoji(message.id),
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Mensaje anónimo',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              message.content,
              style: const TextStyle(
                color: Colors.white,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _publishAnonymousMessage(AnonymousMessageModel message) async {
    await ref.read(anonymousRepositoryProvider).publishAnonymousMessage(message);
    if (!mounted) return;
    setState(() {
      _anonymousBubbleOpen = true;
      _messagesStream = ref.read(chatRepositoryProvider).watchMessages(widget.groupId);
    });
    _scrollToBottom();
  }

  String _anonymousBadgeEmoji(String seed) {
    const badgeEmojis = ['âœ‰ï¸', 'ðŸ’Œ', 'âœ¨', 'ðŸŒ™', 'ðŸ’™', 'ðŸ«¶'];
    if (seed.isEmpty) return badgeEmojis.first;
    return badgeEmojis[seed.hashCode.abs() % badgeEmojis.length];
  }
  Future<void> _openEmojiPicker() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (context) {
        final colorScheme = Theme.of(context).colorScheme;
        return SafeArea(
          top: false,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.58),
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                16,
                8,
                16,
                20 + MediaQuery.viewPaddingOf(context).bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Escoge tu emoji', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 10),
                  Text(
                    'Este emoji te identificará en el chat.',
                    style: TextStyle(color: colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: profileEmojis
                        .map(
                          (emoji) => ChoiceChip(
                            label: Text(emoji, style: const TextStyle(fontSize: 18)),
                            selected: emoji == _currentUserEmoji,
                            onSelected: (_) => Navigator.of(context).pop(emoji),
                            selectedColor: colorScheme.primary.withValues(alpha: 0.14),
                            side: BorderSide(color: colorScheme.outline.withValues(alpha: 0.35)),
                          ),
                        )
                        .toList(),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    if (selected == null || selected == _currentUserEmoji) return;

    await ref.read(authRepositoryProvider).updateEmoji(selected);
    if (!mounted) return;
    setState(() {
      _currentUserEmoji = selected;
      _messagesStream = ref.read(chatRepositoryProvider).watchMessages(widget.groupId);
    });
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
    unawaited(AdService.instance.showInterstitialAfterInviteShared());
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

    return RepaintBoundary(
      key: _screenshotKey,
      child: Scaffold(
        appBar: AppBar(
        title: Text('Grupo ${widget.groupId.substring(0, 6)}'),
        actions: [
            IconButton(
              tooltip: 'Compartir captura',
              onPressed: _shareChatScreenshot,
              icon: const Icon(Icons.screenshot_monitor_outlined),
            ),
          IconButton(
            tooltip: 'Agregar foto al collage',
            onPressed: () => context.push('/groups/${widget.groupId}/photos'),
            icon: const Icon(Icons.add_a_photo_outlined),
          ),
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
      body: StreamBuilder<List<AnonymousMessageModel>>(
        stream: _anonymousMessagesStream,
        builder: (context, anonymousSnapshot) {
          final anonymousMessages = anonymousSnapshot.data ?? const <AnonymousMessageModel>[];
          return Stack(
            children: [
              Column(
                children: [
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

                        final feedEntries = _buildFeedEntries(messages);

                        return ListView.separated(
                          controller: _scrollController,
                          reverse: true,
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
                          itemCount: feedEntries.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final entry = feedEntries[index];

                            final message = entry.message;
                            if (message.type == 'anonymous') {
                              return Align(
                                alignment: Alignment.centerLeft,
                                child: _buildAnonymousPublishedBubble(context, message, colorScheme),
                              );
                            }

                            final isMine = message.senderId == currentUserId;
                            final senderLabel = isMine ? _currentUserEmoji : message.senderName;

                            return Align(
                              alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
                              child: GestureDetector(
                                onLongPress: () async {
                                  final reaction = await showModalBottomSheet<String>(
                                    context: context,
                                    isScrollControlled: true,
                                    useSafeArea: true,
                                    backgroundColor: colorScheme.surface,
                                    builder: (context) {
                                      return SafeArea(
                                        top: false,
                                        child: ConstrainedBox(
                                          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.55),
                                          child: SingleChildScrollView(
                                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
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
                                          ),
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
                                        senderLabel,
                                        style: TextStyle(
                                          fontSize: 18,
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
                  if (_otherTypingUsers.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                      child: Container(
                        width: double.infinity,
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
                    ),
                  if (_otherTypingUsers.isNotEmpty) const SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: _openEmojiPicker,
                        icon: Text(_currentUserEmoji, style: const TextStyle(fontSize: 18)),
                        label: const Text('Escoge tu emoji'),
                      ),
                    ),
                  ),
                  SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
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
              Positioned(
                top: 12,
                right: 12,
                child: _buildAnonymousFloatingBubble(context, anonymousMessages),
              ),
            ],
          );
        },
      ),
    ),
  );
  }
}
