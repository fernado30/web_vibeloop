import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/anonymous_repository.dart';
import '../domain/anonymous_message_model.dart';

class AnonymousInboxScreen extends ConsumerStatefulWidget {
  const AnonymousInboxScreen({super.key, required this.groupId});

  final String groupId;

  @override
  ConsumerState<AnonymousInboxScreen> createState() => _AnonymousInboxScreenState();
}

class _AnonymousInboxScreenState extends ConsumerState<AnonymousInboxScreen> {
  late Future<List<AnonymousMessageModel>> _messagesFuture;

  @override
  void initState() {
    super.initState();
    _messagesFuture = ref.read(anonymousRepositoryProvider).fetchAnonymousMessages(widget.groupId);
  }

  Future<void> _reload() async {
    setState(() {
      _messagesFuture = ref.read(anonymousRepositoryProvider).fetchAnonymousMessages(widget.groupId);
    });
    await _messagesFuture;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Buzón anónimo')),
      body: RefreshIndicator(
        onRefresh: _reload,
        child: FutureBuilder<List<AnonymousMessageModel>>(
          future: _messagesFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final messages = snapshot.data ?? const <AnonymousMessageModel>[];
            if (messages.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(24),
                children: const [
                  SizedBox(height: 120),
                  Center(child: Text('Todavía no hay mensajes anónimos.')),
                ],
              );
            }

            return ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              itemCount: messages.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final message = messages[index];
                return Card(
                  color: Theme.of(context).colorScheme.surface,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Anónimo', style: TextStyle(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 8),
                        Text(message.content),
                        if (message.reactions.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: message.reactions.entries
                                .map(
                                  (entry) => ActionChip(
                                    label: Text('${entry.key} ${entry.value}'),
                                    onPressed: () => ref
                                        .read(anonymousRepositoryProvider)
                                        .reactToAnonymousMessage(message.id, entry.key),
                                  ),
                                )
                                .toList(),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
