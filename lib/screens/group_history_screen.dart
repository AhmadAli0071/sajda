import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/streak_v2.dart';
import '../services/streak_v2_api.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/glass/glass_background.dart';
import 'solo_history_screen.dart';

/// Month-by-month history for one group. New members never break streaks
/// retroactively, so 'missed' only shows days after the member joined.
class GroupHistoryScreen extends StatelessWidget {
  final GroupDetail group;

  const GroupHistoryScreen({super.key, required this.group});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: AppColors.textMain(isDark)),
        title: Flexible(
          child: Text(
            '${group.name} · ${app.t('history', 'تاریخ')}',
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textMain(isDark),
            ),
          ),
        ),
      ),
      body: GlassBackground(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            20,
            MediaQuery.of(context).padding.top + kToolbarHeight + 8,
            20,
            32,
          ),
          child: MonthHistoryView(
            title: group.name,
            fetch: (y, m) => StreakV2Api.instance.getGroupHistory(group.groupId, year: y, month: m),
          ),
        ),
      ),
    );
  }
}
