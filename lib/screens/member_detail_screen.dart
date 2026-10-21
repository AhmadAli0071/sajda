import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/streak_v2.dart';
import '../services/streak_v2_api.dart';
import '../services/api_client.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/streak/streak_components.dart';

/// A member's detail: today's five prayers, all-time totals and streaks.
/// Opened by tapping a member's name in the group dashboard.
class MemberDetailScreen extends StatefulWidget {
  final String groupId;
  final MemberProgress member;

  const MemberDetailScreen({super.key, required this.groupId, required this.member});

  @override
  State<MemberDetailScreen> createState() => _MemberDetailScreenState();
}

class _MemberDetailScreenState extends State<MemberDetailScreen> {
  MemberDetailData? _data;
  bool _loading = true;
  String? _error;

  static const _prayerLabels = {
    'fajr': ('Fajr', 'فجر'),
    'dhuhr': ('Dhuhr', 'ظهر'),
    'asr': ('Asr', 'عصر'),
    'maghrib': ('Maghrib', 'مغرب'),
    'isha': ('Isha', 'عشاء'),
  };

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
      final data = await StreakV2Api.instance.getMemberDetail(widget.groupId, widget.member.userId);
      if (!mounted) return;
      setState(() {
        _data = data;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.isNetworkError ? 'network' : e.message;
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

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: isDark ? AppColors.darkText : AppColors.lightText),
        title: Text(
          widget.member.displayName,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: isDark ? AppColors.darkText : AppColors.lightText,
          ),
        ),
      ),
      body: _loading && _data == null
          ? const LoadingList()
          : _error != null
              ? ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    ErrorCard(
                      message: _error == 'network'
                          ? app.t('No connection. Check your internet.', 'انٹرنیٹ نہیں چل رہا۔')
                          : _error!,
                      onRetry: _load,
                    ),
                  ],
                )
              : RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh: _load,
                  child: _buildBody(app, isDark),
                ),
    );
  }

  Widget _buildBody(AppState app, bool isDark) {
    final d = _data!;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        // ── Header ──
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : AppColors.lightCard,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: isDark ? AppColors.darkSurfaceAlt : AppColors.lightBorder),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: AppColors.primary,
                child: Text(
                  d.displayName.isNotEmpty ? d.displayName[0].toUpperCase() : '?',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      d.displayName,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: isDark ? AppColors.darkText : AppColors.lightText,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      d.role == 'owner'
                          ? app.t('Group owner', 'گروپ کا مالک')
                          : d.role == 'admin'
                              ? app.t('Admin', 'ایڈمن')
                              : app.t('Member', 'رکن'),
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppColors.darkMuted : AppColors.lightSecondaryText,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (!d.requiredToday) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
            ),
            child: Text(
              app.t(
                'Group counting starts tomorrow.',
                'گروپ کا شمار کل سے شروع ہوگا۔',
              ),
              style: const TextStyle(fontSize: 12.5, color: AppColors.primaryDeep),
            ),
          ),
        ],
        const SizedBox(height: 20),

        // ── Today ──
        StreakSectionHeader(title: app.t('Today', 'آج')),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : AppColors.lightCard,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: d.today.isDayComplete
                  ? AppColors.success.withValues(alpha: 0.4)
                  : (isDark ? AppColors.darkSurfaceAlt : AppColors.lightBorder),
            ),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(child: StreakDots(count: d.today.completedCount)),
                  Text(
                    '${d.today.completedCount}/5',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: isDark ? AppColors.darkText : AppColors.lightText,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: _prayerLabels.entries.map((e) {
                  final done = d.today.of(e.key);
                  return Expanded(
                    child: Column(
                      children: [
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: done ? AppColors.primary : Colors.transparent,
                            border: Border.all(
                              color: done ? AppColors.primary : (isDark ? AppColors.darkMuted : AppColors.lightBorder),
                              width: 1.6,
                            ),
                          ),
                          child: done
                              ? const Icon(Icons.check_rounded, size: 18, color: Colors.white)
                              : null,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          (e.key == 'dhuhr' && DateTime.now().weekday == DateTime.friday)
                              ? app.t('Friday', 'جمعہ')
                              : app.t(e.value.$1, e.value.$2),
                          style: TextStyle(
                            fontSize: 10.5,
                            color: isDark ? AppColors.darkMuted : AppColors.lightSecondaryText,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // ── Stats ──
        StreakSectionHeader(title: app.t('Performance', 'کارکردگی')),
        Row(
          children: [
            Expanded(
              child: _StatCard(
                dark: isDark,
                icon: Icons.stars_rounded,
                label: app.t('Score', 'سکور'),
                value: '${d.score}',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                dark: isDark,
                icon: Icons.check_circle_outline_rounded,
                label: app.t('Total prayers', 'کل نمازیں'),
                value: '${d.totalPrayers}',
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _StatCard(
                dark: isDark,
                icon: Icons.local_fire_department_rounded,
                label: app.t('Current streak', 'موجودہ سلسلہ'),
                value: '${d.currentStreak}',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                dark: isDark,
                icon: Icons.emoji_events_outlined,
                label: app.t('Best streak', 'بہترین سلسلہ'),
                value: '${d.bestStreak}',
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          '${d.completeDays} ${app.t('complete days so far', 'اب تک مکمل دن')}',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12.5,
            color: isDark ? AppColors.darkMuted : AppColors.lightSecondaryText,
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final bool dark;
  final IconData icon;
  final String label;
  final String value;

  const _StatCard({required this.dark, required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: dark ? AppColors.darkSurface : AppColors.lightCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: dark ? AppColors.darkSurfaceAlt : AppColors.lightBorder),
      ),
      child: Row(
        children: [
          Icon(icon, size: 22, color: AppColors.primary),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: dark ? AppColors.darkText : AppColors.lightText,
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11.5,
                  color: dark ? AppColors.darkMuted : AppColors.lightSecondaryText,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
