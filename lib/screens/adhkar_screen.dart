import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/adhkar_service.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/language_switcher.dart';
import 'zikr_detail_screen.dart';

class AdhkarScreen extends StatelessWidget {
  const AdhkarScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final adhkar = context.watch<AdhkarService>();
    final categories = adhkar.categories;
    // Adhkar only offers Arabic + English — snap the shared content language
    // so the menu never shows an unselectable value (e.g. global 'hi').
    final contentLang = adhkarLangFor(state.contentLang);
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        title: Text(state.t('Adhkar (Hisnul Muslim)', 'اذکار (حصون مسلم)')),
        actions: [
          ContentLanguageMenu(
            selected: contentLang,
            languages: kAdhkarLanguages,
            onChanged: (code) => context.read<AppState>().setContentLanguage(code),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: categories.length,
        itemBuilder: (ctx, i) {
          final c = categories[i];
          final name = c.nameFor(contentLang);
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: GlassCard(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => ZikrDetailScreen(category: c)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [AppColors.primary, AppColors.primaryDeep],
                      ),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: const Icon(Icons.volunteer_activism_outlined, color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          textAlign: contentLang == 'ar' || contentLang == 'ur'
                              ? TextAlign.right
                              : TextAlign.left,
                          style: TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w700,
                            fontFamily: contentLang == 'ar' ? 'serif' : null,
                            color: dark ? AppColors.darkText : const Color(0xFF12352B),
                          ),
                        ),
                        if (contentLang != 'ar' && c.hasTranslation(contentLang)) ...[
                          const SizedBox(height: 3),
                          Text(
                            c.category,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  fontFamily: 'serif',
                                ),
                          ),
                        ],
                        const SizedBox(height: 3),
                        Text(
                          state.t(
                            '${c.items.length} remembrances',
                            '${c.items.length} اذکار',
                          ),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
