class Word {
  const Word(
    this.english,
    this.translation,
    this.example,
    this.exampleTranslation, {
    this.customId,
  });
  final String? customId;
  String get id => customId ?? 'base:$english';
  bool get isCustom => customId != null;
  final String english;
  final String translation;
  final String example;
  final String exampleTranslation;

  Map<String, dynamic> toJson() => {
    'id': customId,
    'english': english,
    'translation': translation,
    'example': example,
    'exampleTranslation': exampleTranslation,
  };

  factory Word.fromJson(Map<String, dynamic> json) => Word(
    json['english'] as String,
    json['translation'] as String,
    json['example'] as String,
    json['exampleTranslation'] as String,
    customId: json['id'] as String,
  );
}
