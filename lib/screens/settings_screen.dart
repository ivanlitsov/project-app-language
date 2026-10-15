import 'package:flutter/material.dart';
import '../models/learning_progress.dart';
import '../services/progress_store.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.store});
  final ProgressStore store;

  Widget _selector<T>({
    required String label,
    required T value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?>? onChanged,
  }) => Padding(
    padding: const EdgeInsets.all(16),
    child: InputDecorator(
      decoration: InputDecoration(labelText: label),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          isDense: true,
          items: items,
          onChanged: onChanged,
        ),
      ),
    ),
  );

  Future<void> _change(BuildContext context, LearningSettings settings) async {
    try {
      await store.updateSettings(settings);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не удалось сохранить настройки')),
        );
      }
    }
  }

  Future<void> _reset(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Сбросить освоение?'),
        content: const Text(
          'Уровни всех слов и счётчики ответов станут нулевыми. Свои слова и настройки сохранятся.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Сбросить'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await store.resetProgress();
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не удалось сбросить освоение')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      Card(
        child: Column(
          children: [
            _selector<AppTheme>(
              label: 'Тема',
              value: store.settings.theme,
              items: const [
                DropdownMenuItem(
                  value: AppTheme.system,
                  child: Text('Как на устройстве'),
                ),
                DropdownMenuItem(value: AppTheme.light, child: Text('Светлая')),
                DropdownMenuItem(value: AppTheme.dark, child: Text('Тёмная')),
              ],
              onChanged: store.saving
                  ? null
                  : (value) {
                      if (value != null) {
                        _change(context, store.settings.copyWith(theme: value));
                      }
                    },
            ),
            SwitchListTile(
              title: const Text('Карточки с теорией'),
              subtitle: const Text(
                'Знакомство со словом и примером. Не меняет освоение.',
              ),
              value: store.settings.showTheory,
              onChanged: store.saving
                  ? null
                  : (value) => _change(
                      context,
                      store.settings.copyWith(showTheory: value),
                    ),
            ),
            _selector<TranslationDirection>(
              label: 'Направление перевода',
              value: store.settings.direction,
              items: const [
                DropdownMenuItem(
                  value: TranslationDirection.mixed,
                  child: Text('В обе стороны'),
                ),
                DropdownMenuItem(
                  value: TranslationDirection.englishToRussian,
                  child: Text('Английский → русский'),
                ),
                DropdownMenuItem(
                  value: TranslationDirection.russianToEnglish,
                  child: Text('Русский → английский'),
                ),
              ],
              onChanged: store.saving
                  ? null
                  : (value) {
                      if (value != null) {
                        _change(
                          context,
                          store.settings.copyWith(direction: value),
                        );
                      }
                    },
            ),
          ],
        ),
      ),
      const SizedBox(height: 24),
      Text('Освоение слов', style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 12),
      const Text(
        'У каждого слова уровень от 0 до 5. Верный ответ добавляет 1, ошибка убавляет 1. Отметки «Знаю» и «Не знаю» на карточке теории не меняют освоение.',
      ),
      const SizedBox(height: 12),
      const Text(
        'Слова выбираются случайно. Даже слово с уровнем 5 продолжает появляться для повторения. После изменения словаря или настроек занятий лента начинается заново.',
      ),
      const SizedBox(height: 24),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Всего слов: ${store.words.length}'),
              const SizedBox(height: 8),
              Text('Своих слов: ${store.customCount}'),
              const SizedBox(height: 8),
              Text('Освоено на 5/5: ${store.masteredCount}'),
              const SizedBox(height: 8),
              Text('Ответов в практике: ${store.answerCount}'),
            ],
          ),
        ),
      ),
      const SizedBox(height: 16),
      OutlinedButton(
        onPressed: store.saving ? null : () => _reset(context),
        child: const Text('Сбросить освоение'),
      ),
      const SizedBox(height: 16),
      const Text(
        'Слова, настройки и освоение хранятся на этом устройстве. Интернет для занятий не нужен.',
      ),
    ],
  );
}
