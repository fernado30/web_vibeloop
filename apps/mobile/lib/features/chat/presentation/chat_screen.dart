import 'dart:async';
import 'dart:io';

import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/ads/ad_service.dart';
import '../../../core/theme/vibe_tokens.dart';
import '../../../core/widgets/vibe_svg_icon.dart';
import '../../../core/widgets/vibe_ui.dart';
import '../../../core/utils/profile_emojis.dart';
import '../../../core/utils/error_helper.dart';
import '../../auth/data/auth_repository.dart';
import '../../anonymous/data/anonymous_repository.dart';
import '../../anonymous/domain/anonymous_message_model.dart';
import '../../groups/data/groups_repository.dart';
import '../../groups/domain/group_model.dart';
import '../data/chat_repository.dart';
import '../domain/message_model.dart';
import '../../settings/data/safety_repository.dart';
import '../../settings/presentation/report_bottom_sheet.dart';

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

sealed class _MessageMenuSelection {
  const _MessageMenuSelection();
}

final class _MessageMenuReactionSelection extends _MessageMenuSelection {
  const _MessageMenuReactionSelection(this.emoji);

  final String emoji;
}

final class _MessageMenuActionSelection extends _MessageMenuSelection {
  const _MessageMenuActionSelection(this.action);

  final _MessageMenuAction action;
}

enum _MessageMenuAction { edit, delete, report }

class _EditMessageDialog extends StatefulWidget {
  const _EditMessageDialog({required this.initialText});

  final String initialText;

  @override
  State<_EditMessageDialog> createState() => _EditMessageDialogState();
}

class _EditMessageDialogState extends State<_EditMessageDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialText);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    final value = _controller.text.trim();
    if (value.isEmpty || value == widget.initialText) {
      Navigator.of(context).pop();
      return;
    }

    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Editar mensaje'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLines: 4,
        minLines: 1,
        maxLength: 500,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(
          hintText: 'Escribe tu mensaje...',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _save,
          child: const Text('Guardar'),
        ),
      ],
    );
  }
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
  final Object _anonymousTapRegionGroupId = Object();
  final Set<String> _deletedMessageIds = <String>{};
  OverlayEntry? _anonymousBubbleOverlayEntry;
  List<AnonymousMessageModel> _latestAnonymousMessages = const <AnonymousMessageModel>[];
  bool _anonymousOverlayRefreshScheduled = false;
  Timer? _typingTimer;
  bool _isTyping = false;
  String _currentUserEmoji = '\u{1F642}';

  @override
  void initState() {
    super.initState();
    ref.listenManual<int>(safetyFiltersRevisionProvider, (_, __) {
      if (!mounted) return;
      setState(() {
        _messagesStream = ref.read(chatRepositoryProvider).watchMessages(widget.groupId);
        _anonymousMessagesStream = ref.read(anonymousRepositoryProvider).watchAnonymousMessages(widget.groupId);
      });
    });
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
      _currentUserEmoji = profile?['emoji']?.toString() ?? '\u{1F642}';
    });
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
    _removeAnonymousBubbleOverlay();
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
    } catch (error, stackTrace) {
      await FirebaseCrashlytics.instance.recordError(
        error,
        stackTrace,
        reason: 'Error enviando mensaje al chat del grupo',
        fatal: false,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_friendlyChatError(error))),
      );
    }
  }

  void _refreshAnonymousMessagesStream() {
    _anonymousMessagesStream = ref.read(anonymousRepositoryProvider).watchAnonymousMessages(widget.groupId);
  }

  Future<void> _reactToMessage(String messageId, String emoji) async {
    await ref.read(chatRepositoryProvider).reactToMessage(messageId, emoji);
  }

  Future<String?> _showReactionPicker(BuildContext context, ColorScheme colorScheme) async {
    const reactionOptions = [
      '\u{1F44D}',
      '\u{2764}\u{FE0F}',
      '\u{1F602}',
      '\u{1F62E}',
      '\u{1F622}',
      '\u{1F525}',
    ];

    return showModalBottomSheet<String>(
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
  }

  Future<_MessageMenuSelection?> _showMessageMenu(
    BuildContext context, {
    required ColorScheme colorScheme,
    required bool allowEditAndDelete,
  }) {
    const reactionOptions = [
      '\u{1F44D}',
      '\u{2764}\u{FE0F}',
      '\u{1F602}',
      '\u{1F62E}',
      '\u{1F622}',
      '\u{1F525}',
    ];

    return showModalBottomSheet<_MessageMenuSelection>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: colorScheme.surface,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final actionColor = isDark ? Colors.white.withValues(alpha: 0.86) : colorScheme.onSurface;

        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  alignment: WrapAlignment.center,
                  children: reactionOptions
                      .map(
                        (emoji) => ActionChip(
                          label: Text(emoji, style: const TextStyle(fontSize: 20)),
                          onPressed: () => Navigator.of(context).pop(_MessageMenuReactionSelection(emoji)),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 16),
                Divider(height: 1, color: colorScheme.outline.withValues(alpha: 0.18)),
                const SizedBox(height: 8),
                if (allowEditAndDelete) ...[
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.edit_rounded, color: actionColor),
                    title: Text(
                      'Editar mensaje',
                      style: TextStyle(
                        color: actionColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    onTap: () => Navigator.of(context).pop(const _MessageMenuActionSelection(_MessageMenuAction.edit)),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.delete_outline_rounded, color: Color(0xFFF43F5E)),
                    title: const Text(
                      'Eliminar mensaje',
                      style: TextStyle(
                        color: Color(0xFFF43F5E),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    onTap: () => Navigator.of(context).pop(const _MessageMenuActionSelection(_MessageMenuAction.delete)),
                  ),
                ],
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.flag_outlined, color: Color(0xFFF43F5E)),
                  title: const Text(
                    'Denunciar mensaje',
                    style: TextStyle(
                      color: Color(0xFFF43F5E),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  onTap: () => Navigator.of(context).pop(const _MessageMenuActionSelection(_MessageMenuAction.report)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _handleMessageLongPress(
    BuildContext context,
    MessageModel message, {
    required bool isMine,
    required ColorScheme colorScheme,
  }) async {
    final selection = await _showMessageMenu(
      context,
      colorScheme: colorScheme,
      allowEditAndDelete: isMine,
    );

    if (selection == null) return;

    if (selection is _MessageMenuReactionSelection) {
      await _reactToMessage(message.id, selection.emoji);
      return;
    }

    if (selection is _MessageMenuActionSelection) {
      switch (selection.action) {
        case _MessageMenuAction.edit:
          await _editMessage(message);
          break;
        case _MessageMenuAction.delete:
          await _deleteMessage(message);
          break;
        case _MessageMenuAction.report:
          final reported = await ReportBottomSheet.show(
            context,
            targetType: message.type == 'anonymous' ? 'anonymous_message' : 'message',
            targetId: message.id,
            title: message.type == 'anonymous' ? 'Denunciar mensaje anónimo' : 'Denunciar mensaje',
            snippet: message.content,
          );
          if (reported == true && mounted) {
            setState(() {
              _deletedMessageIds.add(message.id);
            });
          }
          break;
      }
    }
  }

  Future<void> _editMessage(MessageModel message) async {
    try {
      final updatedContent = await showDialog<String>(
        context: context,
        builder: (dialogContext) => _EditMessageDialog(initialText: message.content),
      );

      if (updatedContent == null) return;

      await ref.read(chatRepositoryProvider).editMessage(message.id, updatedContent);
    } catch (error, stackTrace) {
      await FirebaseCrashlytics.instance.recordError(
        error,
        stackTrace,
        reason: 'Error editando mensaje del chat del grupo',
        fatal: false,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_friendlyChatError(error))),
      );
    }
  }

  Future<void> _deleteMessage(MessageModel message) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Eliminar mensaje'),
          content: const Text('Este mensaje se borrará para todos los miembros del grupo.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton.tonal(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Eliminar'),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true) return;

    try {
      if (mounted) {
        setState(() {
          _deletedMessageIds.add(message.id);
        });
      }

      await ref.read(chatRepositoryProvider).deleteMessage(message.id);
    } catch (error, stackTrace) {
      if (mounted) {
        setState(() {
          _deletedMessageIds.remove(message.id);
        });
      }

      await FirebaseCrashlytics.instance.recordError(
        error,
        stackTrace,
        reason: 'Error eliminando mensaje del chat del grupo',
        fatal: false,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_friendlyChatError(error))),
      );
    }
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
        text: 'Captura del chat de Nadie',
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo generar la captura: $error')),
      );
    }
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

  void _ensureAnonymousBubbleOverlay() {
    if (_anonymousBubbleOverlayEntry != null) return;

    _anonymousBubbleOverlayEntry = OverlayEntry(
      builder: (overlayContext) => _buildAnonymousBubbleOverlay(overlayContext),
    );

    Overlay.of(context, rootOverlay: true).insert(_anonymousBubbleOverlayEntry!);
  }

  void _removeAnonymousBubbleOverlay() {
    final overlayEntry = _anonymousBubbleOverlayEntry;
    if (overlayEntry == null) return;
    _anonymousBubbleOverlayEntry = null;
    overlayEntry.remove();
  }

  void _scheduleAnonymousBubbleOverlayRefresh(List<AnonymousMessageModel> anonymousMessages) {
    _latestAnonymousMessages = anonymousMessages;
    if (!_anonymousBubbleOpen || _anonymousBubbleOverlayEntry == null || _anonymousOverlayRefreshScheduled) {
      return;
    }

    _anonymousOverlayRefreshScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _anonymousOverlayRefreshScheduled = false;
      if (!mounted || !_anonymousBubbleOpen) return;
      _anonymousBubbleOverlayEntry?.markNeedsBuild();
    });
  }

  void _toggleAnonymousBubble(List<AnonymousMessageModel> anonymousMessages) {
    setState(() {
      final opening = !_anonymousBubbleOpen;
      _anonymousBubbleOpen = opening;
      _latestAnonymousMessages = anonymousMessages;

      if (!opening && anonymousMessages.isNotEmpty) {
        _lastAnonymousSeenAt = anonymousMessages.first.createdAt;
      }
    });

    if (_anonymousBubbleOpen) {
      _ensureAnonymousBubbleOverlay();
      _anonymousBubbleOverlayEntry?.markNeedsBuild();
    } else {
      _removeAnonymousBubbleOverlay();
    }
  }

  void _closeAnonymousBubble([List<AnonymousMessageModel>? anonymousMessages]) {
    if (!_anonymousBubbleOpen) return;

    final messages = anonymousMessages ?? _latestAnonymousMessages;
    setState(() {
      _anonymousBubbleOpen = false;
      if (messages.isNotEmpty) {
        _lastAnonymousSeenAt = messages.first.createdAt;
      }
    });
    _removeAnonymousBubbleOverlay();
  }

  Widget _buildAnonymousBubbleOverlay(BuildContext context) {
    final anonymousMessages = _latestAnonymousMessages;
    if (anonymousMessages.isEmpty && !_anonymousBubbleOpen) {
      return const SizedBox.shrink();
    }

    final unseenCount = _unseenAnonymousMessages(anonymousMessages).length;
    final isOpen = _anonymousBubbleOpen;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return TapRegion(
      groupId: _anonymousTapRegionGroupId,
      onTapOutside: (_) => _closeAnonymousBubble(anonymousMessages),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(top: 78, right: 8),
          child: Align(
            alignment: Alignment.topRight,
            child: GestureDetector(
              onTap: () => _toggleAnonymousBubble(anonymousMessages),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                width: isOpen ? 220 : 174,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDark
                        ? const [
                            Color(0xFF5531C0),
                            Color(0xFF7C3AED),
                            Color(0xFF9F7AEA),
                          ]
                        : const [
                            Color(0xFF6D5AF7),
                            Color(0xFF8B5CF6),
                            Color(0xFFB85BF7),
                          ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF8B5CF6).withValues(alpha: isDark ? 0.28 : 0.24),
                      blurRadius: 24,
                      offset: const Offset(0, 12),
                    ),
                    BoxShadow(
                      color: const Color(0xFFF9C2FF).withValues(alpha: isDark ? 0.08 : 0.18),
                      blurRadius: 28,
                      offset: const Offset(0, 16),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(28),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                    child: DefaultTextStyle.merge(
                      style: const TextStyle(decoration: TextDecoration.none),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: isDark ? 0.08 : 0.12),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: isDark ? 0.12 : 0.18),
                          ),
                          borderRadius: BorderRadius.circular(28),
                        ),
                        child: AnimatedSize(
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeOutCubic,
                          alignment: Alignment.topCenter,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                              child: Row(
                                children: [
                                  Container(
                                    width: 30,
                                    height: 30,
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [
                                          Color(0xFF9D7CFF),
                                          Color(0xFFD36BFF),
                                        ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.10),
                                          blurRadius: 8,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: const Center(
                                      child: Icon(
                                        Icons.mail_outline_rounded,
                                        size: 18,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                'Buzón anónimo',
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.w800,
                                                  fontSize: 13,
                                                  letterSpacing: -0.1,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                              decoration: BoxDecoration(
                                                color: Colors.white.withValues(alpha: 0.16),
                                                borderRadius: BorderRadius.circular(999),
                                              ),
                                              child: Text(
                                                '$unseenCount',
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w800,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '$unseenCount nuevos',
                                          style: TextStyle(
                                            color: Colors.white.withValues(alpha: 0.78),
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Icon(
                                    isOpen ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_right_rounded,
                                    color: Colors.white.withValues(alpha: 0.9),
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
                                            anonymousMessages.isEmpty ? 'Sin mensajes nuevos' : 'Toca uno para publicarlo',
                                            style: TextStyle(
                                              color: Colors.white.withValues(alpha: 0.82),
                                              fontWeight: FontWeight.w600,
                                              fontSize: 11,
                                              decoration: TextDecoration.none,
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
                                                              colors: [Color(0xFFB794F4), Color(0xFFF0ABFC)],
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
                                                              decoration: TextDecoration.none,
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
                                  : const SizedBox.shrink(),
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
    ));
  }

  Widget _buildChatBackdrop(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? const [
                  Color(0xFF040814),
                  Color(0xFF090D1D),
                  Color(0xFF05070F),
                ]
              : const [
                  Color(0xFFF9FBFF),
                  Color(0xFFF4F7FF),
                  Color(0xFFFBF8FF),
                ],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -20,
            left: -40,
            child: _ChatGlow(
              size: 220,
              color: isDark ? const Color(0xFF6D28D9).withValues(alpha: 0.20) : const Color(0xFFB5D4FF).withValues(alpha: 0.56),
            ),
          ),
          Positioned(
            top: 40,
            right: -26,
            child: _ChatGlow(
              size: 180,
              color: isDark ? const Color(0xFF7C3AED).withValues(alpha: 0.14) : const Color(0xFFF7C6FF).withValues(alpha: 0.56),
            ),
          ),
          Positioned(
            bottom: 160,
            left: -18,
            child: _ChatGlow(
              size: 240,
              color: isDark ? const Color(0xFF0EA5E9).withValues(alpha: 0.08) : const Color(0xFFD4C7FF).withValues(alpha: 0.36),
            ),
          ),
          Positioned(
            bottom: 40,
            right: -24,
            child: _ChatGlow(
              size: 220,
              color: isDark ? const Color(0xFFEC4899).withValues(alpha: 0.07) : const Color(0xFFFBCFE8).withValues(alpha: 0.42),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatMessageBubble(
    BuildContext context, {
    required MessageModel message,
    required String senderLabel,
    required bool isMine,
    required ColorScheme colorScheme,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final timeLabel = MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(message.createdAt));
    final bubbleGradient = isMine
        ? const LinearGradient(
            colors: [
              Color(0xFF4F46E5),
              Color(0xFF6D28D9),
              Color(0xFFEC4899),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          )
        : null;
    final bubbleColor = isMine
        ? null
        : isDark
            ? const Color(0xFF101425).withValues(alpha: 0.88)
            : Colors.white.withValues(alpha: 0.96);
    final borderColor = isMine
        ? Colors.transparent
        : isDark
            ? Colors.white.withValues(alpha: 0.05)
            : colorScheme.outline.withValues(alpha: 0.14);
    final textColor = isMine ? Colors.white : (isDark ? Colors.white : colorScheme.onSurface);
    final metaColor = isMine
        ? Colors.white.withValues(alpha: 0.72)
        : (isDark ? Colors.white.withValues(alpha: 0.70) : colorScheme.onSurfaceVariant);

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth.isFinite ? constraints.maxWidth : MediaQuery.sizeOf(context).width;
        final widthCap = (availableWidth - 56).clamp(176.0, 308.0).toDouble();
        final bubbleMaxWidth = isMine ? widthCap : widthCap.clamp(176.0, 300.0).toDouble();
        Widget bubbleBody({bool includeReactions = true}) {
          return IntrinsicWidth(
            child: Column(
              crossAxisAlignment: isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: bubbleMaxWidth),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: bubbleGradient,
                      color: bubbleColor,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(22),
                        topRight: const Radius.circular(22),
                        bottomLeft: Radius.circular(isMine ? 22 : 12),
                        bottomRight: Radius.circular(isMine ? 12 : 22),
                      ),
                      border: Border.all(color: borderColor),
                      boxShadow: [
                        BoxShadow(
                          color: isMine
                              ? const Color(0xFF7C3AED).withValues(alpha: isDark ? 0.24 : 0.18)
                              : Colors.black.withValues(alpha: isDark ? 0.24 : 0.10),
                          blurRadius: 24,
                          offset: const Offset(0, 12),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.fromLTRB(14, 11, 12, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          message.content,
                          textWidthBasis: TextWidthBasis.longestLine,
                          softWrap: true,
                          style: TextStyle(
                            fontSize: 16,
                            height: 1.18,
                            fontWeight: FontWeight.w600,
                            color: textColor,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Align(
                          alignment: Alignment.centerRight,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                timeLabel,
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w600,
                                  color: metaColor,
                                ),
                              ),
                              if (isMine) ...[
                                const SizedBox(width: 4),
                                Icon(
                                  Icons.done_all_rounded,
                                  size: 14,
                                  color: metaColor,
                                ),
                              ],
                            ],
                  ),
                ),
              ],
            ),
          ),
        ),
                if (includeReactions && message.reactions.isNotEmpty) ...[
                  const SizedBox(height: 7),
                  ReactionBar(reactions: message.reactions, isMine: isMine),
                ],
              ],
            ),
          );
        }

        return Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (!isMine) ...[
              _MessageEmojiAvatar(
                emoji: senderLabel,
                isMine: isMine,
                isDark: isDark,
              ),
              const SizedBox(width: 10),
            ],
            bubbleBody(),
            if (isMine) ...[
              const SizedBox(width: 10),
              _MessageEmojiAvatar(
                emoji: senderLabel,
                isMine: isMine,
                isDark: isDark,
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildChatComposer(BuildContext context, ColorScheme colorScheme) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? const Color(0xFF141A2A).withValues(alpha: 0.94) : Colors.white;
    final borderColor = isDark ? Colors.white.withValues(alpha: 0.06) : const Color(0xFFE8EAF2);
    final iconBackground = isDark
        ? const Color(0xFF1D2640)
        : const Color(0xFFF3F7FF);
    final hintStyle = TextStyle(
      color: isDark ? Colors.white.withValues(alpha: 0.48) : const Color(0xFF8D97AA),
      fontSize: 15,
      fontWeight: FontWeight.w500,
    );
    final textStyle = TextStyle(
      color: colorScheme.onSurface,
      fontSize: 15,
      fontWeight: FontWeight.w500,
    );

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
        child: AnimatedBuilder(
          animation: _textController,
          builder: (context, _) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: surfaceColor,
                      borderRadius: BorderRadius.circular(26),
                      border: Border.all(color: borderColor),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: isDark ? 0.20 : 0.06),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(left: 2, bottom: 4),
                          child: GestureDetector(
                            onTap: _openEmojiPicker,
                            child: Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: iconBackground,
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 180),
                                  switchInCurve: Curves.easeOutCubic,
                                  switchOutCurve: Curves.easeInCubic,
                                  transitionBuilder: (child, animation) {
                                    return ScaleTransition(
                                      scale: animation,
                                      child: FadeTransition(opacity: animation, child: child),
                                    );
                                  },
                                  child: Text(
                                    _currentUserEmoji,
                                    key: ValueKey<String>(_currentUserEmoji),
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontSize: 19,
                                      height: 1,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                            child: TextField(
                              controller: _textController,
                              focusNode: _focusNode,
                              minLines: 1,
                              maxLines: 5,
                              style: textStyle,
                              textInputAction: TextInputAction.newline,
                              decoration: InputDecoration(
                                hintText: 'Escribe un mensaje...',
                                hintStyle: hintStyle,
                                border: InputBorder.none,
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(vertical: 8),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: GestureDetector(
                    onTap: _sendMessage,
                    child: Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFF4F46E5),
                            Color(0xFF8B5CF6),
                            Color(0xFFB85BF7),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF8B5CF6).withValues(alpha: 0.35),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.send_rounded,
                          size: 20,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildAnonymousPublishedBubble(
    BuildContext context,
    MessageModel message,
    ColorScheme colorScheme,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onLongPress: () async {
        final reaction = await _showReactionPicker(context, colorScheme);

        if (reaction != null) {
          await _reactToMessage(message.id, reaction);
        }
      },
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: -16,
            top: -10,
            child: _AnonymousSparkle(
              size: 14,
              color: const Color(0xFF7C3AED).withValues(alpha: 0.95),
            ),
          ),
          Positioned(
            left: -2,
            top: 10,
            child: _AnonymousSparkle(
              size: 10,
              color: const Color(0xFFB794F4).withValues(alpha: 0.85),
            ),
          ),
          Positioned(
            right: -12,
            bottom: -8,
            child: _AnonymousSparkle(
              size: 12,
              color: const Color(0xFF4F46E5).withValues(alpha: 0.90),
            ),
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(26),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: isDark ? 0.08 : 0.96),
                    borderRadius: BorderRadius.circular(26),
                    border: Border.all(
                      color: isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE9E7F5),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.26 : 0.12),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        height: 54,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Color(0xFF4F46E5),
                              Color(0xFF8B5CF6),
                              Color(0xFFFF4FA1),
                            ],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.16),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
                              ),
                              child: const Center(
                                child: Icon(Icons.mail_outline_rounded, size: 19, color: Colors.white),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                            child: Text(
                              '!mensajes anónimos!',
                              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 14,
                                    letterSpacing: 0.1,
                                    decoration: TextDecoration.none,
                                    decorationThickness: 0,
                                  ),
                            ),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 28),
                        child: Center(
                          child: Text(
                            message.content,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                              height: 1.15,
                              fontWeight: FontWeight.w800,
                              fontSize: 22,
                              decoration: TextDecoration.none,
                              decorationThickness: 0,
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
        ],
      ),
    );
  }

  Future<void> _publishAnonymousMessage(AnonymousMessageModel message) async {
    try {
      await ref.read(anonymousRepositoryProvider).publishAnonymousMessage(message);
      if (!mounted) return;
      setState(() {
        _anonymousBubbleOpen = true;
        _refreshAnonymousMessagesStream();
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
    if (isNetworkError(error)) {
      return getFriendlyNetworkError(actionContext: 'enviar el mensaje');
    }
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
    const badgeEmojis = [
      '\u{1F3C5}',
      '\u2728',
      '\u{1F31F}',
      '\u{1F4AB}',
      '\u{1F525}',
      '\u{1F396}\u{FE0F}',
    ];
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
        text: 'Únete a mi grupo en Nadie: $inviteLink',
      ),
    );
    unawaited(AdService.instance.showInterstitialAfterInviteShared());
  }

  Future<void> _shareWebInviteLink() async {
    try {
      final links = await _inviteLinksFuture;
      final webLinkUri = Uri.parse(links.webLink);
      final buzonLink = webLinkUri.replace(
        pathSegments: <String>[
          'buzon',
          ...webLinkUri.pathSegments.skip(1),
        ],
      ).toString();
      await SharePlus.instance.share(
        ShareParams(
          text: buzonLink,
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

  Future<void> _confirmAndDeleteGroup(String groupName) async {
    final confirmController = TextEditingController();
    final shouldDelete = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) {
            return AlertDialog(
              title: const Text('Eliminar grupo'),
              content: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Vas a eliminar "$groupName".\n'
                      'Se borrarán el chat, las fotos y la membresía de todos los miembros.',
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: confirmController,
                      textCapitalization: TextCapitalization.characters,
                      decoration: const InputDecoration(
                        labelText: 'Escribe ELIMINAR para confirmar',
                      ),
                      autofocus: true,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Cancelar'),
                ),
                ValueListenableBuilder<TextEditingValue>(
                  valueListenable: confirmController,
                  builder: (context, value, _) {
                    final canDelete = value.text.trim().toUpperCase() == 'ELIMINAR';
                    return FilledButton(
                      onPressed: canDelete ? () => Navigator.of(dialogContext).pop(true) : null,
                      style: FilledButton.styleFrom(
                        backgroundColor: VibeColors.dangerRed,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Eliminar'),
                    );
                  },
                ),
              ],
            );
          },
        ) ??
        false;

    confirmController.dispose();
    if (!shouldDelete || !mounted) {
      return;
    }

    try {
      await ref.read(groupsRepositoryProvider).deleteGroup(widget.groupId);
      if (!mounted) return;
      context.go('/groups');
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo eliminar el grupo: $error')),
      );
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
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    final colorScheme = Theme.of(context).colorScheme;
    final topInset = MediaQuery.of(context).padding.top;

    return RepaintBoundary(
      key: _screenshotKey,
      child: VibeScaffold(
        appBar: PreferredSize(
          preferredSize: Size.fromHeight(126 + topInset),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
              child: FutureBuilder<GroupModel>(
                future: _groupFuture,
                builder: (context, groupSnapshot) {
                  final groupName = groupSnapshot.data?.name ?? 'Grupo ${widget.groupId.substring(0, 6)}';
                  final memberCount = groupSnapshot.data?.memberCount;
                  final memberLabel = memberCount == null
                      ? 'Miembros'
                      : memberCount == 1
                          ? '1 miembro'
                          : '$memberCount miembros';
                  final isGroupOwner = currentUserId != null &&
                      groupSnapshot.data?.createdBy.trim() == currentUserId.trim();

                  return StreamBuilder<List<AnonymousMessageModel>>(
                    stream: _anonymousMessagesStream,
                    builder: (context, snapshot) {
                      final anonymousMessages = snapshot.data ?? const <AnonymousMessageModel>[];
                      final unseenCount = _unseenAnonymousMessages(anonymousMessages).length;

                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          _TopBarActionShell(
                            backgroundColor: Theme.of(context).brightness == Brightness.dark
                                ? const Color(0xFF14192A).withValues(alpha: 0.92)
                                : Colors.white.withValues(alpha: 0.94),
                            borderColor: Theme.of(context).brightness == Brightness.dark
                                ? const Color(0xFF2B3550)
                                : const Color(0xFFE7E9F1),
                            shadowColor: Colors.black.withValues(
                              alpha: Theme.of(context).brightness == Brightness.dark ? 0.28 : 0.10,
                            ),
                            child: IconButton(
                              tooltip: 'Volver',
                              onPressed: () => context.pop(),
                              icon: VibeSvgIcon(
                                VibeAssetIcons.arrowBack,
                                size: 21,
                                color: Theme.of(context).brightness == Brightness.dark
                                    ? const Color(0xFFD7DDF0)
                                    : colorScheme.onSurface,
                              ),
                            ),
                          ),
                          const SizedBox(width: 18),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  groupName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 19,
                                        letterSpacing: -0.3,
                                      ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '$memberLabel • Privado',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                        color: colorScheme.onSurfaceVariant,
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w600,
                                        decoration: TextDecoration.none,
                                        decorationThickness: 0,
                                      ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          _AnonymousInboxHeaderButton(
                            unseenCount: unseenCount,
                            isOpen: _anonymousBubbleOpen,
                            tapRegionGroupId: _anonymousTapRegionGroupId,
                            onTap: () => _toggleAnonymousBubble(anonymousMessages),
                            onTapOutside: () => _closeAnonymousBubble(anonymousMessages),
                          ),

                          const SizedBox(width: 12),
                          _ExpandableHeaderActionMenu(
                            screenshotLabel: 'Captura',
                            inviteLabel: 'Invitar',
                            shareLabel: 'Enlace web',
                            photosLabel: 'Fotos',
                            screenshotIconAsset: VibeAssetIcons.screenshot,
                            inviteIconAsset: VibeAssetIcons.invite,
                            shareIconAsset: VibeAssetIcons.share,
                            photosIconAsset: VibeAssetIcons.photos,
                            screenshotColor: VibeColors.primaryViolet,
                            inviteColor: VibeColors.successGreen,
                            shareColor: VibeColors.coralPink,
                            photosColor: VibeColors.electricBlue,
                            onScreenshotTap: _shareChatScreenshot,
                            onInviteTap: _shareInviteLink,
                            onShareTap: _shareWebInviteLink,
                            onPhotosTap: () => context.push('/groups/${widget.groupId}/photos'),
                            onReportGroupTap: () => ReportBottomSheet.show(
                              context,
                              targetType: 'group',
                              targetId: widget.groupId,
                              title: 'Denunciar grupo',
                            ),
                            showDeleteAction: isGroupOwner,
                            onDeleteTap: () => _confirmAndDeleteGroup(groupSnapshot.data?.name ?? 'este grupo'),
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ),
          body: StreamBuilder<List<AnonymousMessageModel>>(
              stream: _anonymousMessagesStream,
              builder: (context, anonymousSnapshot) {
                final anonymousMessages = anonymousSnapshot.data ?? const <AnonymousMessageModel>[];
                if (_anonymousBubbleOpen) {
                  _scheduleAnonymousBubbleOverlayRefresh(anonymousMessages);
                }
            return TapRegionSurface(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: IgnorePointer(
                      child: _buildChatBackdrop(context),
                    ),
                  ),
                  Column(
                    children: [
                      Expanded(
                        child: StreamBuilder<List<MessageModel>>(
                          stream: _messagesStream,
                          builder: (context, snapshot) {
                            final messages = snapshot.data ?? const <MessageModel>[];
                            final visibleMessages =
                                messages.where((message) => !_deletedMessageIds.contains(message.id)).toList();

                            if (visibleMessages.isNotEmpty) {
                              _scrollToBottom();
                            }

                          if (snapshot.connectionState == ConnectionState.waiting && visibleMessages.isEmpty) {
                            return const Center(child: CircularProgressIndicator());
                          }

                          final feedEntries = _buildFeedEntries(visibleMessages);

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
                                  onLongPress: () => _handleMessageLongPress(
                                    context,
                                    message,
                                    isMine: isMine,
                                    colorScheme: colorScheme,
                                  ),
                                  child: _buildChatMessageBubble(
                                    context,
                                    message: message,
                                    senderLabel: senderLabel,
                                    isMine: isMine,
                                    colorScheme: colorScheme,
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
                    _buildChatComposer(context, colorScheme),
                  ],
                ),
              ],
            ),
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
    this.horizontal = false,
  });

  final String label;
  final String iconAsset;
  final Color color;
  final VoidCallback onTap;
  final bool compact;
  final bool horizontal;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(horizontal ? 20 : 18),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: horizontal ? 12 : 0,
            vertical: compact ? 0 : 4,
          ),
          child: horizontal
              ? SizedBox(
                  height: 52,
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: VibeSvgIcon(iconAsset, size: 16, color: color),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.w700,
                                decoration: TextDecoration.none,
                                decorationThickness: 0,
                              ),
                        ),
                      ),
                    ],
                  ),
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: compact ? 54 : 54,
                      height: compact ? 54 : 54,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(compact ? 18 : 18),
                      ),
                      child: Center(
                        child: VibeSvgIcon(iconAsset, size: compact ? 22 : 22, color: color),
                      ),
                    ),
                    SizedBox(height: compact ? 10 : 6),
                    Text(
                      label,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            fontSize: compact ? 12 : null,
                            decoration: TextDecoration.none,
                            decorationThickness: 0,
                          ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _ExpandableHeaderActionMenu extends StatefulWidget {
  const _ExpandableHeaderActionMenu({
    required this.screenshotLabel,
    required this.inviteLabel,
    required this.shareLabel,
    required this.photosLabel,
    required this.screenshotIconAsset,
    required this.inviteIconAsset,
    required this.shareIconAsset,
    required this.photosIconAsset,
    required this.screenshotColor,
    required this.inviteColor,
    required this.shareColor,
    required this.photosColor,
    required this.onScreenshotTap,
    required this.onInviteTap,
    required this.onShareTap,
    required this.onPhotosTap,
    this.onReportGroupTap,
    required this.showDeleteAction,
    this.onDeleteTap,
  });

  final String screenshotLabel;
  final String inviteLabel;
  final String shareLabel;
  final String photosLabel;
  final String screenshotIconAsset;
  final String inviteIconAsset;
  final String shareIconAsset;
  final String photosIconAsset;
  final Color screenshotColor;
  final Color inviteColor;
  final Color shareColor;
  final Color photosColor;
  final VoidCallback onScreenshotTap;
  final VoidCallback onInviteTap;
  final VoidCallback onShareTap;
  final VoidCallback onPhotosTap;
  final VoidCallback? onReportGroupTap;
  final bool showDeleteAction;
  final VoidCallback? onDeleteTap;

  @override
  State<_ExpandableHeaderActionMenu> createState() => _ExpandableHeaderActionMenuState();
}

class _ExpandableHeaderActionMenuState extends State<_ExpandableHeaderActionMenu>
    with SingleTickerProviderStateMixin {
  final LayerLink _layerLink = LayerLink();
  final Object _tapRegionGroupId = Object();
  OverlayEntry? _overlayEntry;
  late final AnimationController _controller;
  bool _isOpen = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
      reverseDuration: const Duration(milliseconds: 180),
    );
  }

  @override
  void dispose() {
    _removeOverlay();
    _controller.dispose();
    super.dispose();
  }

  void _toggleMenu() {
    if (_isOpen) {
      _closeMenu();
    } else {
      _openMenu();
    }
  }

  void _openMenu() {
    if (_isOpen) return;
    setState(() {
      _isOpen = true;
    });
    _ensureOverlay();
    _controller.forward(from: 0);
  }

  void _closeMenu() {
    if (!_isOpen) return;
    setState(() {
      _isOpen = false;
    });
    _controller.reverse().whenComplete(() {
      if (!mounted || _isOpen) return;
      _removeOverlay();
    });
  }

  void _ensureOverlay() {
    if (_overlayEntry != null) return;
    final overlay = Overlay.of(context, rootOverlay: true);

    _overlayEntry = OverlayEntry(
      builder: (overlayContext) => _buildOverlay(overlayContext),
    );
    overlay.insert(_overlayEntry!);
  }

  void _removeOverlay() {
    final overlayEntry = _overlayEntry;
    if (overlayEntry == null) return;
    _overlayEntry = null;
    overlayEntry.remove();
  }

  void _triggerAction(VoidCallback action) {
    _removeOverlay();
    _isOpen = false;
    _controller.reset();
    if (mounted) {
      setState(() {});
    }
    action();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return TapRegion(
      groupId: _tapRegionGroupId,
      onTapOutside: (_) => _closeMenu(),
      child: CompositedTransformTarget(
        link: _layerLink,
        child: _GradientTopBarActionShell(
          colors: isDark
              ? const [
                  Color(0xFF5A31D8),
                  Color(0xFF7B4DFF),
                  Color(0xFFF042B5),
                ]
              : const [
                  Color(0xFF6D5AF7),
                  Color(0xFF8E5DF8),
                  Color(0xFFF04FC0),
                ],
          shadowColor: Colors.black.withValues(alpha: isDark ? 0.24 : 0.14),
          onTap: _toggleMenu,
          child: Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, animation) {
                return RotationTransition(
                  turns: Tween<double>(begin: 0.85, end: 1.0).animate(animation),
                  child: ScaleTransition(scale: animation, child: child),
                );
              },
              child: Icon(
                Icons.more_vert_rounded,
                key: ValueKey<bool>(_isOpen),
                color: Colors.white,
                size: 22,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOverlay(BuildContext overlayContext) {
    final isDark = Theme.of(overlayContext).brightness == Brightness.dark;
    final panelBg = isDark ? const Color(0xFF0F1628).withValues(alpha: 0.96) : Colors.white.withValues(alpha: 0.98);
    final panelBorder = isDark ? Colors.white.withValues(alpha: 0.10) : const Color(0xFFE9ECF5);
    final menuWidth = MediaQuery.sizeOf(overlayContext).width.clamp(318.0, 392.0).toDouble();

    return Material(
      color: Colors.transparent,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final eased = Curves.easeOutCubic.transform(_controller.value);
          return CompositedTransformFollower(
            link: _layerLink,
            showWhenUnlinked: false,
            targetAnchor: Alignment.bottomRight,
            followerAnchor: Alignment.topRight,
            offset: const Offset(0, 8),
            child: IgnorePointer(
              ignoring: !_isOpen && _controller.value == 0,
              child: Opacity(
                opacity: eased,
                child: Transform.translate(
                  offset: Offset(0, 10 * (1 - eased)),
                  child: ClipRect(
                    child: Align(
                      alignment: Alignment.topRight,
                      heightFactor: eased,
                      child: TapRegion(
                        groupId: _tapRegionGroupId,
            child: _buildMenuPanel(
                          context: overlayContext,
                          panelBg: panelBg,
                          panelBorder: panelBorder,
                          menuWidth: menuWidth,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMenuPanel({
    required BuildContext context,
    required Color panelBg,
    required Color panelBorder,
    required double menuWidth,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              top: -7,
              right: 28,
              child: Transform.rotate(
                angle: 0.7853981633974483,
                child: Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: panelBg,
                    border: Border.all(color: panelBorder),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {},
              child: Container(
                width: menuWidth,
                constraints: const BoxConstraints(minWidth: 318, maxWidth: 392),
                padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
                decoration: BoxDecoration(
                  color: panelBg,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: panelBorder),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: Theme.of(context).brightness == Brightness.dark ? 0.28 : 0.10),
                      blurRadius: 22,
                      offset: const Offset(0, 14),
                    ),
                  ],
                ),
                child: DefaultTextStyle.merge(
                  style: const TextStyle(decoration: TextDecoration.none),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _HeaderActionTile(
                              label: widget.screenshotLabel,
                              iconAsset: widget.screenshotIconAsset,
                              color: widget.screenshotColor,
                              onTap: () => _triggerAction(widget.onScreenshotTap),
                              compact: true,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _HeaderActionTile(
                              label: widget.inviteLabel,
                              iconAsset: widget.inviteIconAsset,
                              color: widget.inviteColor,
                              onTap: () => _triggerAction(widget.onInviteTap),
                              compact: true,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _HeaderActionTile(
                              label: widget.shareLabel,
                              iconAsset: widget.shareIconAsset,
                              color: widget.shareColor,
                              onTap: () => _triggerAction(widget.onShareTap),
                              compact: true,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _HeaderActionTile(
                              label: widget.photosLabel,
                              iconAsset: widget.photosIconAsset,
                              color: widget.photosColor,
                              onTap: () => _triggerAction(widget.onPhotosTap),
                              compact: true,
                            ),
                          ),
                        ],
                      ),
                      if (widget.onReportGroupTap != null) ...[
                        const SizedBox(height: 10),
                        Container(
                          height: 1,
                          color: isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE9ECF5),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(
                              child: InkWell(
                                onTap: () => _triggerAction(widget.onReportGroupTap!),
                                borderRadius: BorderRadius.circular(12),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: const [
                                      Icon(Icons.flag_outlined, size: 16, color: Color(0xFFF43F5E)),
                                      SizedBox(width: 4),
                                      Text(
                                        'Denunciar grupo',
                                        style: TextStyle(
                                          color: Color(0xFFF43F5E),
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),

      ],
    );
  }
}

class _TopBarActionShell extends StatelessWidget {
  const _TopBarActionShell({
    required this.backgroundColor,
    required this.borderColor,
    required this.shadowColor,
    required this.child,
    this.onTap,
  });

  final Color backgroundColor;
  final Color borderColor;
  final Color shadowColor;
  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderColor),
            boxShadow: [
              BoxShadow(
                color: shadowColor,
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

class _GradientTopBarActionShell extends StatelessWidget {
  const _GradientTopBarActionShell({
    required this.colors,
    required this.shadowColor,
    required this.child,
    this.onTap,
  });

  final List<Color> colors;
  final Color shadowColor;
  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: colors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
            boxShadow: [
              BoxShadow(
                color: shadowColor,
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

class _AnonymousInboxHeaderButton extends StatelessWidget {
  const _AnonymousInboxHeaderButton({
    required this.unseenCount,
    required this.isOpen,
    required this.tapRegionGroupId,
    required this.onTap,
    required this.onTapOutside,
  });

  final int unseenCount;
  final bool isOpen;
  final Object tapRegionGroupId;
  final VoidCallback onTap;
  final VoidCallback onTapOutside;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final shadowColor = const Color(0xFF9B5CF6).withValues(alpha: isDark ? 0.32 : 0.26);
    final hasUnread = unseenCount > 0;

    return TapRegion(
      groupId: tapRegionGroupId,
      onTapOutside: (_) => onTapOutside(),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOutCubic,
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? const [
                        Color(0xFF5A31D8),
                        Color(0xFF7B4DFF),
                        Color(0xFFF042B5),
                      ]
                    : const [
                        Color(0xFF6D5AF7),
                        Color(0xFF8E5DF8),
                        Color(0xFFF04FC0),
                      ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: shadowColor,
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
                BoxShadow(
                  color: const Color(0xFFF4B3FF).withValues(alpha: isDark ? 0.10 : 0.20),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
              border: Border.all(
                color: Colors.white.withValues(alpha: isDark ? 0.12 : 0.20),
              ),
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                const Center(
                  child: Icon(
                    Icons.mail_outline_rounded,
                    size: 22,
                    color: Colors.white,
                  ),
                ),
                if (hasUnread)
                  Positioned(
                    top: -3,
                    right: -3,
                    child: Container(
                      width: 18,
                      height: 18,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF43F5E),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFF43F5E).withValues(alpha: 0.36),
                            blurRadius: 14,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Text(
                        unseenCount > 99 ? '99+' : '$unseenCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          height: 1.0,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ChatGlow extends StatelessWidget {
  const _ChatGlow({
    required this.size,
    required this.color,
  });

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            color,
            color.withValues(alpha: 0.0),
          ],
          stops: const [0.0, 1.0],
        ),
      ),
    );
  }
}

class _MessageEmojiAvatar extends StatelessWidget {
  const _MessageEmojiAvatar({
    required this.emoji,
    required this.isMine,
    required this.isDark,
  });

  final String emoji;
  final bool isMine;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final background = isDark
        ? const [Color(0xFFFFF4D8), Color(0xFFFFE7B8)]
        : const [Color(0xFFFFF8EA), Color(0xFFFFEED0)];
    final shadowColor = isMine
        ? const Color(0xFF7C3AED).withValues(alpha: isDark ? 0.28 : 0.18)
        : const Color(0xFF3B82F6).withValues(alpha: isDark ? 0.18 : 0.12);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: background,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(color: Colors.white.withValues(alpha: 0.92), width: 2),
            boxShadow: [
              BoxShadow(
                color: shadowColor,
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Center(
            child: Text(
              emoji,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 20, height: 1),
            ),
          ),
        ),
        Positioned(
          right: -1,
          bottom: 0,
          child: Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(
              color: isMine ? const Color(0xFF6366F1) : const Color(0xFF5B4BFF),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 1.4),
            ),
          ),
        ),
      ],
    );
  }
}

class _AnonymousSparkle extends StatelessWidget {
  const _AnonymousSparkle({
    required this.size,
    required this.color,
  });

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Icon(
      Icons.auto_awesome_rounded,
      size: size,
      color: color,
    );
  }
}


