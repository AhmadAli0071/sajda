import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// The content translation languages supported by Ayat of the Day & Adhkar.
const List<(String, String)> kContentLanguages = [
  ('ar', 'عربی'),
  ('ur', 'اردو'),
  ('en', 'English'),
  ('hi', 'हिन्दी'),
  ('id', 'Indonesia'),
];

/// Adhkar (Hisnul Muslim) offers only Arabic + English in its menu — the
/// bundled dataset is Arabic and just English is offered as the translation,
/// so ur/hi/id are deliberately excluded even though Ayat of the Day ships
/// all five.
const List<(String, String)> kAdhkarLanguages = [
  ('ar', 'عربی'),
  ('en', 'English'),
];

/// Snaps a global content language down to one Adhkar actually offers so the
/// menu never shows an unselectable value (e.g. global 'hi' → 'en').
String adhkarLangFor(String code) => code == 'ar' ? 'ar' : 'en';

/// Compact filter-chip row for picking the content translation language.
/// Renders top-corner inside the Ayat of the Day card.
class ContentLanguageChips extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;
  const ContentLanguageChips({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Directionality(
      textDirection: TextDirection.ltr,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final (code, label) in kContentLanguages) ...[
              _chip(context, code, label, dark),
              const SizedBox(width: 6),
            ],
          ],
        ),
      ),
    );
  }

  Widget _chip(BuildContext context, String code, String label, bool dark) {
    final isSelected = code == selected;
    return InkWell(
      onTap: () => onChanged(code),
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
        decoration: BoxDecoration(
          gradient: isSelected
              ? const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.primary, AppColors.primaryDeep],
                )
              : null,
          color: isSelected ? null : (dark ? Colors.white.withValues(alpha: 0.07) : Colors.black.withValues(alpha: 0.05)),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            height: 1.3,
            fontWeight: FontWeight.w700,
            color: isSelected
                ? Colors.white
                : (dark ? AppColors.darkText : const Color(0xFF12352B)),
          ),
        ),
      ),
    );
  }
}

/// Dropdown menu for AppBars (Adhkar screens).
class ContentLanguageMenu extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;

  /// Languages to offer — defaults to the full Ayat-of-the-Day set; pass
  /// [kAdhkarLanguages] on Adhkar screens to restrict to Arabic + English.
  final List<(String, String)> languages;
  const ContentLanguageMenu({
    super.key,
    required this.selected,
    required this.onChanged,
    this.languages = kContentLanguages,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      onSelected: onChanged,
      tooltip: 'Language',
      icon: const Icon(Icons.translate_rounded),
      itemBuilder: (ctx) => [
        for (final (code, label) in languages)
          PopupMenuItem<String>(
            value: code,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontWeight: code == selected ? FontWeight.w800 : FontWeight.w500,
                      color: code == selected ? AppColors.primary : null,
                    ),
                  ),
                ),
                if (code == selected)
                  const Icon(Icons.check_rounded, size: 18, color: AppColors.primary),
              ],
            ),
          ),
      ],
    );
  }
}
