import 'dart:math' as math;

import 'package:shared_preferences/shared_preferences.dart';

class CityData {
  final String name;
  final String country;
  final double lat;
  final double lng;
  final int qibla;
  final String timezone;
  final List<String> aliases;

  const CityData({
    required this.name,
    required this.country,
    required this.lat,
    required this.lng,
    required this.qibla,
    required this.timezone,
    this.aliases = const [],
  });

  @override
  String toString() => '$name, $country';
}

const List<CityData> citiesDb = [
  CityData(name: 'Mecca', country: 'Saudi Arabia', lat: 21.3891, lng: 39.8579, qibla: 251, timezone: 'Asia/Riyadh'),
  CityData(name: 'Medina', country: 'Saudi Arabia', lat: 24.4672, lng: 39.6112, qibla: 252, timezone: 'Asia/Riyadh'),
  CityData(name: 'Riyadh', country: 'Saudi Arabia', lat: 24.7136, lng: 46.6753, qibla: 248, timezone: 'Asia/Riyadh'),
  CityData(name: 'Dubai', country: 'UAE', lat: 25.2048, lng: 55.2708, qibla: 260, timezone: 'Asia/Dubai'),
  CityData(name: 'Karachi', country: 'Pakistan', lat: 24.8607, lng: 67.0011, qibla: 268, timezone: 'Asia/Karachi', aliases: ['کراچی']),
  CityData(name: 'Lahore', country: 'Pakistan', lat: 31.5497, lng: 74.3436, qibla: 265, timezone: 'Asia/Karachi', aliases: ['لاہور']),
  CityData(name: 'Islamabad', country: 'Pakistan', lat: 33.6844, lng: 73.0479, qibla: 261, timezone: 'Asia/Karachi', aliases: ['اسلام آباد']),
  CityData(name: 'Rahim Yar Khan', country: 'Pakistan', lat: 28.3902, lng: 70.3216, qibla: 270, timezone: 'Asia/Karachi', aliases: ['رحیم یار خان', 'RYK']),
  CityData(name: 'Bahawalpur', country: 'Pakistan', lat: 29.3846, lng: 71.6729, qibla: 269, timezone: 'Asia/Karachi', aliases: ['بہاولپور']),
  CityData(name: 'Peshawar', country: 'Pakistan', lat: 34.0151, lng: 71.5249, qibla: 256, timezone: 'Asia/Karachi', aliases: ['پشاور']),
  CityData(name: 'Multan', country: 'Pakistan', lat: 30.1575, lng: 71.5249, qibla: 267, timezone: 'Asia/Karachi', aliases: ['ملتان']),
  CityData(name: 'Faisalabad', country: 'Pakistan', lat: 31.4504, lng: 73.1350, qibla: 264, timezone: 'Asia/Karachi', aliases: ['فیصل آباد']),
  CityData(name: 'Quetta', country: 'Pakistan', lat: 30.1798, lng: 66.9750, qibla: 252, timezone: 'Asia/Karachi', aliases: ['کوئٹہ']),
  CityData(name: 'Gujranwala', country: 'Pakistan', lat: 32.1606, lng: 74.1852, qibla: 263, timezone: 'Asia/Karachi', aliases: ['گوجرانوالہ']),
  CityData(name: 'Sialkot', country: 'Pakistan', lat: 32.4945, lng: 74.5229, qibla: 262, timezone: 'Asia/Karachi', aliases: ['سیالکوٹ']),
  CityData(name: 'Sargodha', country: 'Pakistan', lat: 32.0837, lng: 72.6711, qibla: 260, timezone: 'Asia/Karachi', aliases: ['سرگودھا']),
  CityData(name: 'Dhaka', country: 'Bangladesh', lat: 23.8103, lng: 90.4125, qibla: 279, timezone: 'Asia/Dhaka'),
  CityData(name: 'Mumbai', country: 'India', lat: 19.0760, lng: 72.8777, qibla: 276, timezone: 'Asia/Kolkata'),
  CityData(name: 'Delhi', country: 'India', lat: 28.7041, lng: 77.1025, qibla: 272, timezone: 'Asia/Kolkata'),
  CityData(name: 'Cairo', country: 'Egypt', lat: 30.0444, lng: 31.2357, qibla: 136, timezone: 'Africa/Cairo'),
  CityData(name: 'Istanbul', country: 'Turkey', lat: 41.0082, lng: 28.9784, qibla: 150, timezone: 'Europe/Istanbul'),
  CityData(name: 'Kuala Lumpur', country: 'Malaysia', lat: 3.1390, lng: 101.6869, qibla: 293, timezone: 'Asia/Kuala_Lumpur'),
  CityData(name: 'Jakarta', country: 'Indonesia', lat: -6.2088, lng: 106.8456, qibla: 298, timezone: 'Asia/Jakarta'),
  CityData(name: 'London', country: 'United Kingdom', lat: 51.5074, lng: -0.1278, qibla: 119, timezone: 'Europe/London'),
  CityData(name: 'New York', country: 'United States', lat: 40.7128, lng: -74.0060, qibla: 58, timezone: 'America/New_York'),
  CityData(name: 'Toronto', country: 'Canada', lat: 43.6532, lng: -79.3832, qibla: 58, timezone: 'America/Toronto'),
  CityData(name: 'Sydney', country: 'Australia', lat: -33.8688, lng: 151.2093, qibla: 277, timezone: 'Australia/Sydney'),
];

/// Finds nearest city to given coordinates using haversine distance.
CityData? nearestCity(double lat, double lng) {
  if (citiesDb.isEmpty) return null;
  CityData? best;
  var bestDist = double.infinity;
  for (final c in citiesDb) {
    final d = haversineKm(lat, lng, c.lat, c.lng);
    if (d < bestDist) {
      bestDist = d;
      best = c;
    }
  }
  return best;
}

double haversineKm(double lat1, double lon1, double lat2, double lon2) {
  const r = 6371.0;
  final dLat = _rad(lat2 - lat1);
  final dLon = _rad(lon2 - lon1);
  final a = math.pow(math.sin(dLat / 2), 2) +
      math.cos(_rad(lat1)) * math.cos(_rad(lat2)) * math.pow(math.sin(dLon / 2), 2);
  return 2 * r * math.asin(math.sqrt(a));
}

double _rad(double deg) => deg * math.pi / 180.0;

// ---------- Tasbeeh presets ----------

class TasbeehPreset {
  final String name;
  final String arabic;
  final String meaning;
  final int defaultCount;
  const TasbeehPreset({
    required this.name,
    required this.arabic,
    required this.meaning,
    required this.defaultCount,
  });
}

const List<TasbeehPreset> tasbeehPresets = [
  TasbeehPreset(name: 'SubhanAllah', arabic: 'سُبْحَانَ اللَّهِ', meaning: 'Glory be to Allah', defaultCount: 33),
  TasbeehPreset(name: 'Alhamdulillah', arabic: 'الْحَمْدُ لِلَّهِ', meaning: 'All praise is for Allah', defaultCount: 33),
  TasbeehPreset(name: 'Allahu Akbar', arabic: 'اللَّهُ أَكْبَرُ', meaning: 'Allah is the Greatest', defaultCount: 33),
  TasbeehPreset(name: 'La ilaha illallah', arabic: 'لَا إِلَٰهَ إِلَّا اللَّهُ', meaning: 'There is no god but Allah', defaultCount: 100),
  TasbeehPreset(name: 'Astaghfirullah', arabic: 'أَسْتَغْفِرُ اللَّهَ', meaning: 'I seek forgiveness from Allah', defaultCount: 100),
  TasbeehPreset(name: 'Darood Sharif', arabic: 'اللَّهُمَّ صَلِّ عَلَىٰ مُحَمَّدٍ', meaning: 'Blessings upon Muhammad ﷺ', defaultCount: 100),
];

// ---------- 99 Names of Allah ----------

class AllahName {
  final int number;
  final String arabic;
  final String en;
  final String ur;
  final String meaning;
  final String meaningUr;
  const AllahName({
    required this.number,
    required this.arabic,
    required this.en,
    required this.ur,
    required this.meaning,
    required this.meaningUr,
  });
}

const List<AllahName> allahNames = [
  AllahName(number: 1, arabic: 'الرَّحْمٰنُ', en: 'Ar-Rahman', ur: 'الرحمٰن', meaning: 'The Most Gracious', meaningUr: 'بے حد رحم کرنے والا'),
  AllahName(number: 2, arabic: 'الرَّحِيْمُ', en: 'Ar-Raheem', ur: 'الرحیم', meaning: 'The Most Merciful', meaningUr: 'بے انتہا رحم کرنے والا'),
  AllahName(number: 3, arabic: 'الْمَلِكُ', en: 'Al-Malik', ur: 'الملک', meaning: 'The King', meaningUr: 'بادشاہ'),
  AllahName(number: 4, arabic: 'الْقُدُّوسُ', en: 'Al-Quddus', ur: 'القدوس', meaning: 'The Holy', meaningUr: 'نہایت پاک'),
  AllahName(number: 5, arabic: 'السَّلَامُ', en: 'As-Salam', ur: 'السلام', meaning: 'The Source of Peace', meaningUr: 'سلامتی کا سرچشمہ'),
  AllahName(number: 6, arabic: 'الْمُؤْمِنُ', en: 'Al-Mu\'min', ur: 'المؤمن', meaning: 'The Guardian of Faith', meaningUr: 'ایمان دینے والا'),
  AllahName(number: 7, arabic: 'الْمُهَيْمِنُ', en: 'Al-Muhaymin', ur: 'المہیمن', meaning: 'The Protector', meaningUr: 'نگران و محافظ'),
  AllahName(number: 8, arabic: 'الْعَزِيْزُ', en: 'Al-Aziz', ur: 'العزیز', meaning: 'The Almighty', meaningUr: 'غالب و زبردست'),
  AllahName(number: 9, arabic: 'الْجَبَّارُ', en: 'Al-Jabbar', ur: 'الجبار', meaning: 'The Compeller', meaningUr: 'جبر فرمانے والا'),
  AllahName(number: 10, arabic: 'الْمُتَكَبِّرُ', en: 'Al-Mutakabbir', ur: 'المتکبر', meaning: 'The Supreme', meaningUr: 'بڑائی والا'),
  AllahName(number: 11, arabic: 'الْخَالِقُ', en: 'Al-Khaliq', ur: 'الخالق', meaning: 'The Creator', meaningUr: 'پیدا کرنے والا'),
  AllahName(number: 12, arabic: 'الْبَارِئُ', en: 'Al-Bari', ur: 'البارئ', meaning: 'The Maker', meaningUr: 'ٹھیک بنانے والا'),
  AllahName(number: 13, arabic: 'الْمُصَوِّرُ', en: 'Al-Musawwir', ur: 'المصور', meaning: 'The Shaper of Beauty', meaningUr: 'صورت بنانے والا'),
  AllahName(number: 14, arabic: 'الْغَفَّارُ', en: 'Al-Ghaffar', ur: 'الغفار', meaning: 'The Great Forgiver', meaningUr: 'بڑا بخشنے والا'),
  AllahName(number: 15, arabic: 'الْقَهَّارُ', en: 'Al-Qahhar', ur: 'القهار', meaning: 'The Subduer', meaningUr: 'دبانے والا'),
  AllahName(number: 16, arabic: 'الْوَهَّابُ', en: 'Al-Wahhab', ur: 'الوہاب', meaning: 'The Bestower', meaningUr: 'بے حساب دینے والا'),
  AllahName(number: 17, arabic: 'الرَّزَّاقُ', en: 'Ar-Razzaq', ur: 'الرزاق', meaning: 'The Provider', meaningUr: 'روزی دینے والا'),
  AllahName(number: 18, arabic: 'الْفَتَّاحُ', en: 'Al-Fattah', ur: 'الفتاح', meaning: 'The Opener', meaningUr: 'کھولنے والا'),
  AllahName(number: 19, arabic: 'الْعَلِيْمُ', en: 'Al-Aleem', ur: 'العلیم', meaning: 'The All-Knowing', meaningUr: 'سب کچھ جاننے والا'),
  AllahName(number: 20, arabic: 'الْقَابِضُ', en: 'Al-Qabid', ur: 'القابض', meaning: 'The Withholder', meaningUr: 'روک لینے والا'),
  AllahName(number: 21, arabic: 'الْبَاسِطُ', en: 'Al-Basit', ur: 'الباسط', meaning: 'The Expander', meaningUr: 'کشادگی دینے والا'),
  AllahName(number: 22, arabic: 'الْخَافِضُ', en: 'Al-Khafid', ur: 'الخافض', meaning: 'The Abaser', meaningUr: 'پست کرنے والا'),
  AllahName(number: 23, arabic: 'الرَّافِعُ', en: 'Ar-Rafi', ur: 'الرافع', meaning: 'The Exalter', meaningUr: 'بلند کرنے والا'),
  AllahName(number: 24, arabic: 'الْمُعِزُّ', en: 'Al-Mu\'izz', ur: 'المعز', meaning: 'The Bestower of Honor', meaningUr: 'عزت دینے والا'),
  AllahName(number: 25, arabic: 'الْمُذِلُّ', en: 'Al-Mudhill', ur: 'المذل', meaning: 'The Humiliator', meaningUr: 'ذلیل کرنے والا'),
  AllahName(number: 26, arabic: 'السَّمِيْعُ', en: 'As-Sami', ur: 'السمیع', meaning: 'The All-Hearing', meaningUr: 'سب کچھ سننے والا'),
  AllahName(number: 27, arabic: 'الْبَصِيْرُ', en: 'Al-Basir', ur: 'البصیر', meaning: 'The All-Seeing', meaningUr: 'سب کچھ دیکھنے والا'),
  AllahName(number: 28, arabic: 'الْحَكَمُ', en: 'Al-Hakam', ur: 'الحکم', meaning: 'The Judge', meaningUr: 'فیصلہ کرنے والا'),
  AllahName(number: 29, arabic: 'الْعَدْلُ', en: 'Al-Adl', ur: 'العدل', meaning: 'The Just', meaningUr: 'انصاف کرنے والا'),
  AllahName(number: 30, arabic: 'اللَّطِيْفُ', en: 'Al-Latif', ur: 'اللطیف', meaning: 'The Subtle One', meaningUr: 'باریک بین و مہربان'),
  AllahName(number: 31, arabic: 'الْخَبِيْرُ', en: 'Al-Khabir', ur: 'الخبیر', meaning: 'The All-Aware', meaningUr: 'باخبر'),
  AllahName(number: 32, arabic: 'الْحَلِيْمُ', en: 'Al-Halim', ur: 'الحلیم', meaning: 'The Forbearing', meaningUr: 'بردبار'),
  AllahName(number: 33, arabic: 'الْعَظِيْمُ', en: 'Al-Azim', ur: 'العظیم', meaning: 'The Magnificent', meaningUr: 'بڑی عظمت والا'),
  AllahName(number: 34, arabic: 'الْغَفُوْرُ', en: 'Al-Ghafur', ur: 'الغفور', meaning: 'The Forgiving', meaningUr: 'بخشنے والا'),
  AllahName(number: 35, arabic: 'الشَّكُوْرُ', en: 'Ash-Shakur', ur: 'الشکور', meaning: 'The Appreciative', meaningUr: 'قدر کرنے والا'),
  AllahName(number: 36, arabic: 'الْعَلِيُّ', en: 'Al-Ali', ur: 'العلی', meaning: 'The Most High', meaningUr: 'بلند مرتبہ'),
  AllahName(number: 37, arabic: 'الْكَبِيْرُ', en: 'Al-Kabir', ur: 'الکبیر', meaning: 'The Most Great', meaningUr: 'بڑا'),
  AllahName(number: 38, arabic: 'الْحَفِيْظُ', en: 'Al-Hafiz', ur: 'الحفیظ', meaning: 'The Preserver', meaningUr: 'حفاظت کرنے والا'),
  AllahName(number: 39, arabic: 'الْمُقِيْتُ', en: 'Al-Muqit', ur: 'المقیت', meaning: 'The Sustainer', meaningUr: 'غذا پہنچانے والا'),
  AllahName(number: 40, arabic: 'الْحَسِيْبُ', en: 'Al-Hasib', ur: 'الحسیب', meaning: 'The Reckoner', meaningUr: 'حساب لینے والا'),
  AllahName(number: 41, arabic: 'الْجَلِيْلُ', en: 'Al-Jalil', ur: 'الجلیل', meaning: 'The Majestic', meaningUr: 'بڑی شان والا'),
  AllahName(number: 42, arabic: 'الْكَرِيْمُ', en: 'Al-Karim', ur: 'الکریم', meaning: 'The Generous', meaningUr: 'سخی'),
  AllahName(number: 43, arabic: 'الرَّقِيْبُ', en: 'Ar-Raqib', ur: 'الرقیب', meaning: 'The Watchful', meaningUr: 'نگہبان'),
  AllahName(number: 44, arabic: 'الْمُجِيْبُ', en: 'Al-Mujib', ur: 'المجیب', meaning: 'The Responsive', meaningUr: 'دعا قبول کرنے والا'),
  AllahName(number: 45, arabic: 'الْوَاسِعُ', en: 'Al-Wasi', ur: 'الواسع', meaning: 'The All-Encompassing', meaningUr: 'وسیع'),
  AllahName(number: 46, arabic: 'الْحَكِيْمُ', en: 'Al-Hakim', ur: 'الحکیم', meaning: 'The All-Wise', meaningUr: 'حکمت والا'),
  AllahName(number: 47, arabic: 'الْوَدُوْدُ', en: 'Al-Wadud', ur: 'الودود', meaning: 'The Loving', meaningUr: 'محبت کرنے والا'),
  AllahName(number: 48, arabic: 'الْمَجِيْدُ', en: 'Al-Majid', ur: 'المجید', meaning: 'The Glorious', meaningUr: 'عزت والا'),
  AllahName(number: 49, arabic: 'الْبَاعِثُ', en: 'Al-Ba\'ith', ur: 'الباعث', meaning: 'The Resurrector', meaningUr: 'اٹھانے والا'),
  AllahName(number: 50, arabic: 'الشَّهِيْدُ', en: 'Ash-Shahid', ur: 'الشہید', meaning: 'The Witness', meaningUr: 'گواہ'),
  AllahName(number: 51, arabic: 'الْحَقُّ', en: 'Al-Haqq', ur: 'الحق', meaning: 'The Truth', meaningUr: 'حق'),
  AllahName(number: 52, arabic: 'الْوَكِيْلُ', en: 'Al-Wakil', ur: 'الوکیل', meaning: 'The Trustee', meaningUr: 'کارساز'),
  AllahName(number: 53, arabic: 'الْقَوِيُّ', en: 'Al-Qawiyy', ur: 'القوی', meaning: 'The Strong', meaningUr: 'طاقتور'),
  AllahName(number: 54, arabic: 'الْمَتِيْنُ', en: 'Al-Matin', ur: 'المتین', meaning: 'The Firm', meaningUr: 'مضبوط'),
  AllahName(number: 55, arabic: 'الْوَلِيُّ', en: 'Al-Waliyy', ur: 'الولی', meaning: 'The Protecting Friend', meaningUr: 'دوست و مددگار'),
  AllahName(number: 56, arabic: 'الْحَمِيْدُ', en: 'Al-Hamid', ur: 'الحمید', meaning: 'The Praiseworthy', meaningUr: 'قابل تعریف'),
  AllahName(number: 57, arabic: 'الْمُحْصِي', en: 'Al-Muhsi', ur: 'المحصی', meaning: 'The Accounter', meaningUr: 'شمار کرنے والا'),
  AllahName(number: 58, arabic: 'الْمُبْدِئُ', en: 'Al-Mubdi', ur: 'المبدئ', meaning: 'The Originator', meaningUr: 'پہلی بار پیدا کرنے والا'),
  AllahName(number: 59, arabic: 'الْمُعِيْدُ', en: 'Al-Mu\'id', ur: 'المعید', meaning: 'The Restorer', meaningUr: 'دوبارہ پیدا کرنے والا'),
  AllahName(number: 60, arabic: 'الْمُحْيِي', en: 'Al-Muhyi', ur: 'المحیی', meaning: 'The Giver of Life', meaningUr: 'زندگی دینے والا'),
  AllahName(number: 61, arabic: 'الْمُمِيْتُ', en: 'Al-Mumit', ur: 'الممیت', meaning: 'The Taker of Life', meaningUr: 'موت دینے والا'),
  AllahName(number: 62, arabic: 'الْحَيُّ', en: 'Al-Hayy', ur: 'الحی', meaning: 'The Ever-Living', meaningUr: 'زندہ'),
  AllahName(number: 63, arabic: 'الْقَيُّوْمُ', en: 'Al-Qayyum', ur: 'القیوم', meaning: 'The Sustainer of All', meaningUr: 'سب کو سنبھالنے والا'),
  AllahName(number: 64, arabic: 'الْوَاجِدُ', en: 'Al-Wajid', ur: 'الواجد', meaning: 'The Finder', meaningUr: 'پانے والا'),
  AllahName(number: 65, arabic: 'الْمَاجِدُ', en: 'Al-Majid', ur: 'الماجد', meaning: 'The Noble', meaningUr: 'بزرگی والا'),
  AllahName(number: 66, arabic: 'الْوَاحِدُ', en: 'Al-Wahid', ur: 'الواحد', meaning: 'The One', meaningUr: 'اکیلا'),
  AllahName(number: 67, arabic: 'الْأَحَدُ', en: 'Al-Ahad', ur: 'الاحد', meaning: 'The Unique', meaningUr: 'یکتا'),
  AllahName(number: 68, arabic: 'الصَّمَدُ', en: 'As-Samad', ur: 'الصمد', meaning: 'The Eternal', meaningUr: 'بے نیاز'),
  AllahName(number: 69, arabic: 'الْقَادِرُ', en: 'Al-Qadir', ur: 'القادر', meaning: 'The All-Powerful', meaningUr: 'قدرت والا'),
  AllahName(number: 70, arabic: 'الْمُقْتَدِرُ', en: 'Al-Muqtadir', ur: 'المقتدر', meaning: 'The Determiner', meaningUr: 'اختیار والا'),
  AllahName(number: 71, arabic: 'الْمُقَدِّمُ', en: 'Al-Muqaddim', ur: 'المقدم', meaning: 'The Advancer', meaningUr: 'آگے کرنے والا'),
  AllahName(number: 72, arabic: 'الْمُؤَخِّرُ', en: 'Al-Mu\'akhkhir', ur: 'المؤخر', meaning: 'The Deferrer', meaningUr: 'پیچھے کرنے والا'),
  AllahName(number: 73, arabic: 'الْأَوَّلُ', en: 'Al-Awwal', ur: 'الاول', meaning: 'The First', meaningUr: 'اول'),
  AllahName(number: 74, arabic: 'الْآخِرُ', en: 'Al-Akhir', ur: 'الآخر', meaning: 'The Last', meaningUr: 'آخر'),
  AllahName(number: 75, arabic: 'الظَّاهِرُ', en: 'Az-Zahir', ur: 'الظاہر', meaning: 'The Manifest', meaningUr: 'ظاہر'),
  AllahName(number: 76, arabic: 'الْبَاطِنُ', en: 'Al-Batin', ur: 'الباطن', meaning: 'The Hidden', meaningUr: 'باطن'),
  AllahName(number: 77, arabic: 'الْوَالِي', en: 'Al-Wali', ur: 'الوالی', meaning: 'The Governor', meaningUr: 'مالک و حاکم'),
  AllahName(number: 78, arabic: 'الْمُتَعَالِي', en: 'Al-Muta\'ali', ur: 'المتعالی', meaning: 'The Self-Exalted', meaningUr: 'بہت بلند'),
  AllahName(number: 79, arabic: 'الْبَرُّ', en: 'Al-Barr', ur: 'البر', meaning: 'The Source of Goodness', meaningUr: 'نیکی کرنے والا'),
  AllahName(number: 80, arabic: 'التَّوَّابُ', en: 'At-Tawwab', ur: 'التواب', meaning: 'The Acceptor of Repentance', meaningUr: 'توبہ قبول کرنے والا'),
  AllahName(number: 81, arabic: 'الْمُنْتَقِمُ', en: 'Al-Muntaqim', ur: 'المنتقم', meaning: 'The Avenger', meaningUr: 'بدلہ لینے والا'),
  AllahName(number: 82, arabic: 'الْعَفُوُّ', en: 'Al-\'Afuww', ur: 'العفو', meaning: 'The Pardoner', meaningUr: 'معاف کرنے والا'),
  AllahName(number: 83, arabic: 'الرَّؤُوْفُ', en: 'Ar-Ra\'uf', ur: 'الرؤوف', meaning: 'The Kind', meaningUr: 'شفیق'),
  AllahName(number: 84, arabic: 'مَالِكُ الْمُلْكِ', en: 'Malik-ul-Mulk', ur: 'مالک الملک', meaning: 'The Owner of All Sovereignty', meaningUr: 'بادشاہی کا مالک'),
  AllahName(number: 85, arabic: 'ذُو الْجَلَالِ وَالْإِكْرَامِ', en: 'Dhul-Jalali wal-Ikram', ur: 'ذوالجلال والاکرام', meaning: 'The Lord of Majesty and Honor', meaningUr: 'بزرگی اور عزت والا'),
  AllahName(number: 86, arabic: 'الْمُقْسِطُ', en: 'Al-Muqsit', ur: 'المقسط', meaning: 'The Equitable', meaningUr: 'انصاف کرنے والا'),
  AllahName(number: 87, arabic: 'الْجَامِعُ', en: 'Al-Jami', ur: 'الجامع', meaning: 'The Gatherer', meaningUr: 'جمع کرنے والا'),
  AllahName(number: 88, arabic: 'الْغَنِيُّ', en: 'Al-Ghani', ur: 'الغنی', meaning: 'The Self-Sufficient', meaningUr: 'بے نیاز'),
  AllahName(number: 89, arabic: 'الْمُغْنِي', en: 'Al-Mughni', ur: 'المغنی', meaning: 'The Enricher', meaningUr: 'غنی کرنے والا'),
  AllahName(number: 90, arabic: 'الْمَانِعُ', en: 'Al-Mani', ur: 'المانع', meaning: 'The Preventer', meaningUr: 'روکنے والا'),
  AllahName(number: 91, arabic: 'الضَّارُّ', en: 'Ad-Darr', ur: 'الضار', meaning: 'The Distresser', meaningUr: 'تکلیف دینے والا'),
  AllahName(number: 92, arabic: 'النَّافِعُ', en: 'An-Nafi', ur: 'النافع', meaning: 'The Benefiter', meaningUr: 'نفع دینے والا'),
  AllahName(number: 93, arabic: 'النُّوْرُ', en: 'An-Nur', ur: 'النور', meaning: 'The Light', meaningUr: 'روشن کرنے والا'),
  AllahName(number: 94, arabic: 'الْهَادِي', en: 'Al-Hadi', ur: 'الہادی', meaning: 'The Guide', meaningUr: 'ہدایت دینے والا'),
  AllahName(number: 95, arabic: 'الْبَدِيْعُ', en: 'Al-Badi', ur: 'البدیع', meaning: 'The Originator', meaningUr: 'نئی چیز پیدا کرنے والا'),
  AllahName(number: 96, arabic: 'الْبَاقِي', en: 'Al-Baqi', ur: 'الباقی', meaning: 'The Everlasting', meaningUr: 'ہمیشہ رہنے والا'),
  AllahName(number: 97, arabic: 'الْوَارِثُ', en: 'Al-Warith', ur: 'الوارث', meaning: 'The Inheritor', meaningUr: 'وارث'),
  AllahName(number: 98, arabic: 'الرَّشِيْدُ', en: 'Ar-Rashid', ur: 'الرشید', meaning: 'The Guide to the Right Path', meaningUr: 'راہ دکھانے والا'),
  AllahName(number: 99, arabic: 'الصَّبُوْرُ', en: 'As-Sabur', ur: 'الصبور', meaning: 'The Patient', meaningUr: 'صبر کرنے والا'),
];

/// Random Asma-ul-Husna picker shared by the home greeting.
/// Avoids repeating the name shown on the previous app launch.
class AllahNames {
  static const _kPrefKey = 'sajda_allah_name_index';

  static Future<int> pickFreshIndex() async {
    final prefs = await SharedPreferences.getInstance();
    final last = prefs.getInt(_kPrefKey) ?? -1;
    var idx = math.Random().nextInt(allahNames.length);
    if (allahNames.length > 1 && idx == last) {
      idx = (idx + 1) % allahNames.length;
    }
    await prefs.setInt(_kPrefKey, idx);
    return idx;
  }
}