import 'package:flutter/material.dart';

/// A short du'a with its own public-domain English/Urdu rendering.
class DuaCardContent {
  final String titleEn;
  final String titleUr;
  final String arabic;
  final String transliteration;
  final String translationEn;
  final String translationUr;
  final String source;

  const DuaCardContent({
    required this.titleEn,
    required this.titleUr,
    required this.arabic,
    required this.transliteration,
    required this.translationEn,
    required this.translationUr,
    required this.source,
  });
}

/// Visual themes for shareable posters.
class CardThemeOption {
  final String nameEn;
  final String nameUr;
  final List<Color> colors;
  final Color foreground;
  final Color accent;

  const CardThemeOption({
    required this.nameEn,
    required this.nameUr,
    required this.colors,
    required this.foreground,
    required this.accent,
  });
}

/// Ten short, widely memorised adhkar/du'as.
const List<DuaCardContent> duaCardContents = [
  DuaCardContent(
    titleEn: 'Ease After Hardship',
    titleUr: 'مشکل کے بعد آسانی',
    arabic: 'فَإِنَّ مَعَ الْعُسْرِ يُسْرًا',
    transliteration: 'Fa-inna ma\'al-\'usri yusra',
    translationEn: 'Indeed, with hardship comes ease.',
    translationUr: 'بے شک مشکل کے ساتھ آسانی ہے۔',
    source: 'Quran 94:5',
  ),
  DuaCardContent(
    titleEn: 'Peace of the Heart',
    titleUr: 'دل کا سکون',
    arabic: 'أَلَا بِذِكْرِ اللَّهِ تَطْمَئِنُّ الْقُلُوبُ',
    transliteration: 'Ala bi-dhikrillahi tatma\'innul-qulub',
    translationEn: 'Surely in the remembrance of Allah do hearts find rest.',
    translationUr: 'یاد رکھو! اللہ کے ذکر سے ہی دلوں کو سکون ملتا ہے۔',
    source: 'Quran 13:28',
  ),
  DuaCardContent(
    titleEn: 'Trust in Allah',
    titleUr: 'اللہ پر بھروسہ',
    arabic: 'وَمَن يَتَوَكَّلْ عَلَى اللَّهِ فَهُوَ حَسْبُهُ',
    transliteration: 'Wa man yatawakkal \'alallahi fa-huwa hasbuh',
    translationEn: 'Whoever relies upon Allah — He is sufficient for him.',
    translationUr: 'جو اللہ پر بھروسہ کرے، اس کے لیے وہی کافی ہے۔',
    source: 'Quran 65:3',
  ),
  DuaCardContent(
    titleEn: 'Remember Me',
    titleUr: 'مجھے یاد کرو',
    arabic: 'فَاذْكُرُونِي أَذْكُرْكُمْ وَاشْكُرُوا لِي وَلَا تَكْفُرُونِ',
    transliteration: 'Fadhkuruni adhkurkum washkuru li wa la takfurun',
    translationEn: 'Remember Me and I will remember you, and be grateful to Me.',
    translationUr: 'مجھے یاد کرو میں تمہیں یاد کروں گا، اور میرا شکر کرو۔',
    source: 'Quran 2:152',
  ),
  DuaCardContent(
    titleEn: 'Do Not Despair',
    titleUr: 'مایوس نہ ہوں',
    arabic: 'وَلَا تَهِنُوا وَلَا تَحْزَنُوا وَأَنتُمُ الْأَعْلَوْنَ إِن كُنتُم مُّؤْمِنِينَ',
    transliteration: 'Wa la tahinu wa la tahzanu wa antumul-a\'lawna in kuntum mu\'minin',
    translationEn: 'Do not lose hope and do not grieve; you will prevail if you believe.',
    translationUr: 'ہمت نہ ہارو اور غم نہ کرو، تم ہی غالب رہو گے اگر ایمان رکھو۔',
    source: 'Quran 3:139',
  ),
  DuaCardContent(
    titleEn: 'Which Blessing?',
    titleUr: 'کون سی نعمت؟',
    arabic: 'فَبِأَيِّ آلَاءِ رَبِّكُمَا تُكَذِّبَانِ',
    transliteration: 'Fa-bi-ayyi ala\'i rabbikuma tukadhdhiban',
    translationEn: 'So which of the favours of your Lord will you deny?',
    translationUr: 'پھر تم اپنے رب کی کون سی نعمت جھٹلاؤ گے؟',
    source: 'Quran 55:13',
  ),
  DuaCardContent(
    titleEn: 'Ask for Knowledge',
    titleUr: 'علم کی دعا',
    arabic: 'رَبِّ زِدْنِي عِلْمًا',
    transliteration: 'Rabbi zidni \'ilma',
    translationEn: 'My Lord, increase me in knowledge.',
    translationUr: 'اے میرے رب! میرے علم میں اضافہ فرما۔',
    source: 'Quran 20:114',
  ),
  DuaCardContent(
    titleEn: 'Forgiveness',
    titleUr: 'مغفرت',
    arabic: 'رَبِّ اغْفِرْ لِي وَلِوَالِدَيَّ وَلِلْمُؤْمِنِينَ يَوْمَ يَقُومُ الْحِسَابُ',
    transliteration: 'Rabbighfir li wa li-walidayya wa lil-mu\'minina yawma yaqumul-hisab',
    translationEn: 'My Lord, forgive me, my parents, and the believers on the Day of Reckoning.',
    translationUr: 'اے میرے رب! مجھے، میرے والدین اور مومنین کو حساب کے دن معاف فرما۔',
    source: 'Quran 14:41',
  ),
  DuaCardContent(
    titleEn: 'Morning Remembrance',
    titleUr: 'صبح کا ذکر',
    arabic: 'سُبْحَانَ اللَّهِ وَبِحَمْدِهِ',
    transliteration: 'SubhanAllahi wa bihamdih',
    translationEn: 'Glory be to Allah and praise be to Him.',
    translationUr: 'اللہ پاک ہے اور اسی کے لیے تمام تعریفیں ہیں۔',
    source: 'Sahih Muslim 2691',
  ),
  DuaCardContent(
    titleEn: 'Seek Forgiveness',
    titleUr: 'استغفار',
    arabic: 'أَسْتَغْفِرُ اللَّهَ وَأَتُوبُ إِلَيْهِ',
    transliteration: 'Astaghfirullaha wa atubu ilayh',
    translationEn: 'I seek Allah\'s forgiveness and turn to Him in repentance.',
    translationUr: 'میں اللہ سے معافی مانگتا ہوں اور اسی کی طرف رجوع کرتا ہوں۔',
    source: 'Sahih al-Bukhari 6307',
  ),
];

/// Curated short ayat for the poster studio (all public-domain Quran text).
const List<(int, int)> cardStudioAyahs = [
  (13, 28),
  (94, 5),
  (94, 6),
  (65, 3),
  (2, 152),
  (3, 139),
  (55, 13),
  (39, 53),
  (2, 286),
  (20, 114),
  (14, 41),
  (59, 22),
];

const List<CardThemeOption> cardStudioThemes = [
  CardThemeOption(
    nameEn: 'Emerald Night',
    nameUr: 'زمردی رات',
    colors: [Color(0xFF0B3D2E), Color(0xFF00695C)],
    foreground: Colors.white,
    accent: Color(0xFFD4A937),
  ),
  CardThemeOption(
    nameEn: 'Midnight',
    nameUr: 'آدھی رات',
    colors: [Color(0xFF0B1E3A), Color(0xFF1F4E79)],
    foreground: Colors.white,
    accent: Color(0xFF8ECAE6),
  ),
  CardThemeOption(
    nameEn: 'Desert Sand',
    nameUr: 'صحرائی ریت',
    colors: [Color(0xFFF6E7D8), Color(0xFFEAC7B0)],
    foreground: Color(0xFF3E2723),
    accent: Color(0xFF8D6E63),
  ),
  CardThemeOption(
    nameEn: 'Royal Plum',
    nameUr: 'شاہی جامنی',
    colors: [Color(0xFF2D1233), Color(0xFF6A2C70)],
    foreground: Colors.white,
    accent: Color(0xFFE8BAFF),
  ),
  CardThemeOption(
    nameEn: 'Black & Gold',
    nameUr: 'سیاہ اور سونا',
    colors: [Color(0xFF0D0D0D), Color(0xFF2B2B2B)],
    foreground: Colors.white,
    accent: Color(0xFFD4A937),
  ),
];
