import 'dart:math';
import 'learning_progress.dart';
import 'word.dart';

class FeedEntry {
  FeedEntry({
    required this.word,
    required this.isTheory,
    this.reverse = false,
    this.options = const [],
  });

  final Word word;
  final bool isTheory;
  final bool reverse;
  final List<String> options;
  String get prompt => reverse ? word.translation : word.english;
  String get answer => reverse ? word.english : word.translation;
}

class FeedGenerator {
  FeedGenerator({
    required this.words,
    required this.settings,
    Random? random,
    this.introductionId,
  }) : _random = random ?? Random();

  final List<Word> words;
  final LearningSettings settings;
  final Random _random;
  final String? introductionId;
  String? _previousId;
  bool _first = true;

  FeedEntry next() {
    final candidates = words.where((word) => word.id != _previousId).toList();
    final pool = candidates.isEmpty ? words : candidates;
    var word = pool[_random.nextInt(pool.length)];
    if (_first && introductionId != null) {
      word = words.firstWhere(
        (word) => word.id == introductionId,
        orElse: () => word,
      );
    }
    final isTheory = settings.showTheory && (_first || _random.nextInt(3) == 0);
    _first = false;
    _previousId = word.id;
    if (isTheory) return FeedEntry(word: word, isTheory: true);

    final reverse = switch (settings.direction) {
      TranslationDirection.englishToRussian => false,
      TranslationDirection.russianToEnglish => true,
      TranslationDirection.mixed => _random.nextBool(),
    };
    final answer = reverse ? word.english : word.translation;
    final seen = {answer.toLowerCase()};
    final wrong = <String>[];
    for (final other in words) {
      final option = reverse ? other.english : other.translation;
      if (seen.add(option.toLowerCase())) wrong.add(option);
    }
    wrong.shuffle(_random);
    final options = [answer, ...wrong.take(3)]..shuffle(_random);
    return FeedEntry(
      word: word,
      isTheory: false,
      reverse: reverse,
      options: options,
    );
  }
}
