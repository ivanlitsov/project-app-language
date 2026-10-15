import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/initial_words.dart';
import '../models/learning_progress.dart';
import '../models/word.dart';

class ProgressStore extends ChangeNotifier {
  static const _key = 'vocabulary_v2';
  SharedPreferences? _preferences;
  List<Word> _customWords = [];
  Map<String, WordProgress> _progress = {};
  LearningSettings _settings = const LearningSettings();

  bool _saving = false;
  int _feedRevision = 0;
  String? _introductionId;

  bool get saving => _saving;
  int get feedRevision => _feedRevision;
  String? get introductionId => _introductionId;

  List<Word> get words => [...initialWords, ..._customWords];
  int get customCount => _customWords.length;
  LearningSettings get settings => _settings;
  WordProgress progressFor(String id) => _progress[id] ?? const WordProgress();
  int get answerCount =>
      _progress.values.fold(0, (sum, value) => sum + value.attempts);
  int get masteredCount =>
      words.where((word) => progressFor(word.id).level == 5).length;

  Future<void> load() async {
    _preferences = await SharedPreferences.getInstance();
    final raw = _preferences!.getString(_key);
    _customWords = [];
    _progress = {};
    _settings = const LearningSettings();
    if (raw != null) {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final custom = (data['words'] as List)
          .map((value) => Word.fromJson(value as Map<String, dynamic>))
          .toList();
      final results = (data['progress'] as Map<String, dynamic>).map(
        (id, value) =>
            MapEntry(id, WordProgress.fromJson(value as Map<String, dynamic>)),
      );
      final settings = LearningSettings.fromJson(
        data['settings'] as Map<String, dynamic>,
      );
      _customWords = custom;
      _progress = results;
      _settings = settings;
    }
    notifyListeners();
  }

  Future<void> recordAnswer(String wordId, bool correct) async {
    if (!words.any((word) => word.id == wordId)) {
      throw ArgumentError('Слово удалено');
    }
    await _commit(
      progress: {
        ..._progress,
        wordId: progressFor(wordId).afterAnswer(correct),
      },
    );
  }

  Future<void> saveWord({
    String? id,
    required String english,
    required String translation,
    String example = '',
    String exampleTranslation = '',
  }) async {
    final term = english.trim().replaceAll(RegExp(r'\s+'), ' ');
    final meaning = translation.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (term.isEmpty || meaning.isEmpty) {
      throw ArgumentError('Укажите слово и перевод');
    }
    if (exampleTranslation.trim().isNotEmpty && example.trim().isEmpty) {
      throw ArgumentError('Сначала добавьте пример на английском');
    }
    if (term.length > 64 ||
        meaning.length > 120 ||
        example.trim().length > 240 ||
        exampleTranslation.trim().length > 240) {
      throw ArgumentError('Слишком длинный текст');
    }
    if (words.any(
      (word) =>
          word.id != id && word.english.toLowerCase() == term.toLowerCase(),
    )) {
      throw ArgumentError('Такое слово уже есть в словаре');
    }
    if (id != null && !_customWords.any((word) => word.id == id)) {
      throw ArgumentError('Можно изменять только свои слова');
    }
    final word = Word(
      term,
      meaning,
      example.trim(),
      exampleTranslation.trim(),
      customId: id ?? 'custom:${DateTime.now().microsecondsSinceEpoch}',
    );
    final custom = List<Word>.of(_customWords);
    final results = Map<String, WordProgress>.of(_progress);
    if (id == null) {
      custom.add(word);
    } else {
      final index = custom.indexWhere((word) => word.id == id);
      final old = custom[index];
      if (old.english != term || old.translation != meaning) results.remove(id);
      custom[index] = word;
    }
    await _commit(
      customWords: custom,
      progress: results,
      refreshFeed: true,
      introduce: id == null ? word.id : null,
    );
  }

  Future<void> deleteWord(String id) async {
    if (!_customWords.any((word) => word.id == id)) {
      throw ArgumentError('Можно удалять только свои слова');
    }
    final results = Map<String, WordProgress>.of(_progress)..remove(id);
    await _commit(
      customWords: _customWords.where((word) => word.id != id).toList(),
      progress: results,
      refreshFeed: true,
    );
  }

  Future<void> updateSettings(LearningSettings settings) => _commit(
    settings: settings,
    refreshFeed:
        settings.showTheory != _settings.showTheory ||
        settings.direction != _settings.direction,
  );
  Future<void> resetProgress() => _commit(progress: {}, refreshFeed: true);

  // Состояние меняется только после успешной записи на устройство.
  Future<void> _commit({
    List<Word>? customWords,
    Map<String, WordProgress>? progress,
    LearningSettings? settings,
    bool refreshFeed = false,
    String? introduce,
  }) async {
    if (saving) throw StateError('Дождитесь сохранения');
    final nextWords = customWords ?? _customWords;
    final nextProgress = progress ?? _progress;
    final nextSettings = settings ?? _settings;
    _saving = true;
    notifyListeners();
    try {
      final saved = await _preferences!.setString(
        _key,
        jsonEncode({
          'words': nextWords.map((word) => word.toJson()).toList(),
          'progress': nextProgress.map(
            (id, value) => MapEntry(id, value.toJson()),
          ),
          'settings': nextSettings.toJson(),
        }),
      );
      if (!saved) throw StateError('Не удалось сохранить данные');
      _customWords = nextWords;
      _progress = nextProgress;
      _settings = nextSettings;
      if (refreshFeed) {
        _feedRevision++;
        _introductionId = introduce;
      }
    } finally {
      _saving = false;
      notifyListeners();
    }
  }
}
