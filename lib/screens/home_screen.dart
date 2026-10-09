import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:quran/quran.dart' as q;

import '../config.dart';
import '../models/models.dart';
import '../services/allah_names.dart';
import '../services/api_client.dart';
import '../services/quran_service.dart';
import '../state/app_state.dart';
import '../state/streak_state.dart';
import '../theme/app_theme.dart';
import '../utils/time_format.dart';
import '../utils/prayer_window.dart';
import '../widgets/language_switcher.dart';
import 'adhkar_screen.dart';
import 'main_shell.dart';
import 'map_location_picker_screen.dart';
import 'prayer_screen.dart';
import 'qibla_screen.dart';
import 'quran_screen.dart';
import 'solo_dashboard_screen.dart';
import 'streak_home_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  _PrayerClock? _clock;
  SearchResult? _ayah;
  Map<String, String>? _ayahTr;
  List<IslamicEvent> _events = [];
  bool _loading = true;
  String? _error;
  Timer? _timer;
  int _nameIndex = -1;

  @override
  void initState() {
    super.initState();
    _load();
    unawaited(_pickName());
    _timer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _load(quiet: true),
    );
  }

  Future<void> _pickName() async {
    final idx = await AllahNames.pickFreshIndex();
    if (mounted) setState(() => _nameIndex = idx);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load({bool quiet = false}) async {
    if (!quiet) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    final state = context.read<AppState>();
    try {
      final times = await ApiClient.instance.getPrayerTimesFor(state);
      if (!mounted) return;
      if (quiet) {
        // Cheap tick: prayer times are served from the client cache, the
        // event/ayah fetches are skipped, and we only rebuild when the
        // countdown minute or the hero prayer actually changed.
        final next = _computeClock(times);
        if (next == null) return;
        final heroChanged = next.current?.name != _clock?.current?.name ||
            next.next.name != _clock?.next.name ||
            next.nextIsTomorrow != _clock?.nextIsTomorrow;
        final minuteChanged =
            next.endsInSec ~/ 60 != (_clock?.endsInSec ?? 0) ~/ 60;
        if (heroChanged || minuteChanged) {
          setState(() => _clock = next);
        }
        return;
      }
      List<IslamicEvent> events = const [];
      try {
        events = await ApiClient.instance.getTodayEvents();
      } catch (_) {}
      setState(() {
        _clock = _computeClock(times);
        _events = events;
        _loading = false;
        _error = null;
      });
      QuranService.instance.dailyAyah().then((ayah) {
        if (!mounted) return;
        setState(() => _ayah = ayah);
        if (ayah == null) return;
        // Translations load separately (backend + day cache) so the Arabic
        // text is never blocked by a network round-trip.
        QuranService.instance
            .dailyAyahTranslations(ayah.surah, ayah.ayah)
            .then((tr) {
          if (!mounted || tr == null) return;
          setState(() => _ayahTr = tr);
        });
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  String _gregorianDate(String lang) {
    final now = DateTime.now();
    try {
      return DateFormat('EEEE, d MMMM y', lang).format(now);
    } catch (_) {
      return DateFormat('EEEE, d MMMM y').format(now);
    }
  }

  String _fmtCountdown(AppState state, int seconds) {
    if (seconds <= 0) return '--';
    final h = seconds ~/ 3600;
    final m = ((seconds % 3600) ~/ 60);
    // Long windows show hours only so the countdown never ellipsizes in
    // the hero row next to the upcoming-prayer chip.
    if (h > 0) {
      return state.isUrdu ? '$h گھنٹے' : '${h}h';
    }
    final mm = m == 0 ? 1 : m;
    return state.isUrdu ? '$mm منٹ' : '${mm}m';
  }

  /// Builds the hero card state from the shared per-prayer window rules:
  /// Fajr ends at SUNRISE, Zuhr at Asr, Asr at Maghrib, Maghrib at Isha,
  /// Isha at tomorrow's Fajr. While a window is open that prayer is the
  /// hero with "Ends in"; in the gaps (e.g. after sunrise) the hero flips
  /// to the NEXT prayer with a "Starts in" countdown.
  _PrayerClock? _computeClock(PrayerTimesResponse times) {
    final now = DateTime.now();
    final w = computePrayerWindow(times.prayers, now);
    if (w == null) return null;

    if (w.current != null && w.currentStart != null && w.currentEnd != null) {
      final total = w.currentEnd!.difference(w.currentStart!).inSeconds;
      final elapsed = now.difference(w.currentStart!).inSeconds;
      return _PrayerClock(
        current: w.current,
        next: w.next,
        nextIsTomorrow: w.nextIsTomorrow,
        endsInSec: w.currentEnd!.difference(now).inSeconds,
        progress: total > 0 ? (elapsed / total).clamp(0.0, 1.0) : 0.0,
      );
    }
    return _PrayerClock(
      current: null,
      next: w.next,
      nextIsTomorrow: w.nextIsTomorrow,
      endsInSec: w.nextStart.difference(now).inSeconds,
      progress: 0,
    );
  }

  Future<void> _showQibla() async {
    final state = context.read<AppState>();
    final city = state.city;
    if (city == null) {
      showAppSnack(
        context,
        state.t('Select a city first', 'پہلے شہر منتخب کریں'),
        error: true,
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const QiblaScreen()),
    );
  }

  Future<void> _showAllFeatures() async {
    final state = context.read<AppState>();
    final dark = Theme.of(context).brightness == Brightness.dark;
    final items = moreItems(context);
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black54,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.78,
        minChildSize: 0.4,
        maxChildSize: 0.96,
        expand: false,
        builder: (sheetCtx, scrollController) => Container(
          decoration: BoxDecoration(
            color: dark ? AppColors.darkSurface : AppColors.lightCard,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 46,
                height: 5,
                decoration: BoxDecoration(
                  color: AppColors.lightBorder,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: AppColors.gradientTeal,
                      ),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: const Icon(
                      Icons.grid_view_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        state.t('All Features', 'تمام خصوصیات'),
                        style: TextStyle(
                          color: Theme.of(context).textTheme.titleLarge?.color,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        state.t(
                          'Explore everything in one place',
                          'ایک جگہ سب کچھ دریافت کریں',
                        ),
                        style: TextStyle(
                          color: Theme.of(context).textTheme.bodySmall?.color,
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Expanded(
                child: GridView.builder(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(18, 4, 18, 24),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.35,
                  ),
                  itemCount: items.length,
                  itemBuilder: (ctx, i) {
                    final item = items[i];
                    return PastelCard(
                      title: state.isUrdu ? item.titleUr : item.title,
                      subtitle: '',
                      icon: item.icon,
                      color: item.color,
                      onTap: () {
                        Navigator.of(ctx).pop();
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => item.screen),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final dark = Theme.of(context).brightness == Brightness.dark;
    final lang = state.language;
    final contentLang = state.contentLang;
    final clock = _clock;
    final hero = clock?.current ?? clock?.next;
    final currentName = clock == null
        ? state.t('Loading...', 'لوڈ ہو رہا ہے...')
        : (lang == 'ur'
            ? (AppStrings.prayerNames[hero!.name] ?? hero.name)
            : hero!.name);

    return Scaffold(
      backgroundColor:
          dark ? AppColors.darkBackground : AppColors.lightBackground,
      body: RefreshIndicator(
        onRefresh: _load,
        color: AppColors.primary,
        backgroundColor: dark ? AppColors.darkSurface : AppColors.lightCard,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // ── Header ──
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).viewPadding.top + 8, 20, 0),
                child: Row(
                  children: [
                    // Logo
                    ClipRRect(
                      borderRadius: BorderRadius.circular(11),
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: AppColors.primaryPill(dark),
                        ),
                        child: Image.asset(
                          'assets/app_logo.png',
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => const Icon(
                            Icons.mosque_rounded,
                            color: AppColors.primary,
                            size: 24,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Greeting
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _nameIndex >= 0
                                ? kAllahNames[_nameIndex].arabic
                                : state.t('Good Morning', 'صبح بخیر'),
                            style: TextStyle(
                              color: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.color,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _nameIndex >= 0
                                ? '${kAllahNames[_nameIndex].urdu} • ${state.displayCityName}'
                                : '${state.displayCityName}, ${state.displayCountryName}',
                            style: TextStyle(
                              color: Theme.of(context).textTheme.bodySmall?.color,
                              fontSize: 12,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    // Prayer times button
                    GestureDetector(
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const PrayerScreen(),
                        ),
                      ),
                      child: Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: AppColors.primaryPill(dark),
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: const Icon(
                          Icons.schedule_rounded,
                          color: AppColors.primary,
                          size: 21,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Hero Prayer Card ──
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: HeroPanel(
                  withPattern: true,
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Date + City
                      Row(
                        children: [
                          Icon(
                            Icons.calendar_month_outlined,
                            color: Colors.white.withValues(alpha: 0.7),
                            size: 15,
                          ),
                          const SizedBox(width: 7),
                          Expanded(
                            child: Text(
                              state.isUrdu
                                  ? state.todayHijriDate.fullWithWeekdayAr
                                  : state.todayHijriDate.fullWithWeekday,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.8),
                                fontSize: 12.5,
                              ),
                            ),
                          ),
                          // Tappable city chip: opens the map picker so the
                          // user can pin a location when GPS isn't accurate.
                          // Auto-GPS refresh (on app start / travel) still
                          // updates this label automatically via AppState.
                          GestureDetector(
                            onTap: () {
                              final loc = state.location;
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => MapLocationPickerScreen(
                                    initialPosition: (loc != null &&
                                            (loc.latitude != 0 ||
                                                loc.longitude != 0))
                                        ? LatLng(loc.latitude, loc.longitude)
                                        : null,
                                  ),
                                ),
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(30),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.location_on_rounded,
                                    color: Colors.white,
                                    size: 12,
                                  ),
                                  const SizedBox(width: 4),
                                  ConstrainedBox(
                                    constraints: const BoxConstraints(
                                      maxWidth: 110,
                                    ),
                                    child: Text(
                                      state.displayCityName,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _gregorianDate(state.language),
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6),
                          fontSize: 11.5,
                        ),
                      ),
                      const SizedBox(height: 20),
                      if (clock == null) ...[
                        Text(
                          state.t('Loading...', 'لوڈ ہو رہا ہے...'),
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ] else ...[
                        // ACTIVE window: hero = the current prayer until its
                        // OWN end time (Fajr ends at sunrise, not at Zuhr!).
                        // In the gaps (after sunrise, before the next
                        // prayer) the hero flips to the NEXT prayer.
                        Text(
                          clock.current != null
                              ? state.t('CURRENT PRAYER', 'موجودہ نماز')
                              : state.t('NEXT PRAYER', 'اگلی نماز'),
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.6),
                            fontSize: 11,
                            letterSpacing: 1.8,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Expanded(
                              child: Text(
                                currentName,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 32,
                                  fontWeight: FontWeight.w900,
                                  height: 1.1,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                formatTime12((clock.current ?? clock.next).time),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (clock.current != null) ...[
                          const SizedBox(height: 16),
                          // Elapsed fraction of the current prayer window.
                          ClipRRect(
                            borderRadius: BorderRadius.circular(99),
                            child: SizedBox(
                              height: 6,
                              child: Stack(
                                children: [
                                  Container(
                                    color: Colors.white.withValues(alpha: 0.18),
                                  ),
                                  FractionallySizedBox(
                                    widthFactor: clock.progress,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            Colors.white.withValues(alpha: 0.7),
                                            Colors.white,
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),
                        // Ends-in (open window) or starts-in (waiting for
                        // the next prayer) + the upcoming prayer chip.
                        // The countdown is inflexible so it always renders
                        // in full; the chip is the flexible part and scales
                        // down as a whole (never clipped) when space is
                        // tight — this also keeps the 'Tomorrow' tag
                        // visible on the next-Fajr chip during the night.
                        Row(
                          children: [
                            Icon(
                              clock.current != null
                                  ? Icons.hourglass_bottom_rounded
                                  : Icons.schedule_rounded,
                              color: Colors.white.withValues(alpha: 0.75),
                              size: 15,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              clock.current != null
                                  ? '${state.t('Ends in', 'باقی')} ${_fmtCountdown(state, clock.endsInSec)}'
                                  : '${state.t('Starts in', 'شروع ہونے میں')} ${_fmtCountdown(state, clock.endsInSec)}',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.92),
                                fontSize: 13.5,
                                fontWeight: FontWeight.w800,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(width: 10),
                            if (clock.current != null)
                              Expanded(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerRight,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 5,
                                    ),
                                    decoration: BoxDecoration(
                                      color:
                                          Colors.black.withValues(alpha: 0.18),
                                      borderRadius: BorderRadius.circular(30),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          '${state.t('Next', 'اگلی')}: ',
                                          style: TextStyle(
                                            color: Colors.white
                                                .withValues(alpha: 0.85),
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        Text(
                                          lang == 'ur'
                                              ? (AppStrings.prayerNames[
                                                      clock.next.name] ??
                                                  clock.next.name)
                                              : clock.next.name,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w800,
                                          ),
                                          maxLines: 1,
                                        ),
                                        Text(
                                          ' · ${formatTime12(clock.next.time)}',
                                          style: TextStyle(
                                            color: Colors.white
                                                .withValues(alpha: 0.85),
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w700,
                                          ),
                                          maxLines: 1,
                                        ),
                                        if (clock.nextIsTomorrow) ...[
                                          const SizedBox(width: 5),
                                          Text(
                                            state.t('Tomorrow', 'کل'),
                                            style: TextStyle(
                                              color: Colors.white
                                                  .withValues(alpha: 0.75),
                                              fontSize: 10.5,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ),
                              )
                            else if (clock.nextIsTomorrow)
                              Text(
                                state.t('Tomorrow', 'کل'),
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.75),
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),

            // ── Your Streak ──
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: _HomeStreakCard(),
              ),
            ),

            // ── Quick Access ──
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
                child: SectionHeader(
                  title: state.t('Quick Access', 'فوری رسائی'),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
              sliver: SliverGrid.count(
                crossAxisCount: 2,
                mainAxisSpacing: 14,
                crossAxisSpacing: 14,
                childAspectRatio: 0.95,
                children: [
                  PastelCard(
                    title: state.t('Al-Quran', 'قرآن مجید'),
                    subtitle: state.t('Read the Holy Quran', 'قرآن پاک پڑھیں'),
                    icon: Icons.menu_book_rounded,
                    color: AppColors.primary,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const QuranScreen()),
                    ),
                  ),
                  PastelCard(
                    title: state.t('Prayer Times', 'نماز کے اوقات'),
                    subtitle:
                        state.t('Timings & Qibla', 'اوقات اور قبلہ'),
                    icon: Icons.schedule_rounded,
                    color: AppColors.pastelBlue,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const PrayerScreen()),
                    ),
                  ),
                  PastelCard(
                    title: state.t('Adhkar', 'اذکار'),
                    subtitle: state.t(
                      'Morning & Evening Azkar',
                      'صبح و شام کے اذکار',
                    ),
                    icon: Icons.volunteer_activism_outlined,
                    color: AppColors.pastelPurple,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const AdhkarScreen()),
                    ),
                  ),
                  PastelCard(
                    title: state.t('Qibla', 'قبلہ'),
                    subtitle: state.t(
                      'Direction of Kaaba',
                      'کعبہ کی سمت',
                    ),
                    icon: Icons.explore_rounded,
                    color: AppColors.pastelOrange,
                    onTap: _showQibla,
                  ),
                ],
              ),
            ),

            // ── View All Features ──
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: GestureDetector(
                  onTap: _showAllFeatures,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: dark ? AppColors.darkSurface : AppColors.lightCard,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: dark
                            ? AppColors.darkSurfaceAlt
                            : AppColors.lightBorder,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: AppColors.primaryPill(dark),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.grid_view_rounded,
                            color: AppColors.primary,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            state.t('View All Features', 'تمام خصوصیات دیکھیں'),
                            style: TextStyle(
                              color: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.color,
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        Icon(
                          Icons.arrow_forward_rounded,
                          color: Theme.of(context).textTheme.bodySmall?.color,
                          size: 22,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // ── Ayah of the Day ──
            if (_ayah != null) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
                  child: SectionHeader(
                    title: state.t('Ayah of the Day', 'آج کی آیت'),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                sliver: SliverToBoxAdapter(
                  child: GlassCard(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ContentLanguageChips(
                          selected: contentLang,
                          onChanged: (code) =>
                              context.read<AppState>().setContentLanguage(code),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          _ayah!.arabic,
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            color:
                                Theme.of(context).textTheme.bodyLarge?.color,
                            fontSize: 19,
                            height: 2,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'serif',
                          ),
                        ),
                        if (contentLang != 'ar' &&
                            (_ayahTr?[contentLang]?.isNotEmpty ?? false)) ...[
                          const SizedBox(height: 12),
                          Text(
                            _ayahTr![contentLang]!,
                            textAlign: contentLang == 'ur'
                                ? TextAlign.right
                                : TextAlign.left,
                            style: TextStyle(
                              color: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.color,
                              fontSize: 14.5,
                              height: 1.7,
                            ),
                          ),
                        ],
                        const SizedBox(height: 10),
                        Text(
                          state.t(
                            '${q.getSurahNameEnglish(_ayah!.surah)} • Ayah ${_ayah!.ayah}',
                            '${q.getSurahNameArabic(_ayah!.surah)} • آیت ${_ayah!.ayah}',
                          ),
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],

            // ── Today's Events ──
            if (_events.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
                  child: SectionHeader(
                    title: state.t(
                      "Today's Islamic Events",
                      'آج کے اسلامی واقعات',
                    ),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                sliver: SliverList.separated(
                  itemCount: _events.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (ctx, i) {
                    final e = _events[i];
                    return GlassCard(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: AppColors.primaryPill(dark),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.event_available_rounded,
                              color: AppColors.primary,
                              size: 21,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  e.title(lang),
                                  style: TextStyle(
                                    color: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.color,
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                if (e.description(lang).isNotEmpty)
                                  Text(
                                    e.description(lang),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.color,
                                      fontSize: 12.5,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],

            // ── Loading / Error ──
            if (_loading)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.only(top: 60),
                  child: Center(
                    child: CircularProgressIndicator(
                      color: AppColors.primary,
                      strokeWidth: 2.5,
                    ),
                  ),
                ),
              )
            else if (_error != null && _events.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(top: 60),
                  child: ErrorView(message: _error!, onRetry: _load),
                ),
              ),

            const SliverToBoxAdapter(child: SizedBox(height: 28)),
          ],
        ),
      ),
    );
  }
}

/// Compact streak summary on the Home screen, driven by StreakState (v2).
class _HomeStreakCard extends StatelessWidget {
  const _HomeStreakCard();

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final streak = context.watch<StreakState>();
    final dark = Theme.of(context).brightness == Brightness.dark;
    final solo = streak.solo;

    final surface = dark ? AppColors.darkSurface : AppColors.lightCard;
    final border = dark ? AppColors.darkSurfaceAlt : AppColors.lightBorder;

    // Skeleton while the solo streak loads (prevents "create" flash).
    if (app.isAuthenticated && solo == null && streak.soloPhase == StreakLoadPhase.loading) {
      return Container(
        height: 84,
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: border),
        ),
        alignment: Alignment.center,
        child: const SizedBox(
          height: 24,
          width: 24,
          child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.primary),
        ),
      );
    }

    final active = solo != null && solo.started;
    final todayDone = solo?.today.completedCount ?? 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [AppColors.primary, AppColors.primaryDeep]),
              borderRadius: BorderRadius.all(Radius.circular(14)),
            ),
            child: const Icon(
              Icons.local_fire_department_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  active
                      ? '${app.t('Your Streak', 'آپ کا سلسلہ')} · ${solo.currentStreak}'
                      : app.t('Start your Salah Streak', 'اپنی صلاح سٹریک شروع کریں'),
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  active
                      ? '🔥 $todayDone/5 ${app.t('today', 'آج')}'
                      : app.t('Build consistency one day at a time', 'ایک دن میں ایک مستقل بنائیں'),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: dark ? AppColors.darkMuted : AppColors.lightMutedText,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [AppColors.primary, AppColors.primaryDeep]),
              borderRadius: BorderRadius.all(Radius.circular(12)),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => active
                        ? const SoloDashboardScreen()
                        : const StreakHomeScreen(),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  child: Text(
                    active ? app.t('View', 'دیکھیں') : app.t('Go', 'جائیں'),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12.5),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Hero-card state: [current] is the prayer whose own window is still open
/// (Fajr → sunrise, Zuhr → Asr, …) — null in the gaps, when [next] becomes
/// the hero with a starts-in countdown. [endsInSec] is the time to the
/// current window's end (or to the next prayer's start) and [progress] the
/// elapsed fraction of the open window.
class _PrayerClock {
  final PrayerTime? current;
  final PrayerTime next;
  final bool nextIsTomorrow;
  final int endsInSec;
  final double progress;

  const _PrayerClock({
    required this.current,
    required this.next,
    required this.nextIsTomorrow,
    required this.endsInSec,
    required this.progress,
  });
}
