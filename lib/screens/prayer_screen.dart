import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config.dart';
import '../data/static_data.dart';
import '../models/models.dart';
import '../services/api_client.dart';
import '../services/date_service.dart';
import '../services/prayer_notification_service.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../utils/prayer_window.dart';
import '../utils/time_format.dart';
import '../widgets/qibla_compass.dart';

class PrayerScreen extends StatefulWidget {
  const PrayerScreen({super.key});

  @override
  State<PrayerScreen> createState() => _PrayerScreenState();
}

class _PrayerScreenState extends State<PrayerScreen> {
  PrayerTimesResponse? _times;
  QiblaResponse? _qibla;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final state = context.read<AppState>();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final times = await ApiClient.instance
          .getPrayerTimesFor(state);
      QiblaResponse? qibla;
      final city = state.city;
      if (city != null) {
        try {
          final lat = state.lat ?? city.lat;
          final lng = state.lng ?? city.lng;
          qibla = await ApiClient.instance.getQibla(lat, lng);
        } catch (_) {}
      }
      if (!mounted) return;
      setState(() {
        _times = times;
        _qibla = qibla;
        _loading = false;
      });
      if (state.notificationsEnabled) {
        try {
          await PrayerNotificationService.instance
              .scheduleAll(times.prayers, isUrdu: state.isUrdu, timezone: state.locationTimezone, prayerModes: state.prayerNotificationModes, city: state.displayCityName);
        } catch (_) {}
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _pickCity() async {
    final state = context.read<AppState>();
    final selected = await showModalBottomSheet<LocationModel>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _CityPicker(initial: state.location),
    );
    if (selected != null) {
      await state.setLocation(selected);
      _load();
    }
  }

  Future<void> _useLocation() async {
    final state = context.read<AppState>();
    try {
      // Delegate to AppState.detectLocation: it handles permission, GPS,
      // reverse-geocode, timezone resolution, and persists lat/lng/location.
      // (Previously this set only the city label, leaving the coordinates
      // stale so times still came from the old location.)
      final ok = await state.detectLocation();
      if (!mounted) return;
      if (ok) {
        showAppSnack(context,
            '${state.t('Location updated', 'مقام اپ ڈیٹ ہو گیا')}: ${state.displayCityName}');
        _load();
      } else {
        showAppSnack(context, state.t('Could not get location', 'مقام حاصل نہیں کیا جا سکا'), error: true);
      }
    } catch (e) {
      if (mounted) {
        showAppSnack(context, state.t('Could not get location', 'مقام حاصل نہیں کیا جا سکا'), error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final times = _times;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(state.t('Prayer Times', 'نماز کے اوقات')),
        actions: [
          IconButton(
            onPressed: _useLocation,
            icon: const Icon(Icons.my_location_rounded),
            tooltip: state.t('Use my location', 'میرا مقام استعمال کریں'),
          ),
          IconButton(
            onPressed: _pickCity,
            icon: const Icon(Icons.location_city_rounded),
            tooltip: state.t('Change city', 'شہر تبدیل کریں'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          children: [
            // City + date header
            GlassCard(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  IconTile(icon: Icons.location_on_rounded, color: AppColors.primary, size: 48),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${state.displayCityName}, ${state.displayCountryName}',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 2),
                        Text(times?.date ?? '', style: Theme.of(context).textTheme.bodySmall),
                        if (times?.hijri.full != null && times!.hijri.full.isNotEmpty)
                          Text(times.hijri.full, style: Theme.of(context).textTheme.bodySmall),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: _pickCity,
                    icon: const Icon(Icons.keyboard_arrow_down_rounded),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            if (_loading)
              const Padding(
                padding: EdgeInsets.only(top: 80),
                child: AppLoader(),
              )
            else if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 60),
                child: ErrorView(message: _error!, onRetry: _load),
              )
            else if (times != null) ...[
              // Next prayer highlight strip
              if (_nextPrayerIndex(times) != null) ...[
                HeroPanel(
                  padding: const EdgeInsets.all(18),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          _prayerIcon(times.prayers[_nextPrayerIndex(times)!].name),
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                               _activePrayerName(times) != null
                                   ? state.t('Current Prayer', 'موجودہ نماز')
                                   : state.t('Next Prayer', 'اگلی نماز'),
                              style: const TextStyle(color: Colors.white70, fontSize: 12),
                            ),
                            Text(
                              state.isUrdu
                                  ? (AppStrings.prayerNames[times.prayers[_nextPrayerIndex(times)!].name] ??
                                      times.prayers[_nextPrayerIndex(times)!].name)
                                  : times.prayers[_nextPrayerIndex(times)!].name,
                              style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        formatTime12(times.prayers[_nextPrayerIndex(times)!].time),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
              ],

              // Prayer times list
              ...times.prayers.asMap().entries.map((entry) {
                final i = entry.key;
                final p = entry.value;
                final isNext = i == _nextPrayerIndex(times);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: GlassCard(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                    gradient: isNext
                        ? LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [AppColors.primaryPill(isDark), Color(0xFFF2FAF7)],
                          )
                        : null,
                    border: isNext
                        ? Border.all(color: AppColors.primary.withValues(alpha: 0.4))
                        : null,
                    child: Row(
                      children: [
                        IconTile(icon: _prayerIcon(p.name), color: AppColors.primary, size: 44),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                state.isUrdu
                                    ? (AppStrings.prayerNames[p.name] ?? p.name)
                                    : p.name,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              if (isNext)
                                Text(
                                   _activePrayerName(times) == p.name
                                       ? state.t('Now', 'ابھی')
                                       : state.t('Next', 'اگلی'),
                                  style: const TextStyle(
                                    color: AppColors.primary,
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Text(
                          formatTime12(p.time),
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: isNext ? AppColors.primary : Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),

              const SizedBox(height: 18),

              // Qibla compass card
              GlassCard(
                padding: const EdgeInsets.all(18),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppColors.primaryPill(isDark),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.explore_outlined, color: AppColors.primary),
                        ),
                        const SizedBox(width: 10),
                        Text(state.t('Qibla Direction', 'قبلہ کی سمت'), style: Theme.of(context).textTheme.titleMedium),
                      ],
                    ),
                    const SizedBox(height: 18),
                    if (_qibla == null)
                      Text(state.t('Select a city to see Qibla', 'قبلہ دیکھنے کے لیے شہر منتخب کریں'),
                          style: Theme.of(context).textTheme.bodySmall)
                    else ...[
                      QiblaCompass(qibla: _qibla!, isUrdu: state.isUrdu),
                      const SizedBox(height: 6),
                      Text(
                        state.t(
                          'Rotate your phone until the Kaaba marker points to Qibla',
                          'اپنے فون کو افقی رکھیں اور اس وقت تک گھمائیں جب تک کعبہ کا نشان سکرین کے اوپر لکیر کے ساتھ ہو نہ ہو جائے۔',
                        ),
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ],
                ),
              ),
            ],
            ],
          ),
        ),
      );

  }
  int? _nextPrayerIndex(PrayerTimesResponse times) {
    if (times.prayers.isEmpty) return null;
    // Same rules as the home card: highlight the prayer whose OWN window
    // is still open (Fajr only until sunrise); in the gaps highlight the
    // next upcoming prayer instead. "now" is the location's wall-clock.
    final w = computePrayerWindow(
        times.prayers, dateService.nowInTimezone(context.read<AppState>().locationTimezone));
    if (w == null) return null;
    final focus = w.current ?? w.next;
    final i = times.prayers.indexWhere((p) => p.name == focus.name);
    return i >= 0 ? i : 0;
  }

  String? _activePrayerName(PrayerTimesResponse times) =>
      computePrayerWindow(
              times.prayers, dateService.nowInTimezone(context.read<AppState>().locationTimezone))
          ?.current
          ?.name;

  IconData _prayerIcon(String name) {
    switch (name) {
      case 'Fajr':
        return Icons.wb_twilight_rounded;
      case 'Sunrise':
        return Icons.wb_sunny_outlined;
      case 'Dhuhr':
        return Icons.light_mode_outlined;
      case 'Asr':
        return Icons.wb_cloudy_outlined;
      case 'Maghrib':
        return Icons.nights_stay_outlined;
      case 'Isha':
        return Icons.dark_mode_outlined;
      default:
        return Icons.schedule_rounded;
    }
  }
}

class _CityPicker extends StatefulWidget {
  final LocationModel? initial;
  const _CityPicker({this.initial});

  @override
  State<_CityPicker> createState() => _CityPickerState();
}

class _CityPickerState extends State<_CityPicker> {
  String _query = '';
  List<LocationModel> _results = [];
  bool _searching = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _results = _localResults('');
  }

  List<LocationModel> _localResults(String q) {
    final ql = q.toLowerCase().trim();
    final normalized = _normalizeSearch(ql);
    return citiesDb
        .where((c) {
          final nameMatch = c.name.toLowerCase().contains(ql) ||
              c.name.toLowerCase().contains(normalized);
          final aliasMatch = c.aliases.any((a) =>
              a.toLowerCase().contains(ql) ||
              a.toLowerCase().contains(normalized));
          final countryMatch = c.country.toLowerCase().contains(ql);
          return nameMatch || aliasMatch || countryMatch;
        })
        .map((c) => LocationModel(
              id: 'local_${c.name.toLowerCase().replaceAll(" ", "_")}',
              city: c.name,
              state: '',
              country: c.country,
              countryCode: '',
              latitude: c.lat,
              longitude: c.lng,
              timezone: c.timezone,
              source: 'MANUAL',
              isManual: true,
            ))
        .toList();
  }

  String _normalizeSearch(String input) {
    return input
        .replaceAll('کراچی', 'karachi')
        .replaceAll('لاہور', 'lahore')
        .replaceAll('رحیم', 'rahim')
        .replaceAll('بہاول', 'bahawal')
        .replaceAll('پشاور', 'peshawar')
        .replaceAll('ملتان', 'multan')
        .replaceAll('فیصل', 'faisal')
        .replaceAll('کوئٹہ', 'quetta')
        .replaceAll('گوجرانوالہ', 'gujranwala')
        .replaceAll('سیالکوٹ', 'sialkot')
        .replaceAll('سرگودھا', 'sargodha')
        .replaceAll('اسلام آباد', 'islamabad')
        .replaceAll(RegExp(r'[^\w\s]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  Future<void> _onQueryChanged(String q) async {
    if (q.length < 2) {
      setState(() {
        _results = _localResults(q);
      });
      return;
    }
    _timer?.cancel();
    setState(() => _searching = true);
    _timer = Timer(const Duration(milliseconds: 700), () async {
      final state = context.read<AppState>();
      final global = await state.searchLocation(q);
      final local = _localResults(q);
      final combined = <LocationModel>[];
      final seen = <String>{};
      for (final l in [...global, ...local]) {
        final key = '${l.city},${l.country}'.toLowerCase();
        if (!seen.contains(key)) {
          seen.add(key);
          combined.add(l);
        }
      }
      if (mounted) {
        setState(() {
          _results = combined;
          _searching = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.8,
      maxChildSize: 0.95,
      builder: (ctx, scrollController) => Column(
        children: [
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              autofocus: false,
              onChanged: _onQueryChanged,
              decoration: InputDecoration(
                hintText: state.t('Search city or country worldwide...', 'دنیا بھر میں شہر یا ملک تلاش کریں...'),
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear_rounded),
                        onPressed: () {
                          setState(() {
                            _query = '';
                            _results = _localResults('');
                          });
                        },
                      ),
              ),
              onTap: () {},
            ),
          ),
          Expanded(
            child: _searching
                ? const Center(child: CircularProgressIndicator())
                : ListView.separated(
                    controller: scrollController,
                    itemCount: _results.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (ctx, i) {
                      final c = _results[i];
                      final selected = widget.initial?.id == c.id;
                      return ListTile(
                        leading: Icon(
                          Icons.location_on_outlined,
                          color: selected ? AppColors.primary : Colors.grey,
                        ),
                        title: Text(c.city, style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text(
                          c.state.isEmpty ? c.country : '${c.state}, ${c.country}',
                        ),
                        trailing: selected
                            ? const Icon(Icons.check_circle_rounded, color: AppColors.primary)
                            : const Icon(Icons.chevron_right_rounded),
                        onTap: () => Navigator.of(ctx).pop(c),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
