import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/safety_repository.dart';

class HiddenWordsScreen extends ConsumerStatefulWidget {
  const HiddenWordsScreen({super.key});

  @override
  ConsumerState<HiddenWordsScreen> createState() => _HiddenWordsScreenState();
}

class _HiddenWordsScreenState extends ConsumerState<HiddenWordsScreen> {
  final _controller = TextEditingController();
  bool _loading = true;
  List<String> _words = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final words = await ref.read(safetyRepositoryProvider).fetchHiddenWords();
    if (!mounted) return;
    setState(() {
      _words = words;
      _loading = false;
    });
  }

  Future<void> _addWord() async {
    final value = _controller.text.trim();
    if (value.isEmpty) return;

    await ref.read(safetyRepositoryProvider).addHiddenWord(value);
    _controller.clear();
    await _load();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Palabra oculta guardada')),
    );
  }

  Future<void> _removeWord(String word) async {
    await ref.read(safetyRepositoryProvider).removeHiddenWord(word);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text('Palabras ocultas'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          const _IntroCard(
            title: 'Filtra palabras que no quieras ver',
            body:
                'Cuando una palabra oculta coincida con un mensaje, VIBELOOP puede reemplazarlo por un aviso corto para que el chat se mantenga más cómodo para ti.',
          ),
          const SizedBox(height: 16),
          _AddWordCard(
            controller: _controller,
            onAdd: _addWord,
          ),
          const SizedBox(height: 16),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_words.isEmpty)
            const _EmptyState(
              title: 'Aún no tienes palabras ocultas.',
              body: 'Agrega una palabra para empezar a ocultar contenido en el chat y en el buzón anónimo.',
            )
          else
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _words
                  .map(
                    (word) => InputChip(
                      label: Text(word),
                      onDeleted: () => _removeWord(word),
                    ),
                  )
                  .toList(),
            ),
        ],
      ),
    );
  }
}

class _IntroCard extends StatelessWidget {
  const _IntroCard({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF111827),
                ),
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: const TextStyle(
              height: 1.45,
              color: Color(0xFF4B5563),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _AddWordCard extends StatelessWidget {
  const _AddWordCard({required this.controller, required this.onAdd});

  final TextEditingController controller;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Agregar palabra',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: controller,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => onAdd(),
            decoration: const InputDecoration(
              hintText: 'Ej. spam, grosería, tema sensible...',
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add),
            label: const Text('Guardar palabra'),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text(body, style: const TextStyle(height: 1.45, color: Color(0xFF4B5563))),
        ],
      ),
    );
  }
}
