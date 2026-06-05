import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/vibe_ui.dart';
import '../data/anonymous_repository.dart';
import '../domain/anonymous_message_model.dart';

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
      appBar: AppBar(title: const Text('Buzon anonimo')),
      body: RefreshIndicator(
        onRefresh: _reload,
        child: StreamBuilder<List<AnonymousMessageModel>>(
          stream: _messagesStream,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                children: const [LoadingStateCard(label: 'Cargando mensajes anonimos...')],
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
                    title: 'Todavia no hay mensajes anonimos',
                    body: 'Cuando lleguen nuevos mensajes, apareceran aqui para revisarlos en tiempo real.',
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
                    title: 'Inbox cuidado para conversaciones delicadas',
                    body: 'Revisa mensajes nuevos, detecta reacciones y mantiene la vista despejada para moderar mejor.',
                    badge: SafetyBadge(label: 'Anonimo'),
                  );
                }

                final message = messages[index - 1];
                return AnonymousMessageCard(
                  content: message.content,
                  reactions: message.reactions,
                );
              },
            );
          },
        ),
      ),
    );
  }
}
