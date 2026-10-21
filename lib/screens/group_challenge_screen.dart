import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/streak_v2.dart';
import '../services/api_client.dart';
import '../services/streak_v2_api.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../utils/group_challenge.dart';
import '../widgets/streak/streak_components.dart';

/// F9 — weekly group challenge and today's leaderboard.
class GroupChallengeScreen extends StatefulWidget {
  final GroupDetail group;
  final List<MemberProgress> initialMembers;

  const GroupChallengeScreen({
    super.key,
    required this.group,
    this.initialMembers = const [],
  });

  @override
  State<GroupChallengeScreen> createState() => _GroupChallengeScreenState();
}

class _GroupChallengeScreenState extends State<GroupChallengeScreen> {
  GroupDashboardData? _data;
  HistoryData? _history;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = _data == null && widget.initialMembers.isEmpty;
      _error = null;
    });
    final groupToday =
        DateTime.tryParse(widget.group.dateKey) ?? DateTime.now();
    final months = <DateTime>[DateUtils.dateOnly(groupToday)];
    final weekStart = startOfWeek(groupToday);
    if (weekStart.year != groupToday.year ||
        weekStart.month != groupToday.month) {
      months.add(weekStart);
    }
    try {
      final results = await Future.wait<Object>([
        StreakV2Api.instance.getGroupDashboard(widget.group.groupId),
        for (final month in months)
          StreakV2Api.instance.getGroupHistory(
            widget.group.groupId,
            year: month.year,
            month: month.month,
          ),
      ]);
      if (!mounted) return;
      setState(() {
        _data = results[0] as GroupDashboardData;
        _history = mergeMonthHistories(
          results.skip(1).cast<HistoryData>().toList(),
        );
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e is ApiException
            ? (e.isNetworkError ? 'network' : e.message)
            : e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final members = _data?.members ?? widget.initialMembers;
    final group = _data?.group ?? widget.group;
    final challenge = buildWeekChallenge(
      _history,
      DateTime.tryParse(group.dateKey) ?? DateTime.now(),
    );
    final ranked = rankMembers(members);

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        title: Text(app.t('Weekly Challenge', 'ہفتہ وار چیلنج')),
        actions: [
          IconButton(
            tooltip: app.t('Share', 'شیئر کریں'),
            icon: const Icon(Icons.ios_share_rounded),
            onPressed: () {
              final text = app.t(
                'We completed ${challenge.completedDays}/7 days in our Sajda group challenge "${widget.group.name}". Join us!\n'
                    'https://play.google.com/store/apps/details?id=com.sajda.dataplus',
                'ہم نے سجدة گروپ چیلنج "${widget.group.name}" میں ${challenge.completedDays}/7 دن مکمل کیے۔ آپ بھی شامل ہوں!\n'
                    'https://play.google.com/store/apps/details?id=com.sajda.dataplus',
              );
              SharePlus.instance.share(ShareParams(text: text));
            },
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                if (_error != null) ...[
                  ErrorCard(
                    message: _error == 'network'
                        ? app.t('No connection. Check your internet.',
                            'انٹرنیٹ نہیں چل رہا۔')
                        : _error!,
                    onRetry: _load,
                  ),
                  const SizedBox(height: 16),
                ],
                _ChallengeHero(
                  app: app,
                  challenge: challenge,
                  groupName: widget.group.name,
                ),
                const SizedBox(height: 18),
                Text(
                  app.t('Today\'s leaderboard', 'آج کا لیڈر بورڈ'),
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 10),
                if (ranked.isEmpty)
                  EmptyStateCard(
                    icon: Icons.group_outlined,
                    title: app.t('No members yet', 'ابھی کوئی ممبر نہیں'),
                    subtitle: app.t(
                      'Invite friends to start the challenge.',
                      'چیلنج شروع کرنے کے لیے دوستوں کو مدعو کریں۔',
                    ),
                  )
                else
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
                        for (var i = 0; i < ranked.length; i++) ...[
                          _LeaderRow(
                            app: app,
                            member: ranked[i],
                            rank: i + 1,
                            isDark: isDark,
                          ),
                          if (i != ranked.length - 1)
                            Divider(
                              height: 1,
                              indent: 56,
                              endIndent: 16,
                              color: isDark
                                  ? AppColors.darkSurfaceAlt
                                  : AppColors.lightBorder,
                            ),
                        ],
                      ],
                    ),
                  ),
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        app.t('How the challenge works', 'چیلنج کیسے کام کرتا ہے'),
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 10),
                      _how(
                        app,
                        Icons.flag_rounded,
                        app.t(
                          'Complete the group day on all 7 days of the week.',
                          'ہفتے کے ساتوں دن گروپ ڈے مکمل کریں۔',
                        ),
                      ),
                      const SizedBox(height: 8),
                      _how(
                        app,
                        Icons.groups_rounded,
                        app.t(
                          'Every eligible member\'s prayers count toward the group day.',
                          'ہر اہل ممبر کی نمازیں گروپ ڈے میں شمار ہوتی ہیں۔',
                        ),
                      ),
                      const SizedBox(height: 8),
                      _how(
                        app,
                        Icons.calendar_month_rounded,
                        app.t(
                          'The week starts on Monday. Yesterday\'s results are locked in.',
                          'ہفتہ پیر سے شروع ہوتا ہے۔ گزشتہ دن کے نتائج محفوظ ہیں۔',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _how(AppState app, IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 17, color: AppColors.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 12,
              height: 1.4,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

class _ChallengeHero extends StatelessWidget {
  final AppState app;
  final WeekChallenge challenge;
  final String groupName;

  const _ChallengeHero({
    required this.app,
    required this.challenge,
    required this.groupName,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [AppColors.primaryDeep, AppColors.primary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.flag_rounded, color: Colors.white, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  groupName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Text(
                  '${challenge.completedDays}/7',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            app.t('7-Day Group Challenge', '7 دن کا گروپ چیلنج'),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 23,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            challenge.perfect
                ? app.t('Alhamdulillah — a perfect week!',
                    'الحمدللہ — ایک مکمل ہفتہ!')
                : app.t(
                    '${challenge.completedDays} days complete. ${7 - challenge.completedDays} to go.',
                    '${challenge.completedDays} دن مکمل۔ ${7 - challenge.completedDays} باقی۔',
                  ),
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 12.5,
            ),
          ),
          const SizedBox(height: 18),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: challenge.progress,
              minHeight: 9,
              backgroundColor: Colors.white.withValues(alpha: 0.18),
              color: const Color(0xFFD4A937),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: challenge.days.map((day) {
              return Expanded(
                child: Column(
                  children: [
                    Text(
                      _weekday(day.date),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.55),
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      width: 28,
                      height: 28,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: day.isComplete
                            ? const Color(0xFFD4A937)
                            : Colors.white.withValues(
                                alpha: day.isToday ? 0.28 : 0.1,
                              ),
                        border: day.isToday
                            ? Border.all(color: Colors.white, width: 1.4)
                            : null,
                      ),
                      child: day.isComplete
                          ? const Icon(Icons.check_rounded,
                              size: 16, color: Colors.white)
                          : Text(
                              '${day.date.day}',
                              style: TextStyle(
                                color: Colors.white.withValues(
                                    alpha: day.isFuture ? 0.35 : 0.8),
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  String _weekday(DateTime date) {
    const en = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
    return en[date.weekday - 1];
  }
}

class _LeaderRow extends StatelessWidget {
  final AppState app;
  final MemberProgress member;
  final int rank;
  final bool isDark;

  const _LeaderRow({
    required this.app,
    required this.member,
    required this.rank,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final color = rank == 1
        ? const Color(0xFFD4A937)
        : rank == 2
            ? const Color(0xFF95A5A6)
            : rank == 3
                ? const Color(0xFFB9770E)
                : null;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: color != null
                ? Icon(Icons.emoji_events_rounded, color: color, size: 20)
                : Text(
                    '$rank',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
          ),
          const SizedBox(width: 10),
          CircleAvatar(
            radius: 16,
            backgroundColor: AppColors.primary.withValues(alpha: 0.14),
            child: Text(
              member.displayName.isEmpty
                  ? '?'
                  : member.displayName.substring(0, 1).toUpperCase(),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: AppColors.primaryDark,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        member.isMe
                            ? app.t('You', 'آپ')
                            : member.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight:
                              member.isMe ? FontWeight.w900 : FontWeight.w700,
                        ),
                      ),
                    ),
                    if (member.isMe) ...[
                      const SizedBox(width: 5),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          app.t('ME', 'میں'),
                          style: const TextStyle(
                            fontSize: 7,
                            fontWeight: FontWeight.w900,
                            color: AppColors.primaryDark,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    for (final prayer in const [
                      'fajr',
                      'dhuhr',
                      'asr',
                      'maghrib',
                      'isha',
                    ])
                      Container(
                        width: 9,
                        height: 9,
                        margin: const EdgeInsets.only(right: 3),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: member.prayerDone(prayer)
                              ? AppColors.primary
                              : (isDark
                                  ? AppColors.darkSurfaceAlt
                                  : AppColors.lightBorder),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            '${member.completedCount}/5',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: member.isDayComplete
                  ? AppColors.primary
                  : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
