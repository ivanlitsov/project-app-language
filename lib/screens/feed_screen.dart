import 'package:flutter/material.dart';
import '../models/feed_entry.dart';
import '../services/progress_store.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key, required this.store});
  final ProgressStore store;

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  late final FeedGenerator _generator;
  late FeedEntry _entry;
  final _scrollController = ScrollController();
  bool _answering = false;

  @override
  void initState() {
    super.initState();
    _generator = FeedGenerator(
      words: widget.store.words,
      settings: widget.store.settings,
      introductionId: widget.store.introductionId,
    );
    _entry = _generator.next();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _next(FeedEntry entry) {
    if (!identical(entry, _entry)) return;
    setState(() => _entry = _generator.next());
    if (_scrollController.hasClients) _scrollController.jumpTo(0);
  }

  Future<void> _answer(FeedEntry entry, String option) async {
    if (_answering || widget.store.saving || !identical(entry, _entry)) return;
    setState(() => _answering = true);
    try {
      final correct = option == entry.answer;
      await widget.store.recordAnswer(entry.word.id, correct);
      if (mounted) {
        final level = widget.store.progressFor(entry.word.id).level;
        final messenger = ScaffoldMessenger.of(context);
        messenger.hideCurrentSnackBar();
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              '${correct ? 'Верно' : 'Неверно'}. ${entry.word.english} — ${entry.word.translation}. Освоение: $level/5',
            ),
          ),
        );
        _next(entry);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ответ не сохранён. Попробуйте ещё раз.'),
          ),
        );
      }
    }
    if (mounted) setState(() => _answering = false);
  }

  @override
  Widget build(BuildContext context) {
    final entry = _entry;
    final busy = _answering || widget.store.saving;
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: (constraints.maxHeight - 16).clamp(0, double.infinity),
          ),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Icon(
                            entry.isTheory
                                ? Icons.menu_book_outlined
                                : Icons.edit_outlined,
                            size: 18,
                          ),
                          Text(
                            entry.isTheory ? 'Знакомство' : 'Повторение',
                            style: Theme.of(context).textTheme.labelLarge,
                          ),
                          if (entry.word.isCustom) const Text('· Моё слово'),
                        ],
                      ),
                      const SizedBox(height: 24),
                      if (entry.isTheory) ...[
                        Text(
                          entry.word.english,
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          entry.word.translation,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        if (entry.word.example.isNotEmpty) ...[
                          const SizedBox(height: 20),
                          Text(entry.word.example),
                          if (entry.word.exampleTranslation.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(entry.word.exampleTranslation),
                          ],
                        ],
                      ] else ...[
                        Text(
                          entry.reverse
                              ? 'Выберите слово на английском'
                              : 'Выберите перевод на русский',
                        ),
                        const SizedBox(height: 12),
                        Text(
                          entry.prompt,
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                      ],
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: entry.isTheory
                          ? [
                              Text(
                                'Теория не влияет на освоение',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              const SizedBox(height: 16),
                              OutlinedButton(
                                onPressed: busy ? null : () => _next(entry),
                                child: const Text('Не знаю'),
                              ),
                              const SizedBox(height: 8),
                              FilledButton(
                                onPressed: busy ? null : () => _next(entry),
                                child: const Text('Знаю'),
                              ),
                            ]
                          : [
                              for (final option in entry.options) ...[
                                OutlinedButton(
                                  onPressed: busy
                                      ? null
                                      : () => _answer(entry, option),
                                  style: OutlinedButton.styleFrom(
                                    alignment: Alignment.centerLeft,
                                    padding: const EdgeInsets.all(16),
                                  ),
                                  child: Text(option),
                                ),
                                const SizedBox(height: 10),
                              ],
                              if (_answering) const Text('Сохранение…'),
                            ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
