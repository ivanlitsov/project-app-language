import 'package:flutter/material.dart';
import '../models/word.dart';
import '../services/progress_store.dart';
import 'word_editor_screen.dart';

class DictionaryScreen extends StatefulWidget {
  const DictionaryScreen({super.key, required this.store});
  final ProgressStore store;

  @override
  State<DictionaryScreen> createState() => _DictionaryScreenState();
}

class _DictionaryScreenState extends State<DictionaryScreen> {
  String _query = '';
  bool _customOnly = false;

  Future<void> _delete(Word word) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить слово?'),
        content: Text(
          '«${word.english}» и его уровень освоения будут удалены.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await widget.store.deleteWord(word.id);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не удалось удалить слово')),
        );
      }
    }
  }

  void _edit([Word? word]) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => WordEditorScreen(store: widget.store, word: word),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final words =
        widget.store.words
            .where(
              (word) =>
                  (!_customOnly || word.isCustom) &&
                  (word.english.toLowerCase().contains(_query) ||
                      word.translation.toLowerCase().contains(_query)),
            )
            .toList()
          ..sort(
            (a, b) =>
                a.english.toLowerCase().compareTo(b.english.toLowerCase()),
          );
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: widget.store.saving ? null : () => _edit(),
              icon: const Icon(Icons.add),
              label: const Text('Добавить слово'),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            onChanged: (value) =>
                setState(() => _query = value.trim().toLowerCase()),
            decoration: const InputDecoration(
              labelText: 'Поиск слова или перевода',
              prefixIcon: Icon(Icons.search),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: SizedBox(
            width: double.infinity,
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 8,
              children: [
                FilterChip(
                  selected: _customOnly,
                  onSelected: (value) => setState(() => _customOnly = value),
                  label: const Text('Только мои'),
                ),
                Text('Найдено: ${words.length}'),
              ],
            ),
          ),
        ),
        Expanded(
          child: words.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      _query.isNotEmpty
                          ? 'По этому запросу слов нет.'
                          : 'Своих слов пока нет.\nДобавьте слово кнопкой выше.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  itemCount: words.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final word = words[index];
                    final progress = widget.store.progressFor(word.id);
                    return Card(
                      child: ExpansionTile(
                        key: ValueKey(word.id),
                        title: Text(word.english),
                        subtitle: Text(
                          '${word.translation}\nОсвоение: ${progress.level}/5${word.isCustom ? ' · Моё слово' : ''}',
                        ),
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                LinearProgressIndicator(
                                  value: progress.level / 5,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'Верных ответов: ${progress.correct} · Ошибок: ${progress.incorrect}',
                                ),
                                if (word.example.isNotEmpty) ...[
                                  const SizedBox(height: 16),
                                  Text(word.example),
                                  if (word.exampleTranslation.isNotEmpty) ...[
                                    const SizedBox(height: 6),
                                    Text(word.exampleTranslation),
                                  ],
                                ],
                                if (word.isCustom) ...[
                                  const SizedBox(height: 12),
                                  Wrap(
                                    spacing: 12,
                                    children: [
                                      TextButton(
                                        onPressed: widget.store.saving
                                            ? null
                                            : () => _edit(word),
                                        child: const Text('Изменить'),
                                      ),
                                      TextButton(
                                        onPressed: widget.store.saving
                                            ? null
                                            : () => _delete(word),
                                        child: const Text('Удалить'),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
