import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/badges.dart';
import '../services/sajda_stats_service.dart';
import '../state/app_state.dart';
import '../state/streak_state.dart';
import '../theme/app_theme.dart';
import '../utils/share_image.dart';

/// F6 — shareable "Sajda Wrapped" story cards built from local stats.
class WrappedScreen extends StatefulWidget {
  const WrappedScreen({super.key});

  @override
  State<WrappedScreen> createState() => _WrappedScreenState();
}

class _WrappedScreenState extends State<WrappedScreen> {
  final PageController _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<_WrappedStory> _stories(
    AppState app,
    SajdaStatsSnapshot stats,
    int badges,
  ) {
    final year = DateTime.now().year;
    return [
      _WrappedStory(
        icon: Icons.mosque_rounded,
        eyebrow: app.t('SAJDA WRAPPED', 'سجدة رپورٹ'),
        value: '$year',
        title: app.t('Your year with Allah', 'اللہ کے ساتھ آپ کا سال'),
        subtitle: app.t(
          'A look back at the prayers, dhikr, and knowledge you gathered.',
          'اپنی نمازوں، ذکر اور علم پر ایک نظر۔',
        ),
        colors: const [Color(0xFF0B3D2E), Color(0xFF00695C)],
      ),
      _WrappedStory(
        icon: Icons.mosque_outlined,
        eyebrow: app.t('PRAYERS LOGGED', 'درج نمازیں'),
        value: '${stats.totalPrayers}',
        title: app.t('Every prayer counted', 'ہر نماز شمار ہوئی'),
        subtitle: app.t(
          'Across ${stats.activeDays} active days, with ${stats.completeDays} perfect days.',
          '${stats.activeDays} فعال دنوں میں، ${stats.completeDays} مکمل دن کے ساتھ۔',
        ),
        colors: const [Color(0xFF123C33), Color(0xFF1B7F5C)],
      ),
      _WrappedStory(
        icon: Icons.local_fire_department_rounded,
        eyebrow: app.t('STREAK', 'سلسلہ'),
        value: '${stats.bestStreak}',
        title: app.t('Your best streak', 'آپ کا بہترین سلسلہ'),
        subtitle: stats.currentStreak > 0
            ? app.t(
                'You are on a ${stats.currentStreak}-day streak right now. Keep it alive.',
                'ابھی آپ ${stats.currentStreak} دن کے سلسلے پر ہیں۔ اسے جاری رکھیں۔',
              )
            : app.t(
                'Start a new streak today — one prayer at a time.',
                'آج نیا سلسلہ شروع کریں — ایک ایک نماز سے۔',
              ),
        colors: const [Color(0xFF5B3A00), Color(0xFFB9770E)],
      ),
      _WrappedStory(
        icon: Icons.circle_rounded,
        eyebrow: app.t('DHIKR & LEARNING', 'ذکر اور علم'),
        value: '${stats.tasbeehSets}',
        title: app.t('Tasbeeh sets completed', 'مکمل تسبیح کے دور'),
        subtitle: app.t(
          'Plus ${stats.quizCorrect} correct quiz answers and ${stats.quizDays} quiz days.',
          'اس کے علاوہ ${stats.quizCorrect} درست کوئز جوابات اور ${stats.quizDays} کوئز دن۔',
        ),
        colors: const [Color(0xFF3B1F4E), Color(0xFF7D3C98)],
      ),
      _WrappedStory(
        icon: Icons.emoji_events_rounded,
        eyebrow: app.t('ACHIEVEMENTS', 'کامیابیاں'),
        value: '$badges/${sajdaBadges.length}',
        title: app.t('Badges unlocked', 'حاصل شدہ بیجز'),
        subtitle: app.t(
          'Small steps, gathered with sincerity, become a life of prayer.',
          'خلوص کے ساتھ کیے گئے چھوٹے قدم نماز سے بھری زندگی بن جاتے ہیں۔',
        ),
        colors: const [Color(0xFF4A3B00), Color(0xFFD4A937)],
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final statsService = context.watch<SajdaStatsService>();
    final streak = context.watch<StreakState>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final stats = statsService.snapshot(
      currentStreak: streak.solo?.currentStreak ?? 0,
      bestStreak: streak.solo?.bestStreak ?? 0,
    );
    final stories = _stories(app, stats, unlockedBadgeCount(stats));

    return Scaffold(
      backgroundColor: isDark
          ? AppColors.darkBackground
          : AppColors.lightBackground,
      appBar: AppBar(title: Text(app.t('Sajda Wrapped', 'سجدة رپورٹ'))),
      body: Column(
        children: [
          Expanded(
            child: PageView.builder(
              controller: _controller,
              itemCount: stories.length,
              onPageChanged: (i) => setState(() => _page = i),
              itemBuilder: (context, i) {
                final story = stories[i];
                return Padding(
                  padding: const EdgeInsets.fromLTRB(22, 8, 22, 8),
                  child: Center(
                    child: FittedBox(
                      fit: BoxFit.contain,
                      child: SizedBox(
                        width: 340,
                        height: 340 * 4 / 3,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(28),
                            gradient: LinearGradient(
                              colors: story.colors,
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: story.colors.last.withValues(
                                  alpha: 0.35,
                                ),
                                blurRadius: 30,
                                offset: const Offset(0, 14),
                              ),
                            ],
                          ),
                          child: MediaQuery.withNoTextScaling(
                            child: _StoryBody(
                              app: app,
                              story: story,
                              index: i,
                              total: stories.length,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(stories.length, (i) {
              final active = i == _page;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: active ? 22 : 7,
                height: 7,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  color: active
                      ? AppColors.primary
                      : (isDark
                            ? AppColors.darkSurfaceAlt
                            : AppColors.lightBorder),
                  borderRadius: BorderRadius.circular(10),
                ),
              );
            }),
          ),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 0, 22, 18),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                    ),
                    onPressed: () {
                      if (_page > 0) {
                        _controller.previousPage(
                          duration: const Duration(milliseconds: 260),
                          curve: Curves.easeOut,
                        );
                      } else {
                        // First card: "Back" leaves the screen. Never a
                        // silent no-op — a dead button reads as broken.
                        Navigator.of(context).maybePop();
                      }
                    },
                    icon: const Icon(Icons.chevron_left_rounded),
                    label: Text(
                      app.t('Back', 'پیچھے'),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                    ),
                    onPressed: () => shareWidgetAsImage(
                      context: context,
                      widget: MediaQuery.withNoTextScaling(
                        child: _StoryShareCard(
                          app: app,
                          story: stories[_page],
                          stats: stats,
                        ),
                      ),
                      fileName: 'sajda_wrapped_${_page + 1}',
                      caption:
                          '${app.t('My Sajda Wrapped', 'میری سجدة رپورٹ')} — '
                          '${stories[_page].value} ${stories[_page].title}\n'
                          'https://play.google.com/store/apps/details?id=com.sajda.dataplus',
                    ),
                    icon: const Icon(Icons.ios_share_rounded, size: 18),
                    label: Text(
                      app.t('Share this card', 'یہ کارڈ شیئر کریں'),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
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

class _WrappedStory {
  final IconData icon;
  final String eyebrow;
  final String value;
  final String title;
  final String subtitle;
  final List<Color> colors;

  const _WrappedStory({
    required this.icon,
    required this.eyebrow,
    required this.value,
    required this.title,
    required this.subtitle,
    required this.colors,
  });
}

class _StoryBody extends StatelessWidget {
  final AppState app;
  final _WrappedStory story;
  final int index;
  final int total;

  const _StoryBody({
    required this.app,
    required this.story,
    required this.index,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          right: -40,
          top: -40,
          child: Icon(
            story.icon,
            size: 190,
            color: Colors.white.withValues(alpha: 0.055),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(26),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.mosque_rounded,
                    color: Colors.white70,
                    size: 18,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'SAJDA',
                    style: TextStyle(
                      letterSpacing: 3,
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${index + 1}/$total',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.white.withValues(alpha: 0.55),
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Container(
                width: 62,
                height: 62,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.14),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.22),
                  ),
                ),
                child: Icon(story.icon, color: Colors.white, size: 30),
              ),
              const SizedBox(height: 18),
              Text(
                story.eyebrow,
                style: TextStyle(
                  letterSpacing: 2,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: Colors.white.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  story.value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 72,
                    height: 1,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                story.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                story.subtitle,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.72),
                  fontSize: 12.5,
                  height: 1.5,
                ),
              ),
              const Spacer(),
              Text(
                app.t(
                  'Sajda • Daily Athan & Qibla',
                  'سجدة • روزانہ اذان اور قبلہ',
                ),
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.45),
                  fontSize: 9.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StoryShareCard extends StatelessWidget {
  final AppState app;
  final _WrappedStory story;
  final SajdaStatsSnapshot stats;

  const _StoryShareCard({
    required this.app,
    required this.story,
    required this.stats,
  });

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 3 / 4,
      child: FittedBox(
        fit: BoxFit.contain,
        child: SizedBox(
          width: 340,
          height: 340 * 4 / 3,
          child: Stack(
            fit: StackFit.expand,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: story.colors,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
              Positioned(
                right: -30,
                top: -20,
                child: Icon(
                  story.icon,
                  size: 150,
                  color: Colors.white.withValues(alpha: 0.07),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.mosque_rounded,
                          color: Colors.white70,
                          size: 16,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          'SAJDA',
                          style: TextStyle(
                            letterSpacing: 3,
                            fontWeight: FontWeight.w900,
                            fontSize: 11,
                            color: Colors.white.withValues(alpha: 0.85),
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Icon(story.icon, color: Colors.white, size: 42),
                    const SizedBox(height: 14),
                    Text(
                      story.eyebrow,
                      style: TextStyle(
                        letterSpacing: 2,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: Colors.white.withValues(alpha: 0.6),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      story.value,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 64,
                        height: 1,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      story.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      story.subtitle,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.72),
                        fontSize: 11,
                        height: 1.45,
                      ),
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        Text(
                          app.t(
                            '${stats.currentStreak}-day streak',
                            '${stats.currentStreak} دن کا سلسلہ',
                          ),
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          app.t('Sajda App', 'سجدة ایپ'),
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.45),
                            fontSize: 9,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'play.google.com/store/apps/details?id=com.sajda.dataplus',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.3),
                        fontSize: 7,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
