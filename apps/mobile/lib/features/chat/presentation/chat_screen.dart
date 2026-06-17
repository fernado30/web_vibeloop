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
import '../../../core/theme/vibe_tokens.dart';
import '../../../core/widgets/vibe_svg_icon.dart';
import '../../../core/widgets/vibe_ui.dart';
import '../../../core/utils/profile_emojis.dart';
import '../../auth/data/auth_repository.dart';
import '../../anonymous/data/anonymous_repository.dart';
import '../../anonymous/domain/anonymous_message_model.dart';
import '../../groups/data/groups_repository.dart';
import '../../groups/domain/group_model.dart';
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
  late final Future<GroupModel> _groupFuture;
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  final _focusNode = FocusNode();
  final Set<String> _otherTypingUsers = <String>{};
  bool _anonymousBubbleOpen = false;
  DateTime? _lastAnonymousSeenAt;
  Timer? _typingTimer;
  bool _isTyping = false;
  String _currentUserEmoji = '🙂';

  @override
  void initState() {
    super.initState();
    _messagesStream = ref.read(chatRepositoryProvider).watchMessages(widget.groupId);
    _anonymousMessagesStream = ref.read(anonymousRepositoryProvider).watchAnonymousMessages(widget.groupId);
    _inviteLinksFuture = ref.read(groupsRepositoryProvider).generateInviteLinks(widget.groupId);
    _groupFuture = ref.read(groupsRepositoryProvider).getGroupById(widget.groupId);
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
      _currentUserEmoji = profile?['emoji']?.toString() ?? '🙂';
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
        padding: const EdgeInsets.only(top: 4, right: 8),
        child: Align(
          alignment: Alignment.topRight,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: isOpen ? 220 : 156),
            child: GestureDetector(
              onTap: () => _toggleAnonymousBubble(anonymousMessages),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutCubic,
                width: isOpen ? 220 : 156,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFF4338CA),
                      Color(0xFF7C3AED),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(isOpen ? 28 : 999),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF6D28D9).withValues(alpha: 0.26),
                      blurRadius: 22,
                      offset: const Offset(0, 10),
                    ),
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(isOpen ? 24 : 999),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.white.withValues(alpha: 0.12),
                            Colors.white.withValues(alpha: 0.04),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: isOpen ? 0.18 : 0.10),
                        ),
                      ),
                      child: AnimatedSize(
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOutCubic,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(10, 9, 10, 8),
                              child: Row(
                                children: [
                                  Container(
                                    width: 26,
                                    height: 26,
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [
                                          Color(0xFFB794F4),
                                          Color(0xFFF0ABFC),
                                        ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.10),
                                          blurRadius: 8,
                                          offset: const Offset(0, 4),
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
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          'Buzón anónimo',
                                          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                                color: Colors.white,
                                                fontWeight: FontWeight.w800,
                                                fontSize: 12,
                                              ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Text(
                                          '$unseenCount nuevos',
                                          style: TextStyle(
                                            color: Colors.white.withValues(alpha: 0.74),
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Icon(
                                    isOpen ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                                    color: Colors.white.withValues(alpha: 0.84),
                                    size: 18,
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
                                      padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.stretch,
                                        children: [
                                          Text(
                                            anonymousMessages.isEmpty
                                                ? 'Sin mensajes nuevos'
                                                : 'Toca uno para publicarlo',
                                            style: TextStyle(
                                              color: Colors.white.withValues(alpha: 0.82),
                                              fontWeight: FontWeight.w600,
                                              fontSize: 11,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          for (final message in anonymousMessages.take(3)) ...[
                                            Padding(
                                              padding: const EdgeInsets.only(bottom: 6),
                                              child: Material(
                                                color: Colors.white.withValues(alpha: 0.12),
                                                borderRadius: BorderRadius.circular(16),
                                                child: InkWell(
                                                  borderRadius: BorderRadius.circular(16),
                                                  onTap: () async {
                                                    await _publishAnonymousMessage(message);
                                                  },
                                                  child: Padding(
                                                    padding: const EdgeInsets.all(10),
                                                    child: Row(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                        Container(
                                                          width: 18,
                                                          height: 18,
                                                          decoration: BoxDecoration(
                                                            gradient: const LinearGradient(
                                                              colors: [
                                                                Color(0xFFB794F4),
                                                                Color(0xFFF0ABFC),
                                                              ],
                                                              begin: Alignment.topLeft,
                                                              end: Alignment.bottomRight,
                                                            ),
                                                            shape: BoxShape.circle,
                                                          ),
                                                          child: Center(
                                                            child: Text(
                                                              _anonymousBadgeEmoji(message.id),
                                                              style: const TextStyle(fontSize: 9),
                                                            ),
                                                          ),
                                                        ),
                                                        const SizedBox(width: 8),
                                                        Expanded(
                                                          child: Text(
                                                            message.content,
                                                            maxLines: 2,
                                                            overflow: TextOverflow.ellipsis,
                                                            style: const TextStyle(
                                                              color: Colors.white,
                                                              fontWeight: FontWeight.w600,
                                                              height: 1.2,
                                                              fontSize: 11,
                                                            ),
                                                          ),
                                                        ),
                                                        const SizedBox(width: 6),
                                                        Icon(
                                                          Icons.send_rounded,
                                                          color: Colors.white.withValues(alpha: 0.88),
                                                          size: 14,
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
                                        padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                          decoration: BoxDecoration(
                                            color: Colors.white.withValues(alpha: 0.12),
                                            borderRadius: BorderRadius.circular(16),
                                            border: Border.all(
                                              color: Colors.white.withValues(alpha: 0.14),
                                            ),
                                          ),
                                          child: Text(
                                            previewMessage?.content ?? 'Sin mensajes nuevos',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              color: Colors.white.withValues(alpha: 0.92),
                                              fontWeight: FontWeight.w600,
                                              height: 1.2,
                                              fontSize: 11,
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

    try {
      await ref.read(chatRepositoryProvider).sendMessage(widget.groupId, text, 'text');
      _textController.clear();
      await _setTyping(false);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_friendlyChatError(error))),
      );
    }
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
    const reactionOptions = ['ðŸ‘', 'â¤ï¸', 'ðŸ˜‚', 'ðŸ˜®', 'ðŸ˜¢', 'ðŸ”¥'];

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
        constraints: const BoxConstraints(maxWidth: 320, minWidth: 220),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [
              Color(0xFFFF5F8D),
              Color(0xFFFF8C4B),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
              child: Text(
                '!mensajes anónimos!',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      letterSpacing: 0.1,
                    ),
              ),
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 28),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(24),
                  bottomRight: Radius.circular(24),
                ),
              ),
              child: Text(
                message.content,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF0F172A),
                  height: 1.2,
                  fontWeight: FontWeight.w800,
                  fontSize: 22,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _publishAnonymousMessage(AnonymousMessageModel message) async {
    try {
      await ref.read(anonymousRepositoryProvider).publishAnonymousMessage(message);
      if (!mounted) return;
      setState(() {
        _anonymousBubbleOpen = true;
        _messagesStream = ref.read(chatRepositoryProvider).watchMessages(widget.groupId);
      });
      _scrollToBottom();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_friendlyChatError(error))),
      );
    }
  }

  String _friendlyChatError(Object error) {
    final message = error.toString();
    if (message.contains('rate_limited_cooldown')) {
      return 'Espera un momento antes de enviar otro mensaje.';
    }
    if (message.contains('rate_limited')) {
      return 'Has enviado muchos mensajes en poco tiempo. Intenta nuevamente en unos segundos.';
    }
    if (message.contains('Invalid message length') || message.contains('Invalid anonymous message length')) {
      return 'El mensaje debe tener entre 1 y 500 caracteres.';
    }
    if (message.contains('URLs are not allowed')) {
      return 'No se permiten enlaces en este tipo de mensaje.';
    }
    return 'No se pudo enviar el mensaje: $message';
  }

  String _anonymousBadgeEmoji(String seed) {
    const badgeEmojis = ['🏅', '✨', '🌟', '💫', '🔥', '🎖️'];
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
                  ),                  const SizedBox(height: 16),
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

  Future<void> _shareInviteLink() async {
    final links = await _inviteLinksFuture;
    final webLinkUri = Uri.parse(links.webLink);
    final inviteLink = webLinkUri.replace(
      pathSegments: <String>[
        'open',
        ...webLinkUri.pathSegments.skip(1),
      ],
    ).toString();
    await SharePlus.instance.share(
      ShareParams(
        text: 'Únete a mi grupo en VIBELOOP: $inviteLink',
      ),
    );
    unawaited(AdService.instance.showInterstitialAfterInviteShared());
  }

  Future<void> _shareWebInviteLink() async {
    try {
      final links = await _inviteLinksFuture;
      await SharePlus.instance.share(
        ShareParams(
          text: links.webLink,
        ),
      );
      unawaited(AdService.instance.showInterstitialAfterInviteShared());
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al generar el link web: $e')),
        );
      }
    }
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
      child: VibeScaffold(
        appBar: AppBar(
          leading: Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Material(
              color: Colors.white,
              shape: const CircleBorder(),
              child: IconButton(
                tooltip: 'Volver',
                onPressed: () => context.pop(),
                icon: VibeSvgIcon(VibeAssetIcons.arrowBack, size: 18, color: colorScheme.onSurface),
              ),
            ),
          ),
          leadingWidth: 48,
          titleSpacing: 4,
          toolbarHeight: 78,
          title: Row(
            children: [
              Expanded(
                child: FutureBuilder<GroupModel>(
                  future: _groupFuture,
                  builder: (context, snapshot) {
                    final groupName = snapshot.data?.name ?? 'Grupo ${widget.groupId.substring(0, 6)}';
                    final memberCount = snapshot.data?.memberCount;
                    final memberLabel = memberCount == null
                        ? 'Miembros'
                        : memberCount == 1
                            ? '1 miembro'
                            : '$memberCount miembros';

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          groupName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                                fontSize: 17,
                              ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          memberLabel,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                                fontSize: 11,
                              ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(width: 8),
              _HeaderActionTile(
                label: 'Pantallazo',
                iconAsset: VibeAssetIcons.screenshot,
                color: VibeColors.primaryViolet,
                onTap: _shareChatScreenshot,
                compact: true,
              ),
              const SizedBox(width: 6),
              _HeaderActionTile(
                label: 'Invitar',
                iconAsset: VibeAssetIcons.invite,
                color: VibeColors.successGreen,
                onTap: _shareInviteLink,
                compact: true,
              ),
              const SizedBox(width: 6),
              _HeaderActionTile(
                label: 'Link web',
                iconAsset: VibeAssetIcons.share,
                color: VibeColors.electricBlue,
                onTap: _shareWebInviteLink,
                compact: true,
              ),
              const SizedBox(width: 6),
              _HeaderActionTile(
                label: 'Fotos',
                iconAsset: VibeAssetIcons.photos,
                color: VibeColors.coralPink,
                onTap: () => context.push('/groups/${widget.groupId}/photos'),
                compact: true,
              ),
            ],
          ),
        ),
        body: StreamBuilder<List<AnonymousMessageModel>>(
          stream: _anonymousMessagesStream,
          builder: (context, anonymousSnapshot) {
            final anonymousMessages = anonymousSnapshot.data ?? const <AnonymousMessageModel>[];
            return Stack(
              children: [
                Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
                      child: _buildAnonymousFloatingBubble(context, anonymousMessages),
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

                          final feedEntries = _buildFeedEntries(messages);

                          return ListView.separated(
                            controller: _scrollController,
                            reverse: true,
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
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
                                                Color(0xFF7B61FF),
                                                Color(0xFF9D8CFF),
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
                                          ReactionBar(reactions: message.reactions, isMine: isMine),
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
                    SafeArea(
                      top: false,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                        child: GlassCard(
                          borderRadius: 28,
                          padding: const EdgeInsets.all(10),
                          child: Row(
                            children: [
                              GestureDetector(
                                onTap: _openEmojiPicker,
                                child: Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: VibeColors.primaryViolet.withValues(alpha: 0.10),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(
                                    child: Text(
                                      _currentUserEmoji,
                                      style: const TextStyle(fontSize: 20),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
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
                              const SizedBox(width: 10),
                              FilledButton(
                                onPressed: _sendMessage,
                                style: FilledButton.styleFrom(
                                  minimumSize: const Size(52, 52),
                                  padding: EdgeInsets.zero,
                                  backgroundColor: VibeColors.primaryViolet,
                                ),
                                child: VibeSvgIcon(VibeAssetIcons.send, size: 18, color: Colors.white),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _HeaderActionTile extends StatelessWidget {
  const _HeaderActionTile({
    required this.label,
    required this.iconAsset,
    required this.color,
    required this.onTap,
    this.compact = false,
  });

  final String label;
  final String iconAsset;
  final Color color;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: compact ? 0 : 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: compact ? 38 : 54,
                height: compact ? 38 : 54,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(compact ? 14 : 18),
                ),
                child: Center(
                  child: VibeSvgIcon(iconAsset, size: compact ? 17 : 22, color: color),
                ),
              ),
              SizedBox(height: compact ? 2 : 6),
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: compact ? 9.5 : null,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
