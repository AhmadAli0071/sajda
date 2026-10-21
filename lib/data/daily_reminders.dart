enum ReminderKind { zikr, dua }

/// A daily dhikr or du'a with translation, all public-domain traditional text.
class DailyReminder {
  final String id;
  final ReminderKind kind;
  final String titleEn;
  final String titleUr;
  final String arabic;
  final String transliteration;
  final String translationEn;
  final String translationUr;
  final String source;

  const DailyReminder({
    required this.id,
    required this.kind,
    required this.titleEn,
    required this.titleUr,
    required this.arabic,
    required this.transliteration,
    required this.translationEn,
    required this.translationUr,
    required this.source,
  });
}

const List<DailyReminder> dailyReminders = [
  DailyReminder(
    id: 'subhanallah',
    kind: ReminderKind.zikr,
    titleEn: 'Glory be to Allah',
    titleUr: 'اللہ کی پاکی',
    arabic: 'سُبْحَانَ اللَّهِ',
    transliteration: 'SubhanAllah',
    translationEn: 'Glory be to Allah.',
    translationUr: 'اللہ پاک ہے۔',
    source: 'Sahih Muslim 2691',
  ),
  DailyReminder(
    id: 'alhamdulillah',
    kind: ReminderKind.zikr,
    titleEn: 'All praise is for Allah',
    titleUr: 'تمام تعریفیں اللہ کے لیے',
    arabic: 'الْحَمْدُ لِلَّهِ',
    transliteration: 'Alhamdulillah',
    translationEn: 'All praise is for Allah.',
    translationUr: 'تمام تعریفیں اللہ کے لیے ہیں۔',
    source: 'Sahih Muslim 2691',
  ),
  DailyReminder(
    id: 'allahuakbar',
    kind: ReminderKind.zikr,
    titleEn: 'Allah is the Greatest',
    titleUr: 'اللہ سب سے بڑا ہے',
    arabic: 'اللَّهُ أَكْبَرُ',
    transliteration: 'Allahu Akbar',
    translationEn: 'Allah is the Greatest.',
    translationUr: 'اللہ سب سے بڑا ہے۔',
    source: 'Sahih Muslim 2691',
  ),
  DailyReminder(
    id: 'lailaha',
    kind: ReminderKind.zikr,
    titleEn: 'There is no god but Allah',
    titleUr: 'اللہ کے سوا کوئی معبود نہیں',
    arabic: 'لَا إِلَهَ إِلَّا اللَّهُ',
    transliteration: 'La ilaha illallah',
    translationEn: 'There is no god but Allah.',
    translationUr: 'اللہ کے سوا کوئی معبود نہیں۔',
    source: 'Sahih al-Bukhari 6407',
  ),
  DailyReminder(
    id: 'istighfar',
    kind: ReminderKind.zikr,
    titleEn: 'Seek forgiveness',
    titleUr: 'استغفار',
    arabic: 'أَسْتَغْفِرُ اللَّهَ وَأَتُوبُ إِلَيْهِ',
    transliteration: 'Astaghfirullaha wa atubu ilayh',
    translationEn: 'I seek Allah\'s forgiveness and turn to Him in repentance.',
    translationUr: 'میں اللہ سے معافی مانگتا ہوں اور اسی کی طرف رجوع کرتا ہوں۔',
    source: 'Sahih al-Bukhari 6307',
  ),
  DailyReminder(
    id: 'hawqala',
    kind: ReminderKind.zikr,
    titleEn: 'No power except with Allah',
    titleUr: 'طاقت صرف اللہ سے',
    arabic: 'لَا حَوْلَ وَلَا قُوَّةَ إِلَّا بِاللَّهِ',
    transliteration: 'La hawla wa la quwwata illa billah',
    translationEn: 'There is no might nor power except with Allah.',
    translationUr: 'اللہ کے سوا نہ کوئی طاقت ہے نہ قوت۔',
    source: 'Sahih al-Bukhari 6384',
  ),
  DailyReminder(
    id: 'tasbih_fatimah',
    kind: ReminderKind.zikr,
    titleEn: 'Tasbeeh of Fatimah',
    titleUr: 'تسبیح فاطمہ',
    arabic: 'سُبْحَانَ اللَّهِ وَالْحَمْدُ لِلَّهِ وَلَا إِلَهَ إِلَّا اللَّهُ وَاللَّهُ أَكْبَرُ',
    transliteration:
        'SubhanAllah, walhamdulillah, wa la ilaha illallah, wallahu akbar',
    translationEn:
        'Glory be to Allah, all praise is for Allah, there is no god but Allah, and Allah is the Greatest.',
    translationUr:
        'اللہ پاک ہے، تمام تعریفیں اللہ کے لیے، اللہ کے سوا کوئی معبود نہیں، اور اللہ سب سے بڑا ہے۔',
    source: 'Sahih Muslim 2137',
  ),
  DailyReminder(
    id: 'rabbana_atina',
    kind: ReminderKind.dua,
    titleEn: 'Good in both worlds',
    titleUr: 'دونوں جہانوں کی بھلائی',
    arabic: 'رَبَّنَا آتِنَا فِي الدُّنْيَا حَسَنَةً وَفِي الآخِرَةِ حَسَنَةً وَقِنَا عَذَابَ النَّارِ',
    transliteration:
        'Rabbana atina fid-dunya hasanatan wa fil-akhirati hasanatan wa qina \'adhaban-nar',
    translationEn:
        'Our Lord, give us good in this world and good in the Hereafter, and protect us from the Fire.',
    translationUr:
        'اے ہمارے رب! ہمیں دنیا میں بھی بھلائی دے اور آخرت میں بھی بھلائی دے، اور ہمیں آگ کے عذاب سے بچا۔',
    source: 'Quran 2:201',
  ),
  DailyReminder(
    id: 'rabbana_taqabbal',
    kind: ReminderKind.dua,
    titleEn: 'Accept our worship',
    titleUr: 'ہماری عبادت قبول فرما',
    arabic: 'رَبَّنَا تَقَبَّلْ مِنَّا إِنَّكَ أَنتَ السَّمِيعُ الْعَلِيمُ',
    transliteration: 'Rabbana taqabbal minna innaka antas-Sami\'ul-\'Alim',
    translationEn:
        'Our Lord, accept this from us. Indeed You are the All-Hearing, the All-Knowing.',
    translationUr:
        'اے ہمارے رب! ہم سے قبول فرما، بے شک تو سب کچھ سننے والا، سب کچھ جاننے والا ہے۔',
    source: 'Quran 2:127',
  ),
  DailyReminder(
    id: 'rabbishrah',
    kind: ReminderKind.dua,
    titleEn: 'Expand my heart',
    titleUr: 'میرا سینہ کھول دے',
    arabic: 'رَبِّ اشْرَحْ لِي صَدْرِي وَيَسِّرْ لِي أَمْرِي',
    transliteration: 'Rabbishrah li sadri wa yassir li amri',
    translationEn: 'My Lord, expand my chest and ease my task for me.',
    translationUr: 'اے میرے رب! میرا سینہ کھول دے اور میرا کام آسان فرما دے۔',
    source: 'Quran 20:25-26',
  ),
  DailyReminder(
    id: 'hasbunallah',
    kind: ReminderKind.dua,
    titleEn: 'Allah is sufficient',
    titleUr: 'اللہ کافی ہے',
    arabic: 'حَسْبُنَا اللَّهُ وَنِعْمَ الْوَكِيلُ',
    transliteration: 'Hasbunallahu wa ni\'mal-wakil',
    translationEn: 'Allah is sufficient for us, and He is the best Disposer of affairs.',
    translationUr: 'ہمیں اللہ کافی ہے اور وہ بہترین کارساز ہے۔',
    source: 'Quran 3:173',
  ),
  DailyReminder(
    id: 'ayyub',
    kind: ReminderKind.dua,
    titleEn: 'Dua of Ayyub',
    titleUr: 'ایوب کی دعا',
    arabic: 'أَنِّي مَسَّنِيَ الضُّرُّ وَأَنتَ أَرْحَمُ الرَّاحِمِينَ',
    transliteration: 'Anni massaniyad-durru wa anta arhamur-rahimin',
    translationEn:
        'Indeed, adversity has touched me, and You are the most merciful of the merciful.',
    translationUr:
        'بے شک مجھے تکلیف پہنچی ہے اور تو سب سے زیادہ رحم کرنے والا ہے۔',
    source: 'Quran 21:83',
  ),
];

/// Stable daily rotation. [category] is `all`, `zikr`, or `dua`.
DailyReminder reminderForDay(DateTime day, {String category = 'all'}) {
  final pool = category == 'zikr'
      ? dailyReminders.where((r) => r.kind == ReminderKind.zikr).toList()
      : category == 'dua'
          ? dailyReminders.where((r) => r.kind == ReminderKind.dua).toList()
          : dailyReminders;
  final safe = pool.isEmpty ? dailyReminders : pool;
  final dayOfYear = day.difference(DateTime(day.year)).inDays;
  return safe[dayOfYear % safe.length];
}
