import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/quran_service.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import 'surah_screen.dart';

class QuranSearchScreen extends StatefulWidget {
  const QuranSearchScreen({super.key});

  @override
  State<QuranSearchScreen> createState() => _QuranSearchScreenState();
}

class _QuranSearchScreenState extends State<QuranSearchScreen> {
  final TextEditingController _controller = TextEditingController();
  List<SearchResult> _results = [];
  bool _searching = false;

  Future<void> _search(String query) async {
    setState(() => _searching = true);
    // searchAsync runs the 6,236-verse scan on a background isolate so
    // typing never freezes the UI on low-end devices.
    final results = await QuranService.instance
        .searchAsync(query)
        .catchError((_) => <SearchResult>[]);
    if (!mounted) return;
    setState(() {
      _results = results;
      _searching = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(title: Text(state.t('Search Quran', 'قرآن میں تلاش'))),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _controller,
              autofocus: true,
              onSubmitted: _search,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: state.t('Search a word or phrase...', 'کوئی لفظ یا جملہ تلاش کریں...'),
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _searching
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : IconButton(
                        icon: const Icon(Icons.search_rounded),
                        onPressed: () => _search(_controller.text),
                      ),
              ),
            ),
          ),
          if (_results.isEmpty && !_searching)
            Expanded(
              child: Center(
                child: Text(
                  state.t(
                    'Search in the translation of all 6236 verses',
                    'تمام 6236 آیات کے ترجمے میں تلاش کریں',
                  ),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            )
          else
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                itemCount: _results.length,
                itemBuilder: (ctx, i) {
                  final r = _results[i];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: GlassCard(
                      padding: const EdgeInsets.all(14),
                      onTap: () {
                        final surah =
                            QuranService.instance.surah(r.surah);
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => SurahScreen(
                              surah: surah,
                              initialVerse: r.ayah,
                            ),
                          ),
                        );
                      },
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${r.surah}:${r.ayah} • ${QuranService.instance.surahNameWithNumber(r.surah)}',
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            r.arabic,
                            textAlign: TextAlign.right,
                            style: const TextStyle(
                              fontSize: 17,
                              height: 1.7,
                              fontFamily: 'serif',
                              color: Color(0xFF12352B),
                            ),
                          ),
                          const SizedBox(height: 6),
                           Text(
                             r.translation(state.isUrdu ? 'ur' : 'en').isEmpty
                                 ? state.t('Translation temporarily unavailable', 'ترجمہ عارضی طور پر دستیاب نہیں ہے۔')
                                 : r.translation(state.isUrdu ? 'ur' : 'en'),
                             style: const TextStyle(fontSize: 13.5, height: 1.5),
                           ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}