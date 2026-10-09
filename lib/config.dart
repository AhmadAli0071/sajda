class AppConfig {
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://sajdaapi.57.129.161.5.nip.io/api',
  );

  static const String appName = 'Sajda: Daily Athan & Qibla';
  static const String appTagline = 'Daily Athan & Qibla Companion';
}

class LanguageOption {
  final String code;
  final String name;
  final String nativeName;
  const LanguageOption(this.code, this.name, this.nativeName);
}

class AppStrings {
  static const Map<String, String> prayerNames = {
    'Fajr': 'فجر',
    'Sunrise': 'طلوع آفتاب',
    'Dhuhr': 'ظہر',
    'Asr': 'عصر',
    'Maghrib': 'مغرب',
    'Isha': 'عشاء',
  };

  static const List<LanguageOption> supportedLanguages = [
    LanguageOption('en', 'English', 'English'),
    LanguageOption('ur', 'Urdu', 'اردو'),
    LanguageOption('ar', 'Arabic', 'العربية'),
    LanguageOption('bn', 'Bengali', 'বাংলা'),
    LanguageOption('id', 'Indonesian', 'Bahasa Indonesia'),
    LanguageOption('tr', 'Turkish', 'Türkçe'),
    LanguageOption('fa', 'Persian', 'فارسی'),
    LanguageOption('hi', 'Hindi', 'हिन्दी'),
    LanguageOption('ms', 'Malay', 'Bahasa Melayu'),
    LanguageOption('fr', 'French', 'Français'),
  ];

  /// English-string -> { langCode: translation }.
  static const Map<String, Map<String, String>> translations = {
    'Home': {'ar': 'الرئيسية', 'bn': 'হোম', 'id': 'Beranda', 'tr': 'Ana Sayfa', 'fa': 'خانه', 'hi': 'होम', 'ms': 'Laman Utama', 'fr': 'Accueil'},
    'Settings': {'ar': 'الإعدادات', 'bn': 'সেটিংস', 'id': 'Pengaturan', 'tr': 'Ayarlar', 'fa': 'تنظیمات', 'hi': 'सेटिंग्स', 'ms': 'Tetapan', 'fr': 'Paramètres'},
    'Quran': {'ar': 'القرآن', 'bn': 'কুরআন', 'id': 'Al-Quran', 'tr': 'Kuran', 'fa': 'قرآن', 'hi': 'कुरान', 'ms': 'Al-Quran', 'fr': 'Coran'},
    'Wazifa': {'ar': 'الأذكار', 'bn': 'ওয়াজিফা', 'id': 'Wazifah', 'tr': 'Vazife', 'fa': 'ورد', 'hi': 'वज़ीफ़ा', 'ms': 'Wazifah', 'fr': 'Wazifa'},
    'Tasbeeh': {'ar': 'التسبيح', 'bn': 'তাসবিহ', 'id': 'Tasbih', 'tr': 'Tesbih', 'fa': 'تسبیح', 'hi': 'तस्बीह', 'ms': 'Tasbih', 'fr': 'Tasbih'},
    'Prayer Times': {'ar': 'أوقات الصلاة', 'bn': 'নামাজের সময়', 'id': 'Waktu Sholat', 'tr': 'Namaz Vakitleri', 'fa': 'اوقات نماز', 'hi': 'नमाज़ का समय', 'ms': 'Waktu Solat', 'fr': 'Heures de prière'},
    'Language': {'ar': 'اللغة', 'bn': 'ভাষা', 'id': 'Bahasa', 'tr': 'Dil', 'fa': 'زبان', 'hi': 'भाषा', 'ms': 'Bahasa', 'fr': 'Langue'},
    'Location': {'ar': 'الموقع', 'bn': 'অবস্থান', 'id': 'Lokasi', 'tr': 'Konum', 'fa': 'مکان', 'hi': 'स्थान', 'ms': 'Lokasi', 'fr': 'Emplacement'},
    'Dark Mode': {'ar': 'الوضع الداكن', 'bn': 'ডার্ক মোড', 'id': 'Mode Gelap', 'tr': 'Karanlık Mod', 'fa': 'حالت تاریک', 'hi': 'डार्क मोड', 'ms': 'Mod Gelap', 'fr': 'Mode sombre'},
    'Notifications': {'ar': 'الإشعارات', 'bn': 'বিজ্ঞপ্তি', 'id': 'Notifikasi', 'tr': 'Bildirimler', 'fa': 'اعلان‌ها', 'hi': 'सूचनाएँ', 'ms': 'Pemberitahuan', 'fr': 'Notifications'},
    'Next Prayer': {'ar': 'الصلاة التالية', 'bn': 'পরবর্তী নামাজ', 'id': 'Sholat Berikutnya', 'tr': 'Sonraki Namaz', 'fa': 'نماز بعدی', 'hi': 'अगली नमाज़', 'ms': 'Solat Seterusnya', 'fr': 'Prochaine prière'},
    'Time remaining': {'ar': 'الوقت المتبقي', 'bn': 'বাকি সময়', 'id': 'Waktu tersisa', 'tr': 'Kalan süre', 'fa': 'زمان باقی‌مانده', 'hi': 'शेष समय', 'ms': 'Masa berbaki', 'fr': 'Temps restant'},
    'Search': {'ar': 'بحث', 'bn': 'অনুসন্ধান', 'id': 'Cari', 'tr': 'Ara', 'fa': 'جستجو', 'hi': 'खोज', 'ms': 'Cari', 'fr': 'Rechercher'},
    'Cancel': {'ar': 'إلغاء', 'bn': 'বাতিল', 'id': 'Batal', 'tr': 'İptal', 'fa': 'لغو', 'hi': 'रद्द', 'ms': 'Batal', 'fr': 'Annuler'},
    'Continue': {'ar': 'متابعة', 'bn': 'চালিয়ে যান', 'id': 'Lanjut', 'tr': 'Devam', 'fa': 'ادامه', 'hi': 'जारी रखें', 'ms': 'Teruskan', 'fr': 'Continuer'},
    'Back': {'ar': 'رجوع', 'bn': 'পিছনে', 'id': 'Kembali', 'tr': 'Geri', 'fa': 'بازگشت', 'hi': 'पीछे', 'ms': 'Kembali', 'fr': 'Retour'},
    'Skip': {'ar': 'تخطي', 'bn': 'এড়িয়ে যান', 'id': 'Lewati', 'tr': 'Atla', 'fa': 'رد کردن', 'hi': 'छोड़ें', 'ms': 'Langkau', 'fr': 'Passer'},
    'Get Started': {'ar': 'ابدأ', 'bn': 'শুরু করুন', 'id': 'Mulai', 'tr': 'Başla', 'fa': 'شروع کن', 'hi': 'शुरू करें', 'ms': 'Mulakan', 'fr': 'Commencer'},
    'Done': {'ar': 'تم', 'bn': 'সম্পন্ন', 'id': 'Selesai', 'tr': 'Tamam', 'fa': 'انجام شد', 'hi': 'हो गया', 'ms': 'Selesai', 'fr': 'Terminé'},
    'Fajr': {'ar': 'الفجر', 'bn': 'ফজর', 'id': 'Subuh', 'tr': 'İmsak', 'fa': 'فجر', 'hi': 'फज्र', 'ms': 'Subuh', 'fr': 'Fajr'},
    'Sunrise': {'ar': 'الشروق', 'bn': 'সূর্যোদয়', 'id': 'Terbit', 'tr': 'Gün Doğumu', 'fa': 'طلوع', 'hi': 'सूर्योदय', 'ms': 'Matahari Naik', 'fr': 'Lever du soleil'},
    'Dhuhr': {'ar': 'الظهر', 'bn': 'যোহর', 'id': 'Dzuhur', 'tr': 'Öğle', 'fa': 'ظهر', 'hi': 'ज़ोहर', 'ms': 'Zohor', 'fr': 'Dhuhr'},
    'Asr': {'ar': 'العصر', 'bn': 'আসর', 'id': 'Ashar', 'tr': 'İkindi', 'fa': 'عصر', 'hi': 'असर', 'ms': 'Asar', 'fr': 'Asr'},
    'Maghrib': {'ar': 'المغرب', 'bn': 'মাগরিব', 'id': 'Maghrib', 'tr': 'Akşam', 'fa': 'مغرب', 'hi': 'मगरिब', 'ms': 'Maghrib', 'fr': 'Maghrib'},
    'Isha': {'ar': 'العشاء', 'bn': 'ইশা', 'id': 'Isya', 'tr': 'Yatsı', 'fa': 'عشاء', 'hi': 'इशा', 'ms': 'Isyak', 'fr': 'Isha'},
    'Islamic Calendar': {'ar': 'التقويم الهجري', 'bn': 'ইসলামিক ক্যালেন্ডার', 'id': 'Kalender Islam', 'tr': 'İslami Takvim', 'fa': 'تقویم اسلامی', 'hi': 'इस्लामिक कैलेंडर', 'ms': 'Kalendar Islam', 'fr': 'Calendrier islamique'},
    'Qibla Direction': {'ar': 'اتجاه القبلة', 'bn': 'কিবলার দিক', 'id': 'Arah Kiblat', 'tr': 'Kıble Yönü', 'fa': 'جهت قبله', 'hi': 'किबला दिशा', 'ms': 'Arah Kiblat', 'fr': 'Direction de la Qibla'},
    '99 Names of Allah': {'ar': 'أسماء الله الحسنى', 'bn': 'আল্লাহর ৯৯ নাম', 'id': '99 Nama Allah', 'tr': 'Allahin 99 Ismi', 'fa': '۹۹ نام خدا', 'hi': 'अल्लाह के 99 नाम', 'ms': '99 Nama Allah', 'fr': '99 Noms d Allah'},
    'Continue Reading': {'ar': 'متابعة القراءة', 'bn': 'পড়া চালিয়ে যান', 'id': 'Lanjutkan Membaca', 'tr': 'Okumaya Devam Et', 'fa': 'ادامه مطالعه', 'hi': 'पढ़ना जारी रखें', 'ms': 'Teruskan Membaca', 'fr': 'Continuer la lecture'},
    'Welcome to Sajda: Daily Athan & Qibla': {'ar': 'مرحبًا بك في Daily Athan Namaz & Qibla', 'bn': 'Daily Athan Namaz & Qibla-এ স্বাগতম', 'id': 'Selamat datang di Daily Athan Namaz & Qibla', 'tr': 'Daily Athan Namaz & Qibla Hoş Geldiniz', 'fa': 'به Daily Athan Namaz & Qibla خوش آمدید', 'hi': 'Daily Athan Namaz & Qibla में आपका स्वागत है', 'ms': 'Selamat datang ke Daily Athan Namaz & Qibla', 'fr': 'Bienvenue sur Daily Athan Namaz & Qibla'},
    'Your daily companion for prayer, Quran, duas, Islamic calendar and more.': {'ar': 'رفيقك اليومي للصلاة والقرآن والأدعية والتقويم الإسلامي وغيرها.', 'bn': 'নামাজ, কুরআন, দোয়া, ইসলামিক ক্যালেন্ডার ও আরও অনেক কিছুর দৈনিক সঙ্গী।', 'id': 'Pendamping harian Anda untuk sholat, Al-Quran, doa, kalender Islam, dan lainnya.', 'tr': 'Namaz, Kuran, dua, İslami takvim ve daha fazlasi için günlük yol arkadasiniz.', 'fa': 'همراه روزانه شما برای نماز، قرآن، دعا، تقویم اسلامی و بیشتر.', 'hi': 'नमाज़, कुरान, दुआ, इस्लामिक कैलेंडर और बहुत कुछ के लिए आपका दैनिक साथी।', 'ms': 'Rakan harian anda untuk solat, Al-Quran, doa, kalendar Islam dan banyak lagi.', 'fr': 'Votre compagnon quotidien pour la prière, le Coran, les invocations, le calendrier islamique et plus encore.'},
    'Let the Quran grow in your heart, page by page': {'ar': 'ليكبر القرآن في قلبك، صفحة بصفحة', 'bn': 'কুরআন যেন আপনার হৃদয়ে বাড়ে, পাতায় পাতায়', 'id': 'Biarkan Al-Quran tumbuh di hati Anda, halaman demi halaman', 'tr': 'Kuran kalbinizde buyusun, sayfa sayfa', 'fa': 'بگذارید قرآن صفحه به صفحه در دلتان رشد کند', 'hi': 'कुरान आपके दिल में बढ़े, पन्ना दर पन्ना', 'ms': 'Biarlah Al-Quran tumbuh di hati anda, muka surat demi muka surat', 'fr': 'Laissez le Coran grandir dans votre cœur, page après page'},
    'Salah Streak': {'ur': 'صلاح سٹریک'},
    'Start a Streak': {'ur': 'سٹریک شروع کریں'},
    'Join a Streak': {'ur': 'سٹریک میں شامل ہوں'},
    'Start Together': {'ur': 'اکٹھے شروع کریں'},
    'My Streak': {'ur': 'میری سٹریک'},
    'Share My Streak': {'ur': 'میری سٹریک شیئر کریں'},
    'Current Streak': {'ur': 'موجودہ سٹریک'},
    'Best Streak': {'ur': 'بہترین سٹریک'},
    'days': {'ur': 'دن'},
    'Day': {'ur': 'دن'},
    'Today\'s Salah': {'ur': 'آج کی نماز'},
    'Keep going 🤍': {'ur': 'جاری رکھیں 🤍'},
    'Completed': {'ur': 'مکمل'},
    'This Week': {'ur': 'اس ہفتے'},
    'Streak History': {'ur': 'سٹریک کی تاریخ'},
    'No history yet': {'ur': 'ابھی تک کوئی تاریخ نہیں'},
    'Status': {'ur': 'حیثیت'},
    'Active': {'ur': 'فعال'},
    'Paused': {'ur': 'روک دیا'},
    'Resume Streak': {'ur': 'سٹریک دوبارہ شروع کریں'},
    'Start New Streak': {'ur': 'نیا سٹریک شروع کریں'},
    'Shared Streak': {'ur': 'شیر شد سٹریک'},
    'Members': {'ur': 'ارکان'},
    'Leave': {'ur': 'چھوڑیں'},
    'Leave Streak?': {'ur': 'سٹریک چھوڑیں؟'},
    'Are you sure you want to leave?': {'ur': 'کیا آپ واقعی چھوڑنا چاہتے ہیں؟'},
    'Create Streak': {'ur': 'سٹریک بنائیں'},
    'How long is your streak?': {'ur': 'آپ کی سٹریک کتنی لمبی ہے؟'},
    'Who is joining?': {'ur': 'کون شامل ہو رہا ہے؟'},
    'Just Me': {'ur': 'صرف میں'},
    'Friends & Family': {'ur': 'دوست اور خاندان'},
    'Personal streak': {'ur': 'ذاتی سٹریک'},
    'Shared streak': {'ur': 'شیر شد سٹریک'},
    'Custom': {'ur': 'اپنی مرضی'},
    'Enter days (3-365)': {'ur': 'دن درج کریں (3-365)'},
    'Enter invite code': {'ur': 'انوائٹ کوڈ درج کریں'},
    'Lookup': {'ur': 'تلاش کریں'},
    'Invalid or expired invite': {'ur': 'غلط یا ختم ہو چکا انوائٹ'},
    'No streak yet': {'ur': 'ابھی تک کوئی سٹریک نہیں'},
    'No shared streak yet': {'ur': 'ابھی تک کوئی شیر شد سٹریک نہیں'},
    'Start your Salah Streak': {'ur': 'اپنی صلاح سٹریک شروع کریں'},
    'Build consistency one day at a time.': {'ur': 'ایک دن میں ایک مستقل بنائیں۔'},
    'Pray together. Stay consistent.': {'ur': 'اکٹھے پڑھیں۔ مستقل رہیں۔'},
    'Your Name': {'ur': 'آپ کا نام'},
    'Please enter your name': {'ur': 'براہ کرم اپنا نام درج کریں'},
    'Welcome': {'ur': 'خوش آمدید'},
    'Link copied': {'ur': 'لینک کاپی ہو گیا'},
    'Share': {'ur': 'شیئر کریں'},
    'Created by': {'ur': 'بنایا'},
    'days completed': {'ur': 'دن مکمل'},
    'members': {'ur': 'ارکان'},
    'more': {'ur': 'مزید'},
    'Goal': {'ur': 'ہدف'},
    'Streak': {'ur': 'سٹریک'},
    'Pause': {'ur': 'روکیں'},
    'Goal Days': {'ur': 'ہدف دن'},
    'streak progress': {'ur': 'سٹریک کی پیش رفت'},
    'share streak progress': {'ur': 'سٹریک کی پیش رفت شیئر کریں'},
  };
}






