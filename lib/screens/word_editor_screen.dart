import 'package:flutter/material.dart';
import '../models/word.dart';
import '../services/progress_store.dart';

class WordEditorScreen extends StatefulWidget {
  const WordEditorScreen({super.key, required this.store, this.word});
  final ProgressStore store;
  final Word? word;

  @override
  State<WordEditorScreen> createState() => _WordEditorScreenState();
}

class _WordEditorScreenState extends State<WordEditorScreen> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _english;
  late final TextEditingController _translation;
  late final TextEditingController _example;
  late final TextEditingController _exampleTranslation;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _english = TextEditingController(text: widget.word?.english);
    _translation = TextEditingController(text: widget.word?.translation);
    _example = TextEditingController(text: widget.word?.example);
    _exampleTranslation = TextEditingController(
      text: widget.word?.exampleTranslation,
    );
  }

  @override
  void dispose() {
    for (final controller in [
      _english,
      _translation,
      _example,
      _exampleTranslation,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.store.saveWord(
        id: widget.word?.id,
        english: _english.text,
        translation: _translation.text,
        example: _example.text,
        exampleTranslation: _exampleTranslation.text,
      );
      if (mounted) Navigator.of(context).pop();
    } on ArgumentError catch (error) {
      if (mounted) setState(() => _error = error.message.toString());
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Не удалось сохранить слово. Попробуйте ещё раз.',
        );
      }
    }
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: Scaffold(
      appBar: AppBar(
        title: Text(widget.word == null ? 'Новое слово' : 'Изменить слово'),
      ),
      body: SafeArea(
        child: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              TextFormField(
                controller: _english,
                enabled: !_saving,
                maxLength: 64,
                textCapitalization: TextCapitalization.none,
                autocorrect: false,
                decoration: const InputDecoration(
                  labelText: 'Слово на английском',
                  counterText: '',
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Введите слово'
                    : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _translation,
                enabled: !_saving,
                maxLength: 120,
                decoration: const InputDecoration(
                  labelText: 'Перевод на русский',
                  counterText: '',
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Введите перевод'
                    : null,
              ),
              const SizedBox(height: 24),
              const Text('Пример можно не заполнять.'),
              const SizedBox(height: 16),
              TextFormField(
                controller: _example,
                enabled: !_saving,
                maxLength: 240,
                minLines: 1,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Пример на английском',
                  counterText: '',
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _exampleTranslation,
                enabled: !_saving,
                maxLength: 240,
                minLines: 1,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Перевод примера',
                  counterText: '',
                ),
                validator: (value) =>
                    value!.trim().isNotEmpty && _example.text.trim().isEmpty
                    ? 'Сначала добавьте пример на английском'
                    : null,
              ),
              if (widget.word != null) ...[
                const SizedBox(height: 20),
                const Text(
                  'При изменении слова или перевода его освоение сбросится.',
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 20),
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: Text(_saving ? 'Сохранение…' : 'Сохранить'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
