import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:language_notes/main.dart';
import 'package:language_notes/models/feed_entry.dart';
import 'package:language_notes/models/learning_progress.dart';
import 'package:language_notes/screens/feed_screen.dart';
import 'package:language_notes/screens/word_editor_screen.dart';
import 'package:language_notes/services/progress_store.dart';
import 'package:language_notes/data/initial_words.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('Начальный словарь содержит 48 разных слов с примерами', () {
    expect(initialWords.length, 48);
    expect(initialWords.map((word) => word.id).toSet().length, 48);
    expect(
      initialWords.every(
        (word) =>
            word.translation.isNotEmpty &&
            word.example.isNotEmpty &&
            word.exampleTranslation.isNotEmpty,
      ),
      isTrue,
    );
  });

  test('Старые настройки без темы загружаются с системной темой', () async {
    SharedPreferences.setMockInitialValues({
      'vocabulary_v2':
          '{"words":[],"progress":{},"settings":{"showTheory":false,"direction":"englishToRussian"}}',
    });
    final store = ProgressStore();
    await store.load();
    expect(store.settings.theme, AppTheme.system);
    await store.updateSettings(store.settings.copyWith(theme: AppTheme.dark));
    final reloaded = ProgressStore();
    await reloaded.load();
    expect(reloaded.settings.theme, AppTheme.dark);
    expect(reloaded.settings.showTheory, isFalse);
    expect(reloaded.settings.direction, TranslationDirection.englishToRussian);
  });

  testWidgets('Смена темы через настройки сохраняет текущую карточку', (
    tester,
  ) async {
    final store = ProgressStore();
    await tester.pumpWidget(LanguageApp(store: store));
    await tester.pumpAndSettle();
    final feed = tester.state(find.byType(FeedScreen));
    final revision = store.feedRevision;
    await tester.tap(find.text('Настройки').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButton<AppTheme>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Тёмная').last);
    await tester.pumpAndSettle();
    expect(store.settings.theme, AppTheme.dark);
    expect(
      Theme.of(tester.element(find.byType(Scaffold))).brightness,
      Brightness.dark,
    );
    expect(store.feedRevision, revision);
    await tester.tap(find.text('Лента').last);
    await tester.pumpAndSettle();
    expect(tester.state(find.byType(FeedScreen)), same(feed));
    expect(store.answerCount, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Системная тема реагирует на настройки устройства', (
    tester,
  ) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    final store = ProgressStore();
    await tester.pumpWidget(LanguageApp(store: store));
    await tester.pumpAndSettle();
    expect(
      Theme.of(tester.element(find.byType(Scaffold))).brightness,
      Brightness.dark,
    );
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
    await tester.pumpAndSettle();
    expect(
      Theme.of(tester.element(find.byType(Scaffold))).brightness,
      Brightness.light,
    );
    expect(tester.takeException(), isNull);
  });

  test(
    'Освоение ограничено 0–5, ошибка уменьшает его, ответы сохраняются',
    () async {
      final store = ProgressStore();
      await store.load();
      final id = store.words.first.id;
      await store.recordAnswer(id, false);
      expect(store.progressFor(id).level, 0);
      for (var i = 0; i < 7; i++) {
        await store.recordAnswer(id, true);
      }
      expect(store.progressFor(id).level, 5);
      await store.recordAnswer(id, false);
      final reloaded = ProgressStore();
      await reloaded.load();
      expect(reloaded.progressFor(id).level, 4);
      expect(reloaded.progressFor(id).correct, 7);
      expect(reloaded.progressFor(id).incorrect, 2);
      expect(reloaded.answerCount, 9);
    },
  );

  test(
    'Свои слова, настройки и освоение восстанавливаются; сброс сохраняет словарь',
    () async {
      final store = ProgressStore();
      await store.load();
      await store.saveWord(
        english: '  evening ',
        translation: ' вечер ',
        example: 'Good evening.',
        exampleTranslation: 'Добрый вечер.',
      );
      final word = store.words.last;
      expect(word.english, 'evening');
      expect(store.introductionId, word.id);
      await store.recordAnswer(word.id, true);
      await store.updateSettings(
        const LearningSettings(
          showTheory: false,
          direction: TranslationDirection.russianToEnglish,
        ),
      );
      final loaded = ProgressStore();
      await loaded.load();
      expect(loaded.words.last.example, 'Good evening.');
      expect(loaded.customCount, 1);
      expect(loaded.progressFor(word.id).level, 1);
      expect(loaded.settings.showTheory, isFalse);
      expect(loaded.settings.direction, TranslationDirection.russianToEnglish);
      await loaded.resetProgress();
      final reset = ProgressStore();
      await reset.load();
      expect(reset.answerCount, 0);
      expect(reset.customCount, 1);
      expect(reset.settings.showTheory, isFalse);
    },
  );

  test(
    'Дубликаты отклоняются, изменение перевода сбрасывает освоение, удаление убирает слово',
    () async {
      final store = ProgressStore();
      await store.load();
      await expectLater(
        store.saveWord(english: ' HELLO ', translation: 'здравствуйте'),
        throwsArgumentError,
      );
      await store.saveWord(english: 'evening', translation: 'вечер');
      final id = store.words.last.id;
      await store.recordAnswer(id, true);
      await store.saveWord(
        id: id,
        english: 'evening',
        translation: 'вечер',
        example: 'Good evening.',
      );
      expect(store.progressFor(id).level, 1);
      await store.saveWord(
        id: id,
        english: 'evening',
        translation: 'вечернее время',
      );
      expect(store.progressFor(id).level, 0);
      await store.recordAnswer(id, true);
      await store.deleteWord(id);
      final loaded = ProgressStore();
      await loaded.load();
      expect(loaded.customCount, 0);
      expect(loaded.answerCount, 0);
      await expectLater(
        loaded.deleteWord(loaded.words.first.id),
        throwsArgumentError,
      );
    },
  );

  test(
    'Лента не заканчивается, перемешивает все слова и не повторяет соседние',
    () async {
      final store = ProgressStore();
      await store.load();
      await store.saveWord(english: 'evening', translation: 'вечер');
      final generator = FeedGenerator(
        words: store.words,
        settings: store.settings,
        random: Random(15),
        introductionId: store.introductionId,
      );
      final first = generator.next();
      expect(first.word.english, 'evening');
      expect(first.isTheory, isTrue);
      var previous = first.word.id;
      final appeared = {previous};
      var theoryCount = 1;
      var practiceCount = 0;
      final directions = <bool>{};
      for (var i = 0; i < 1000; i++) {
        final entry = generator.next();
        expect(entry.word.id, isNot(previous));
        previous = entry.word.id;
        appeared.add(previous);
        if (entry.isTheory) {
          theoryCount++;
        } else {
          practiceCount++;
          directions.add(entry.reverse);
          expect(entry.options.toSet().length, 4);
          expect(
            entry.options.where((option) => option == entry.answer).length,
            1,
          );
        }
      }
      expect(appeared.length, store.words.length);
      expect(theoryCount, greaterThan(0));
      expect(practiceCount, greaterThan(0));
      expect(directions, {false, true});
      expect(store.answerCount, 0);
    },
  );

  test('Настройки отключают теорию и задают направление практики', () async {
    final store = ProgressStore();
    await store.load();
    for (final direction in [
      TranslationDirection.englishToRussian,
      TranslationDirection.russianToEnglish,
    ]) {
      final generator = FeedGenerator(
        words: store.words,
        settings: LearningSettings(showTheory: false, direction: direction),
        random: Random(2),
      );
      for (var i = 0; i < 50; i++) {
        final entry = generator.next();
        expect(entry.isTheory, isFalse);
        expect(
          entry.reverse,
          direction == TranslationDirection.russianToEnglish,
        );
      }
    }
  });

  for (final mark in ['Знаю', 'Не знаю']) {
    testWidgets(
      'Теория: $mark открывает следующую карточку без изменения освоения',
      (tester) async {
        final store = ProgressStore();
        await store.load();
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(body: FeedScreen(store: store)),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(Card), findsOneWidget);
        final firstWord = store.words.firstWhere(
          (word) => find.text(word.english).evaluate().isNotEmpty,
        );
        await tester.drag(
          find.byType(SingleChildScrollView),
          const Offset(0, -600),
        );
        await tester.pumpAndSettle();
        expect(find.text(firstWord.english), findsOneWidget);
        expect(store.answerCount, 0);
        await tester.ensureVisible(find.text(mark));
        await tester.tap(find.text(mark));
        await tester.pumpAndSettle();
        expect(find.byType(Card), findsOneWidget);
        expect(find.text(firstWord.english), findsNothing);
        expect(store.answerCount, 0);
        expect(store.progressFor(firstWord.id).level, 0);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('Ответ сохраняется один раз и открывает следующую карточку', (
    tester,
  ) async {
    final store = ProgressStore();
    await store.load();
    await store.updateSettings(
      const LearningSettings(
        showTheory: false,
        direction: TranslationDirection.englishToRussian,
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: FeedScreen(store: store)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(Card), findsOneWidget);
    final word = store.words.firstWhere(
      (word) => find.text(word.english).evaluate().isNotEmpty,
    );
    final answer = find.text(word.translation);
    await tester.ensureVisible(answer);
    await tester.tap(answer);
    await tester.tap(answer);
    await tester.pumpAndSettle();
    expect(store.answerCount, 1);
    expect(store.progressFor(word.id).level, 1);
    expect(find.byType(Card), findsOneWidget);
    expect(
      find.descendant(of: find.byType(Card), matching: find.text(word.english)),
      findsNothing,
    );
    expect(find.textContaining('Верно.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('Добавленное слово видно в словаре и первым появляется в ленте', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = ProgressStore();
    await tester.pumpWidget(LanguageApp(store: store));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Словарь'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Добавить слово'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), 'evening');
    await tester.enterText(find.byType(TextFormField).at(1), 'вечер');
    await tester.ensureVisible(find.text('Сохранить'));
    await tester.tap(find.text('Сохранить'));
    await tester.pumpAndSettle();
    expect(find.byType(WordEditorScreen), findsNothing);
    expect(store.customCount, 1);
    await tester.tap(find.text('Только мои'));
    await tester.pumpAndSettle();
    expect(find.text('evening'), findsOneWidget);
    await tester.tap(find.text('Лента').last);
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byType(Card).first,
        matching: find.text('evening'),
      ),
      findsOneWidget,
    );
    expect(store.answerCount, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Три вкладки помещаются на экране 320×640', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = ProgressStore();
    await tester.pumpWidget(LanguageApp(store: store));
    await tester.pumpAndSettle();
    for (final title in ['Словарь', 'Настройки', 'Лента']) {
      await tester.tap(find.text(title).last);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
  });
}
