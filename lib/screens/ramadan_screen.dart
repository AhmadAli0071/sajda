import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../services/api_client.dart';
import '../services/hijri_date_service.dart';
import '../services/local_prayer_times_service.dart';
import '../services/prayer_notification_service.dart';
import '../services/ramadan_service.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';

/// F10 — Ramadan Mode: Suhoor/Iftar countdown, 30-day calendar, reminders.
class RamadanScreen extends StatefulWidget {
  const RamadanScreen({super.key});

  @override
  State<RamadanScreen> createState() => _RamadanScreenState();
}

class _RamadanScreenState extends State<RamadanScreen> {
  Timer? _ticker;
  DateTime _now = DateTime.now();
  PrayerTimesResponse? _today;
  PrayerTimesResponse? _tomorrow;
  List<_RamadanDay> _calendar = const [];
  DateTime? _nextRamadan;
  bool _loading = true;
  bool _toggling = false;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _now = DateTime.now());
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final app = context.read<AppState>();
    final now = DateTime.now();
    PrayerTimesResponse? today;
    final tomorrowDate = now.add(const Duration(days: 1));
    PrayerTimesResponse? tomorrow;

    if (app.lat != null && app.lng != null) {
      today = LocalPrayerTimesService.calculate(
        lat: app.lat!,
        lng: app.lng!,
        timezone: app.locationTimezone,
        date: now,
        method: app.prayerMethod,
        school: app.asrSchool,
      );
      tomorrow = LocalPrayerTimesService.calculate(
        lat: app.lat!,
        lng: app.lng!,
        timezone: app.locationTimezone,
        date: tomorrowDate,
        method: app.prayerMethod,
        school: app.asrSchool,
      );
    }
    if (today == null) {
      try {
        today = await ApiClient.instance.getPrayerTimesFor(app);
      } catch (_) {}
    }
    final calendar = _buildCalendar(app, now);
    final nextRamadan = _findNextRamadan(now);
    if (!mounted) return;
    setState(() {
      _today = today;
      _tomorrow = tomorrow;
      _calendar = calendar;
      _nextRamadan = nextRamadan;
      _loading = false;
    });
    if (RamadanService.isRamadan() && app.ramadanRemindersEnabled) {
      _schedule(app);
    }
  }

  Future<void> _schedule(AppState app) async {
    await RamadanService.scheduleIftarReminders(
      lat: app.lat ?? 0,
      lng: app.lng ?? 0,
      timezone: app.locationTimezone,
      method: app.prayerMethod,
      school: app.asrSchool,
      city: app.displayCityName,
      isUrdu: app.isUrdu,
    );
  }

  DateTime? _findNextRamadan(DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    for (var i = 0; i < 420; i++) {
      final date = today.add(Duration(days: i));
      final hijri = HijriDateService.convertPlain(date);
      if (hijri.month == 9 && hijri.day == 1) return date;
    }
    return null;
  }

  List<_RamadanDay> _buildCalendar(AppState app, DateTime now) {
    final hijri = HijriDateService.convertPlain(now);
    if (hijri.month != 9) return const [];
    final first = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: hijri.day - 1));
    final list = <_RamadanDay>[];
    for (var i = 0; i < 30; i++) {
      final date = first.add(Duration(days: i));
      String? maghrib;
      if (app.lat != null && app.lng != null) {
        final times = LocalPrayerTimesService.calculate(
          lat: app.lat!,
          lng: app.lng!,
          timezone: app.locationTimezone,
          date: date,
          method: app.prayerMethod,
          school: app.asrSchool,
        );
        if (times != null) {
          for (final p in times.prayers) {
            if (p.name == 'Maghrib') {
              maghrib = p.time;
              break;
            }
          }
        }
      }
      list.add(_RamadanDay(
        day: i + 1,
        date: date,
        maghrib: maghrib,
      ));
    }
    return list;
  }

  String? _prayerTime(PrayerTimesResponse? times, String name) {
    if (times == null) return null;
    for (final p in times.prayers) {
      if (p.name == name) return p.time;
    }
    return null;
  }

  DateTime? _nextOccurrence(String name) {
    final todayTime = _prayerTime(_today, name);
    final tomorrowTime = _prayerTime(_tomorrow, name);
    if (todayTime != null) {
      final t = RamadanService.atTime(_now, todayTime);
      if (t != null && t.isAfter(_now)) return t;
    }
    if (tomorrowTime != null) {
      return RamadanService.atTime(
        _now.add(const Duration(days: 1)),
        tomorrowTime,
      );
    }
    return null;
  }

  Future<void> _toggleReminders(AppState app, bool value) async {
    if (_toggling) return;
    setState(() => _toggling = true);
    try {
      if (value) {
        await PrayerNotificationService.instance
            .requestNotificationPermission();
      }
      await app.setRamadanRemindersEnabled(value);
      if (value) {
        await _schedule(app);
      } else {
        await RamadanService.cancelAll();
      }
    } finally {
      if (mounted) setState(() => _toggling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isRamadan = RamadanService.isRamadan(_now);

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        title: Text(app.t('Ramadan Mode', 'رمضان موڈ')),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                if (isRamadan)
                  _CountdownHero(
                    app: app,
                    now: _now,
                    day: RamadanService.ramadanDay(_now),
                    suhoor: _nextOccurrence('Fajr'),
                    iftar: _nextOccurrence('Maghrib'),
                  )
                else
                  _BeforeRamadanCard(
                    app: app,
                    nextRamadan: _nextRamadan,
                    now: _now,
                  ),
                const SizedBox(height: 16),
                if (isRamadan) ...[
                  Row(
                    children: [
                      Expanded(
                        child: _TimeCard(
                          icon: Icons.nights_stay_rounded,
                          title: app.t('Suhoor ends', 'سحری ختم'),
                          time: _prayerTime(_today, 'Fajr') ?? '--:--',
                          isDark: isDark,
                          color: const Color(0xFF5D6D7E),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _TimeCard(
                          icon: Icons.wb_twilight_rounded,
                          title: app.t('Iftar', 'افطار'),
                          time: _prayerTime(_today, 'Maghrib') ?? '--:--',
                          isDark: isDark,
                          color: const Color(0xFFB9770E),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
                _ReminderTile(
                  app: app,
                  value: app.ramadanRemindersEnabled,
                  busy: _toggling,
                  onChanged: (v) => _toggleReminders(app, v),
                  isDark: isDark,
                ),
                if (isRamadan) ...[
                  const SizedBox(height: 20),
                  Text(
                    app.t('Ramadan calendar', 'رمضان کیلنڈر'),
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    app.t(
                      'Iftar times are calculated for ${app.displayCityName}.',
                      'افطار کے اوقات ${app.displayCityName} کے لیے شمار کیے گئے ہیں۔',
                    ),
                    style: TextStyle(
                      fontSize: 11.5,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkSurface : AppColors.lightCard,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isDark
                            ? AppColors.darkSurfaceAlt
                            : AppColors.lightBorder,
                      ),
                    ),
                    child: Column(
                      children: [
                        for (var i = 0; i < _calendar.length; i++) ...[
                          _CalendarRow(
                            app: app,
                            item: _calendar[i],
                            today: RamadanService.ramadanDay(_now),
                            isDark: isDark,
                          ),
                          if (i != _calendar.length - 1)
                            Divider(
                              height: 1,
                              indent: 16,
                              endIndent: 16,
                              color: isDark
                                  ? AppColors.darkSurfaceAlt
                                  : AppColors.lightBorder,
                            ),
                        ],
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurface : AppColors.lightCard,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color:
                          isDark ? AppColors.darkSurfaceAlt : AppColors.lightBorder,
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.info_outline_rounded,
                          color: AppColors.primary, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          app.t(
                            'Dates follow the Umm al-Qura calendar with your moon-sighting adjustment. Iftar reminders use the prayer times calculated on your device.',
                            'تاریخیں ام القریٰ کیلنڈر اور آپ کی رویت ہلال ایڈجسٹمنٹ کے مطابق ہیں۔ افطار کے یاد دہانیاں آپ کے فون پر شمار کیے گئے اوقات پر ہیں۔',
                          ),
                          style: TextStyle(
                            fontSize: 11.5,
                            height: 1.45,
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

class _RamadanDay {
  final int day;
  final DateTime date;
  final String? maghrib;

  const _RamadanDay({
    required this.day,
    required this.date,
    this.maghrib,
  });
}

class _CountdownHero extends StatelessWidget {
  final AppState app;
  final DateTime now;
  final int day;
  final DateTime? suhoor;
  final DateTime? iftar;

  const _CountdownHero({
    required this.app,
    required this.now,
    required this.day,
    required this.suhoor,
    required this.iftar,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: const LinearGradient(
          colors: [Color(0xFF1A1A3E), Color(0xFF4A3B7A), Color(0xFF7D3C98)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7D3C98).withValues(alpha: 0.3),
            blurRadius: 26,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.nightlight_round, color: Color(0xFFFFE082)),
              const SizedBox(width: 8),
              Text(
                app.t('RAMADAN MUBARAK', 'رمضان مبارک'),
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: 11,
                  letterSpacing: 2,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Text(
                  app.t('Day $day', 'دن $day'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          _countdown(
            app.t('Suhoor ends in', 'سحری ختم ہونے میں'),
            suhoor == null ? '--:--:--' : _remaining(suhoor!),
            Icons.nights_stay_rounded,
          ),
          const SizedBox(height: 16),
          Container(height: 1, color: Colors.white.withValues(alpha: 0.12)),
          const SizedBox(height: 16),
          _countdown(
            app.t('Iftar in', 'افطار میں'),
            iftar == null ? '--:--:--' : _remaining(iftar!),
            Icons.wb_twilight_rounded,
            highlight: true,
          ),
        ],
      ),
    );
  }

  Widget _countdown(
    String label,
    String value,
    IconData icon, {
    bool highlight = false,
  }) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: highlight
                ? const Color(0xFFFFE082).withValues(alpha: 0.18)
                : Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            color: highlight ? const Color(0xFFFFE082) : Colors.white70,
            size: 21,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.75),
              fontSize: 13,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: highlight ? const Color(0xFFFFE082) : Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w900,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }

  String _remaining(DateTime target) {
    var diff = target.difference(now);
    if (diff.isNegative) diff = Duration.zero;
    final h = diff.inHours.toString().padLeft(2, '0');
    final m = (diff.inMinutes % 60).toString().padLeft(2, '0');
    final s = (diff.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }
}

class _BeforeRamadanCard extends StatelessWidget {
  final AppState app;
  final DateTime? nextRamadan;
  final DateTime now;

  const _BeforeRamadanCard({
    required this.app,
    required this.nextRamadan,
    required this.now,
  });

  @override
  Widget build(BuildContext context) {
    final days = nextRamadan == null
        ? null
        : DateTime(nextRamadan!.year, nextRamadan!.month, nextRamadan!.day)
            .difference(DateTime(now.year, now.month, now.day))
            .inDays;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [Color(0xFF1A1A3E), Color(0xFF4A3B7A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        children: [
          const Icon(Icons.nightlight_round,
              color: Color(0xFFFFE082), size: 48),
          const SizedBox(height: 14),
          Text(
            app.t('Ramadan is coming', 'رمضان آرہا ہے'),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            days == null
                ? app.t(
                    'Ramadan mode will activate automatically.',
                    'رمضان موڈ خود بخود فعال ہو جائے گا۔',
                  )
                : app.t(
                    '${days > 1 ? '$days days' : 'About a month'} until the first fast.',
                    'پہلے روزے میں ${days > 1 ? '$days دن' : 'تقریباً ایک ماہ'} باقی ہیں۔',
                  ),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.78),
              fontSize: 13,
              height: 1.5,
            ),
          ),
          if (nextRamadan != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(30),
              ),
              child: Text(
                '${nextRamadan!.day}/${nextRamadan!.month}/${nextRamadan!.year}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TimeCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String time;
  final Color color;
  final bool isDark;

  const _TimeCard({
    required this.icon,
    required this.title,
    required this.time,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? AppColors.darkSurfaceAlt : AppColors.lightBorder,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              Text(
                time,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ReminderTile extends StatelessWidget {
  final AppState app;
  final bool value;
  final bool busy;
  final ValueChanged<bool> onChanged;
  final bool isDark;

  const _ReminderTile({
    required this.app,
    required this.value,
    required this.busy,
    required this.onChanged,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? AppColors.darkSurfaceAlt : AppColors.lightBorder,
        ),
      ),
      child: SwitchListTile(
        value: value,
        onChanged: busy ? null : onChanged,
        activeThumbColor: AppColors.primary,
        secondary: const Icon(Icons.notifications_active_rounded,
            color: AppColors.primary),
        title: Text(
          app.t('Iftar reminders', 'افطار کی یاد دہانی'),
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          app.t(
            'A notification at Maghrib for the next 30 days',
            'اگلے 30 دن مغرب پر اطلاع',
          ),
          style: const TextStyle(fontSize: 11.5),
        ),
      ),
    );
  }
}

class _CalendarRow extends StatelessWidget {
  final AppState app;
  final _RamadanDay item;
  final int today;
  final bool isDark;

  const _CalendarRow({
    required this.app,
    required this.item,
    required this.today,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final isToday = item.day == today;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isToday
                  ? AppColors.primary
                  : AppColors.primary.withValues(alpha: 0.08),
            ),
            child: Text(
              '${item.day}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: isToday ? Colors.white : AppColors.primaryDark,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _dateLabel(item.date),
              style: TextStyle(
                fontSize: 13,
                fontWeight: isToday ? FontWeight.w800 : FontWeight.w500,
                color: isToday
                    ? AppColors.primary
                    : Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
          if (isToday)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                app.t('TODAY', 'آج'),
                style: const TextStyle(
                  fontSize: 7.5,
                  letterSpacing: 0.8,
                  fontWeight: FontWeight.w900,
                  color: AppColors.primaryDark,
                ),
              ),
            ),
          Text(
            item.maghrib ?? '--:--',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }

  String _dateLabel(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
}
