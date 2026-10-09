import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/azkar_model.dart';
import '../services/adhkar_service.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/language_switcher.dart';

class ZikrDetailScreen extends StatefulWidget {
  final ZikrCategory category;
  const ZikrDetailScreen({super.key, required this.category});

  @override
  State<ZikrDetailScreen> createState() => _ZikrDetailScreenState();
}

class _ZikrDetailScreenState extends State<ZikrDetailScreen> {
  // Keyed by the item's POSITION in the list — the bundled dataset reuses
  // the same numeric id across categories (id 1 appears 130+ times), so
  // id-keyed counters all moved together when one was tapped.
  final Map<int, int> _counts = {};
  bool _showEnglishTranslation = true;

  ZikrCategory get _category {
    // Prefer the merged (translated) category from the service; the widget
    // argument is the fallback captured at navigation time.
    final service = context.watch<AdhkarService>();
    return service.byId(widget.category.id) ?? widget.category;
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    // Adhkar only offers Arabic + English — snap the shared content language.
    final contentLang = adhkarLangFor(state.contentLang);
    final category = _category;

    return Scaffold(
      appBar: AppBar(
        title: Text(category.nameFor(contentLang),
            style: TextStyle(fontFamily: contentLang == 'ar' ? 'serif' : null)),
        actions: [
          // English-only translation toggle — other languages are not
          // offered here by design.
          IconButton(
            onPressed: () => setState(
                () => _showEnglishTranslation = !_showEnglishTranslation),
            icon: Icon(_showEnglishTranslation
                ? Icons.translate_rounded
                : Icons.translate_outlined),
            tooltip: state.t('English translation', 'انگریزی ترجمہ'),
          ),
        ],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: category.items.length,
        itemBuilder: (ctx, i) {
          final item = category.items[i];
          final done = _counts[i] ?? 0;
          final complete = done >= item.count;
          final translation = _showEnglishTranslation && item.hasTranslation('en')
              ? item.textFor('en')
              : null;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: GlassCard(
              padding: const EdgeInsets.all(16),
              border: complete ? Border.all(color: AppColors.primary, width: 1.5) : null,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.text,
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: 16.5,
                      height: 1.8,
                      fontFamily: 'serif',
                      color: Theme.of(context).brightness == Brightness.dark
                          ? AppColors.darkText
                          : const Color(0xFF12352B),
                    ),
                  ),
                  if (translation != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      translation,
                      textAlign: TextAlign.left,
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.7,
                        color: Theme.of(context).textTheme.bodySmall?.color,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      InkWell(
                        onTap: () => setState(() {
                          _counts[i] = done >= item.count ? 0 : done + 1;
                        }),
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            complete
                                ? state.t('Completed ✓', 'مکمل ✓')
                                : '$done / ${item.count}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        state.t('Tap to count', 'گننے کے لیے تھپتھپائیں'),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
