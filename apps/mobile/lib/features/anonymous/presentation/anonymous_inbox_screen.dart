import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/vibe_ui.dart';
import '../data/anonymous_repository.dart';
import '../domain/anonymous_message_model.dart';
import '../../settings/data/safety_repository.dart';
import '../../settings/presentation/report_bottom_sheet.dart';

class AnonymousInboxScreen extends ConsumerStatefulWidget {
  const AnonymousInboxScreen({super.key, required this.groupId});

  final String groupId;

  @override
  ConsumerState<AnonymousInboxScreen> createState() => _AnonymousInboxScreenState();
}

class _AnonymousInboxScreenState extends ConsumerState<AnonymousInboxScreen> {
  late Stream<List<AnonymousMessageModel>> _messagesStream;

  @override
  void initState() {
    super.initState();
    ref.listenManual<int>(safetyFiltersRevisionProvider, (_, __) {
      if (!mounted) return;
      setState(() {
        _messagesStream = ref.read(anonymousRepositoryProvider).watchAnonymousMessages(widget.groupId);
      });
    });
    _messagesStream = ref.read(anonymousRepositoryProvider).watchAnonymousMessages(widget.groupId);
  }

  Future<void> _reload() async {
    setState(() {
      _messagesStream = ref.read(anonymousRepositoryProvider).watchAnonymousMessages(widget.groupId);
    });
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }

  @override
  Widget build(BuildContext context) {
    return VibeScaffold(
      appBar: AppBar(title: const Text('Buzón anónimo')),
      body: RefreshIndicator(
        onRefresh: _reload,
        child: StreamBuilder<List<AnonymousMessageModel>>(
          stream: _messagesStream,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                children: const [LoadingStateCard(label: 'Cargando mensajes anónimos...')],
              );
            }

            final messages = snapshot.data ?? const <AnonymousMessageModel>[];
            if (messages.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                children: const [
                  SizedBox(height: 120),
                  EmptyStateCard(
                    title: 'Todavía no hay mensajes anónimos',
                    body: 'Cuando lleguen nuevos mensajes, aparecerán aquí para revisarlos en tiempo real.',
                  ),
                ],
              );
            }

            return ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              itemCount: messages.length + 1,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                if (index == 0) {
                  return const SectionIntroCard(
                    title: 'Bandeja cuidadosa para conversaciones delicadas',
                    body: 'Revisa mensajes nuevos, detecta reacciones y mantén la vista despejada para moderar mejor.',
                    badge: SafetyBadge(label: 'Anónimo'),
                  );
                }

                final message = messages[index - 1];
                return AnonymousMessageCard(
                  content: message.content,
                  reactions: message.reactions,
                  onReport: () async {
                    final reported = await ReportBottomSheet.show(
                      context,
                      targetType: 'anonymous_message',
                      targetId: message.id,
                      title: 'Denunciar mensaje anónimo',
                      snippet: message.content,
                    );
                    if (reported == true && mounted) {
                      _reload();
                    }
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }
}
