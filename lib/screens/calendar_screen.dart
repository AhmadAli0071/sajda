import 'package:hijri/hijri_calendar.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../services/api_client.dart';
import '../services/hijri_date_service.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../utils/time_format.dart';
import '../widgets/glass/glass_background.dart';
import '../widgets/glass/glass_panel.dart';

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
    _initToToday();
  }

  void _initToToday() {
    final hijriToday = HijriDateService.getHijriDate(DateTime.now());
    _currentHijriMonth = hijriToday.month;
    _currentHijriYear = hijriToday.year;
    _generate();
  }

  Future<void> _generate() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
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

  void _shift(int delta) {
    var m = _currentHijriMonth + delta;
    var y = _currentHijriYear;
    if (m < 1) {
      m = 12;
      y--;
    } else if (m > 12) {
      m = 1;
      y++;
    }
    setState(() {
      _currentHijriMonth = m;
      _currentHijriYear = y;
    });
    _generate();
  }

  List<HijriDay> _generateHijriMonth(int hijriYear, int hijriMonth) {
    final days = <HijriDay>[];
    final calendar = HijriCalendar();
    HijriCalendar.language = 'en';

    final daysInMonth = calendar.getDaysInMonth(hijriYear, hijriMonth);

    for (int day = 1; day <= daysInMonth; day++) {
      final gregorian = calendar.hijriToGregorian(hijriYear, hijriMonth, day);
      final shifted =
          gregorian.subtract(Duration(days: HijriDateService.adjustDays));
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
    final parts = yyyyMMdd.split('-');
    if (parts.length != 3) return yyyyMMdd;
    return '${parts[2]}-${parts[1]}-${parts[0]}';
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = AppColors.accent(isDark);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: AppColors.textMain(isDark)),
        title: Text(
          state.t('Islamic Calendar', 'اسلامی کیلنڈر'),
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.textMain(isDark),
          ),
        ),
      ),
      body: GlassBackground(
        child: RefreshIndicator(
          color: accent,
          onRefresh: _generate,
          child: _loading
              ? ListView(
                  children: const [Center(child: CircularProgressIndicator())],
                )
              : _error != null
                  ? ListView(
                      children: [
                        Center(
                          child: Text(
                            _error!,
                            style: TextStyle(color: AppColors.danger),
                          ),
                        ),
                      ],
                    )
                  : _days.isEmpty
                      ? ListView(
                          children: [
                            Center(
                              child: Text(
                                state.t('No calendar data', 'کیلنڈر ڈیٹا نہیں'),
                                style: TextStyle(color: AppColors.textSub(isDark)),
                              ),
                            ),
                          ],
                        )
                      : _CalendarGrid(
                          days: _days,
                          hijriMonth: _currentHijriMonth,
                          hijriYear: _currentHijriYear,
                          onShift: _shift,
                        ),
        ),
      ),
    );
  }
}

class _CalendarGrid extends StatelessWidget {
  final List<HijriDay> days;
  final int hijriMonth;
  final int hijriYear;
  final ValueChanged<int> onShift;

  const _CalendarGrid({
    required this.days,
    required this.hijriMonth,
    required this.hijriYear,
    required this.onShift,
  });

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = AppColors.accent(isDark);
    final textMain = AppColors.textMain(isDark);
    final textSub = AppColors.textSub(isDark);

    final first = days.first;
    final monthName = first.month;
    final year = first.year;

    final todayHijri = HijriDateService.getHijriDate(DateTime.now());
    final showToday = todayHijri.month == hijriMonth &&
        todayHijri.year == hijriYear;
    final todayDay = todayHijri.day;

    final firstGreg = DateTime.tryParse(_isoDate(first.gregorian));
    final startWeekday = (firstGreg?.weekday ?? 1) - 1;

    final weekdays = state.isUrdu
        ? ['پیر', 'منگل', 'بدھ', 'جمعرات', 'جمعہ', 'ہفتہ', 'اتوار']
        : ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        GlassPanel(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
          child: Row(
            children: [
              IconButton(
                onPressed: () => onShift(-1),
                icon: const Icon(Icons.chevron_left_rounded),
                color: accent,
              ),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      '$monthName $year',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w800,
                        color: textMain,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      state.t('Hijri Calendar', 'ہجری کیلنڈر'),
                      style: TextStyle(fontSize: 12.5, color: textSub),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => onShift(1),
                icon: const Icon(Icons.chevron_right_rounded),
                color: accent,
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        GlassPanel(
          padding: const EdgeInsets.all(14),
          child: Column(
            children: [
              Row(
                children: weekdays
                    .map((w) => Expanded(
                          child: Center(
                            child: Text(
                              w,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: accent,
                              ),
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
                    final isToday =
                        showToday && d.day == todayDay.toString();
                    final greg = DateTime.tryParse(_isoDate(d.gregorian));
                    return InkWell(
                      onTap: () => _showDay(context, d, greg),
                      borderRadius: BorderRadius.circular(12),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: isToday
                              ? accent
                              : accent.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: isToday
                              ? [
                                  BoxShadow(
                                    color: accent.withValues(alpha: 0.35),
                                    blurRadius: 10,
                                    offset: const Offset(0, 3),
                                  ),
                                ]
                              : null,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              d.day,
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: isToday ? Colors.white : textMain,
                                fontSize: 14,
                              ),
                            ),
                            if (greg != null)
                              Text(
                                '${greg.day}',
                                style: TextStyle(
                                  fontSize: 9,
                                  color: isToday
                                      ? Colors.white70
                                      : textSub,
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
        GlassPanel(
          darken: true,
          radius: 16,
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Icon(Icons.info_outline_rounded, color: accent, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  state.t(
                    'Hijri dates above, Gregorian dates below. Green highlight is today.',
                    'اوپر ہجری اور نیچے گریگورین تاریخیں۔ سبز رنگ آج کا دن ہے۔',
                  ),
                  style: TextStyle(fontSize: 12.5, height: 1.5, color: textSub),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _isoDate(String ddmmyyyy) {
    final parts = ddmmyyyy.split('-');
    if (parts.length != 3) return ddmmyyyy;
    return '${parts[2]}-${parts[1]}-${parts[0]}';
  }

  Future<void> _showDay(BuildContext context, HijriDay d, DateTime? greg) async {
    final state = context.read<AppState>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = AppColors.accent(isDark);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
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
            padding: const EdgeInsets.all(16),
            child: GlassPanel(
              radius: 24,
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${d.day} ${d.month} ${d.year}',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textMain(isDark),
                    ),
                  ),
                  if (greg != null)
                    Text(
                      '${greg.day}/${greg.month}/${greg.year}',
                      style: TextStyle(color: AppColors.textSub(isDark)),
                    ),
                  const SizedBox(height: 14),
                  if (snap.connectionState == ConnectionState.waiting)
                    Center(
                      child: CircularProgressIndicator(color: accent),
                    )
                  else if (times == null)
                    Text(
                      state.t('Prayer times unavailable for this date.',
                          'اس تاریخ کے لیے نماز کا وقت دستیاب نہیں۔'),
                      style: TextStyle(color: AppColors.textSub(isDark)),
                    )
                  else
                    ...names.map((n) {
                      final p =
                          times.prayers.where((x) => x.name == n).firstOrNull;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                state.t(n, n),
                                style: TextStyle(
                                    color: AppColors.textMain(isDark)),
                              ),
                            ),
                            Text(
                              p == null ? '-' : formatTime12(p.time),
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: AppColors.textMain(isDark),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  const SizedBox(height: 10),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
