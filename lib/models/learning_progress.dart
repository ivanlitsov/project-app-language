enum TranslationDirection { englishToRussian, russianToEnglish, mixed }

enum AppTheme { system, light, dark }

class LearningSettings {
  const LearningSettings({
    this.showTheory = true,
    this.direction = TranslationDirection.mixed,
    this.theme = AppTheme.system,
  });

  final bool showTheory;
  final TranslationDirection direction;
  final AppTheme theme;

  LearningSettings copyWith({
    bool? showTheory,
    TranslationDirection? direction,
    AppTheme? theme,
  }) => LearningSettings(
    showTheory: showTheory ?? this.showTheory,
    direction: direction ?? this.direction,
    theme: theme ?? this.theme,
  );

  Map<String, dynamic> toJson() => {
    'showTheory': showTheory,
    'direction': direction.name,
    'theme': theme.name,
  };

  factory LearningSettings.fromJson(Map<String, dynamic> json) =>
      LearningSettings(
        showTheory: json['showTheory'] as bool,
        direction: TranslationDirection.values.firstWhere(
          (direction) => direction.name == json['direction'],
          orElse: () => TranslationDirection.mixed,
        ),
        theme: AppTheme.values.firstWhere(
          (theme) => theme.name == json['theme'],
          orElse: () => AppTheme.system,
        ),
      );
}

class WordProgress {
  const WordProgress({this.level = 0, this.correct = 0, this.incorrect = 0});

  final int level;
  final int correct;
  final int incorrect;
  int get attempts => correct + incorrect;

  WordProgress afterAnswer(bool isCorrect) => WordProgress(
    level: (level + (isCorrect ? 1 : -1)).clamp(0, 5),
    correct: correct + (isCorrect ? 1 : 0),
    incorrect: incorrect + (isCorrect ? 0 : 1),
  );

  Map<String, int> toJson() => {
    'level': level,
    'correct': correct,
    'incorrect': incorrect,
  };

  factory WordProgress.fromJson(Map<String, dynamic> json) => WordProgress(
    level: (json['level'] as int).clamp(0, 5),
    correct: (json['correct'] as int).clamp(0, 1 << 30),
    incorrect: (json['incorrect'] as int).clamp(0, 1 << 30),
  );
}
