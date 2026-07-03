import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/vibe_ui.dart';
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
    return VibeScaffold(
      appBar: AppBar(title: const Text('Palabras ocultas')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          const SectionIntroCard(
            title: 'Filtra palabras que no quieras ver',
            body: 'Cuando una palabra oculta coincida con un mensaje, VIBELOOP puede reemplazarlo por un aviso corto para que el chat se mantenga más cómodo para ti.',
            badge: SafetyBadge(label: 'Filtro personal'),
          ),
          const SizedBox(height: 16),
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Agregar palabra', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 12),
                TextField(
                  controller: _controller,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _addWord(),
                  decoration: const InputDecoration(hintText: 'Ej. spam, grosería, tema sensible...'),
                ),
                const SizedBox(height: 12),
                GradientButton(
                  onPressed: _addWord,
                  label: 'Guardar palabra',
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (_loading)
            const LoadingStateCard(label: 'Cargando palabras...')
          else if (_words.isEmpty)
            const EmptyStateCard(
              title: 'Aún no tienes palabras ocultas',
              body: 'Agrega una palabra para empezar a ocultar contenido en el chat y en el buzón anónimo.',
            )
          else
            GlassCard(
              child: Wrap(
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
            ),
        ],
      ),
    );
  }
}
