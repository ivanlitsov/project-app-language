import 'package:flutter/material.dart';
import '../services/progress_store.dart';
import 'dictionary_screen.dart';
import 'feed_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.store});
  final ProgressStore store;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = 0;
  bool _loading = true;
  bool _loadError = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = false;
    });
    try {
      await widget.store.load();
    } catch (_) {
      _loadError = true;
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(['Лента', 'Словарь', 'Настройки'][_tab])),
    body: SafeArea(
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : _loadError
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Не удалось загрузить данные',
                      textAlign: TextAlign.center,
                    ),
                    TextButton(
                      onPressed: _load,
                      child: const Text('Повторить'),
                    ),
                  ],
                ),
              ),
            )
          : IndexedStack(
              index: _tab,
              children: [
                FeedScreen(
                  key: ValueKey(widget.store.feedRevision),
                  store: widget.store,
                ),
                DictionaryScreen(store: widget.store),
                SettingsScreen(store: widget.store),
              ],
            ),
    ),
    bottomNavigationBar: NavigationBar(
      selectedIndex: _tab,
      onDestinationSelected: (value) => setState(() => _tab = value),
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.view_stream_outlined),
          selectedIcon: Icon(Icons.view_stream),
          label: 'Лента',
        ),
        NavigationDestination(
          icon: Icon(Icons.menu_book_outlined),
          selectedIcon: Icon(Icons.menu_book),
          label: 'Словарь',
        ),
        NavigationDestination(
          icon: Icon(Icons.settings_outlined),
          selectedIcon: Icon(Icons.settings),
          label: 'Настройки',
        ),
      ],
    ),
  );
}
