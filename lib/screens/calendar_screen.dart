import 'package:hijri/hijri_calendar.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../services/api_client.dart';
import '../services/hijri_date_service.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../utils/time_format.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  List<HijriDay> _days = [];
  bool _loading = true;
  String? _error;
  int _currentHijriMonth = 0;
  int _currentHijriYear = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      // Generate calendar locally using Umm al-Qura algorithm
      final today = DateTime.now();
      final hijriToday = HijriDateService.getHijriDate(today);
      _currentHijriMonth = hijriToday.month;
      _currentHijriYear = hijriToday.year;

      final days = _generateHijriMonth(_currentHijriYear, _currentHijriMonth);
      
      if (!mounted) return;
      setState(() {
        _days = days;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  /// Generate a full Hijri month locally using Umm al-Qura algorithm
  List<HijriDay> _generateHijriMonth(int hijriYear, int hijriMonth) {
    final days = <HijriDay>[];
    final calendar = HijriCalendar();
    HijriCalendar.language = 'en';

    // Get days in this Hijri month using Umm al-Qura data
    final daysInMonth = calendar.getDaysInMonth(hijriYear, hijriMonth);

    for (int day = 1; day <= daysInMonth; day++) {
      final gregorian = calendar.hijriToGregorian(hijriYear, hijriMonth, day);
      // Inverse of the service adjustment: displayed Hijri day N sits on the
      // Gregorian date shifted by minus the user offset, so the grid, the
      // "today" highlight and the home header all stay consistent.
      final shifted = gregorian
          .subtract(Duration(days: HijriDateService.adjustDays));
      final gregorianStr =
          '${shifted.year}-${shifted.month.toString().padLeft(2, '0')}-${shifted.day.toString().padLeft(2, '0')}';

      HijriCalendar.language = 'en';

      days.add(HijriDay(
        gregorian: _formatGregDate(gregorianStr),
        day: day.toString(),
        month: englishMonths[hijriMonth - 1],
        monthNumber: hijriMonth.toString(),
        year: hijriYear.toString(),
      ));
    }

    return days;
  }

  static const englishMonths = [
    'Muharram', 'Safar', 'Rabi al-Awwal', 'Rabi al-Thani',
    'Jumada al-Awwal', 'Jumada al-Thani', 'Rajab', 'Sha\'ban',
    'Ramadan', 'Shawwal', 'Dhu al-Qi\'dah', 'Dhu al-Hijjah',
  ];

  String _formatGregDate(String yyyyMMdd) {
    // Convert YYYY-MM-DD to DD-MM-YYYY for display
    final parts = yyyyMMdd.split('-');
    if (parts.length != 3) return yyyyMMdd;
    return '${parts[2]}-${parts[1]}-${parts[0]}';
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(title: Text(state.t('Islamic Calendar', 'اسلامی کیلنڈر'))),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? ListView(
                children: const [Center(child: CircularProgressIndicator())],
              )
            : _error != null
                ? ListView(
                    children: [Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))],
                  )
                : _days.isEmpty
                    ? ListView(
                        children: [Center(child: Text(state.t('No calendar data', 'کیلنڈر ڈیٹا نہیں')))],
                      )
                    : _CalendarGrid(days: _days, hijriMonth: _currentHijriMonth, hijriYear: _currentHijriYear),
      ),
    );
  }
}

class _CalendarGrid extends StatelessWidget {
  final List<HijriDay> days;
  final int hijriMonth;
  final int hijriYear;
  const _CalendarGrid({required this.days, required this.hijriMonth, required this.hijriYear});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final first = days.first;
    final monthName = first.month;
    final year = first.year;
    final today = DateTime.now();
    final todayHijri = HijriDateService.getHijriDate(today);
    final todayHijriDay = todayHijri.day;

    // Hijri months are 29/30 days; find weekday offset of day 1.
    final firstGreg = DateTime.tryParse(_gregDate(first.gregorian));
    // weekday: 1=Monday ... 7=Sunday, GridView starts from Monday=0
    final startWeekday = (firstGreg?.weekday ?? 1) - 1; // 0=Mon ... 6=Sun

    // Localized weekdays
    final weekdays = state.isUrdu
        ? ['پیر', 'منگل', 'بدھ', 'جمعرات', 'جمعہ', 'ہفتہ', 'اتوار']
        : ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        HeroPanel(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Text(
                '$monthName $year',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                state.t('Hijri Calendar', 'ہجری کیلنڈر'),
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        GlassCard(
          padding: const EdgeInsets.all(14),
          child: Column(
            children: [
              Row(
                children: weekdays
                    .map((w) => Expanded(
                          child: Center(
                            child: Text(
                              w,
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primary),
                            ),
                          ),
                        ))
                    .toList(),
              ),
              const SizedBox(height: 8),
              GridView.count(
                crossAxisCount: 7,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  for (int i = 0; i < startWeekday; i++)
                    const SizedBox(height: 44),
                  ...days.map((d) {
                    final isToday = d.day == todayHijriDay.toString();
                    final greg = DateTime.tryParse(_gregDate(d.gregorian));
                    return InkWell(
                      onTap: () => _showDay(context, d, greg),
                      borderRadius: BorderRadius.circular(10),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: isToday ? AppColors.primary : null,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: isToday
                              ? [BoxShadow(color: AppColors.primary.withValues(alpha: 0.35), blurRadius: 8, offset: const Offset(0, 3))]
                              : null,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              d.day,
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: isToday ? Colors.white : null,
                                fontSize: 14,
                              ),
                            ),
                            if (greg != null)
                              Text(
                                '${greg.day}',
                                style: TextStyle(
                                  fontSize: 9,
                                  color: isToday ? Colors.white70 : AppColors.textMuted,
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.primaryPill(isDark).withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              const Icon(Icons.info_outline_rounded, color: AppColors.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  state.t(
                    'Hijri dates above, Gregorian dates below. Green highlight is today.',
                    'اوپر ہجری اور نیچے گریگورین تاریخیں۔ سبز رنگ آج کا دن ہے۔',
                  ),
                  style: const TextStyle(fontSize: 12.5, height: 1.5),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _gregDate(String yyyyMMdd) {
    // Convert YYYY-MM-DD to DD-MM-YYYY for display
    final parts = yyyyMMdd.split('-');
    if (parts.length != 3) return yyyyMMdd;
    return '${parts[2]}-${parts[1]}-${parts[0]}';
  }

  Future<void> _showDay(BuildContext context, HijriDay d, DateTime? greg) async {
    final state = context.read<AppState>();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => FutureBuilder<PrayerTimesResponse?>(
        future: greg == null
            ? null
            : ApiClient.instance.getPrayerTimesForDate(
                state.prayerCityParam, state.prayerCountryParam, greg,
                method: state.prayerMethod, school: state.asrSchool),
        builder: (ctx, snap) {
          final times = snap.data;
          final names = ['Fajr', 'Sunrise', 'Dhuhr', 'Asr', 'Maghrib', 'Isha'];
          return Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${d.day} ${d.month} ${d.year}',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
                if (greg != null)
                  Text(
                    '${greg.day}/${greg.month}/${greg.year}',
                    style: const TextStyle(color: AppColors.textMuted),
                  ),
                const SizedBox(height: 14),
                if (snap.connectionState == ConnectionState.waiting)
                  const Center(child: CircularProgressIndicator())
                else if (times == null)
                  Text(state.t('Prayer times unavailable for this date.',
                      'اس تاریخ کے لیے نماز کا وقت دستیاب نہیں۔'))
                else
                  ...names.map((n) {
                    final p = times.prayers.where((x) => x.name == n).firstOrNull;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          Expanded(child: Text(state.t(n, n))),
                          Text(p == null ? '-' : formatTime12(p.time),
                              style: const TextStyle(fontWeight: FontWeight.w700)),
                        ],
                      ),
                    );
                  }),
                const SizedBox(height: 10),
              ],
            ),
          );
        },
      ),
    );
  }
}