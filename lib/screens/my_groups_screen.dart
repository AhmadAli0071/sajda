import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/streak_v2.dart';
import '../state/app_state.dart';
import '../state/streak_state.dart';
import '../theme/app_theme.dart';
import '../widgets/streak/group_actions_sheet.dart';
import '../widgets/streak/streak_components.dart';
import 'create_group_screen.dart';
import 'discover_groups_screen.dart';
import 'group_dashboard_screen.dart';
import 'join_with_code_screen.dart';

/// All my groups (active + archived) with quick actions.
class MyGroupsScreen extends StatelessWidget {
  const MyGroupsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final streak = context.watch<StreakState>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final active = streak.activeGroups;
    final archived = streak.groups.where((g) => g.archived).toList();

    return Scaffold(
      backgroundColor: isDark
          ? AppColors.darkBackground
          : AppColors.lightBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(
          color: isDark ? AppColors.darkText : AppColors.lightText,
        ),
        title: Text(
          app.t('My groups', 'میرے گروپس'),
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: isDark ? AppColors.darkText : AppColors.lightText,
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const CreateGroupScreen())),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.group_add_rounded),
        label: Text(app.t('New', 'نیا')),
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () => streak.refreshGroups(),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 96),
          children: [
            if (streak.groupsPhase == StreakLoadPhase.loading &&
                streak.groups.isEmpty)
              const LoadingList()
            else if (streak.groupsPhase == StreakLoadPhase.error &&
                streak.groups.isEmpty)
              ErrorCard(
                message: streak.groupsError == 'network'
                    ? app.t(
                        'No connection. Check your internet.',
                        'انٹرنیٹ نہیں چل رہا۔',
                      )
                    : (streak.groupsError ?? ''),
                onRetry: () => streak.refreshGroups(),
              )
            else ...[
              if (active.isEmpty)
                EmptyStateCard(
                  icon: Icons.family_restroom_rounded,
                  title: app.t('No groups yet', 'ابھی کوئی گروپ نہیں'),
                  subtitle: app.t(
                    'Create one with family, join with a code, or discover public groups.',
                    'گھر والوں کے ساتھ بنائیں، کوڈ سے شامل ہوں، یا عوامی گروپ تلاش کریں۔',
                  ),
                  action: Wrap(
                    spacing: 10,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const JoinWithCodeScreen(),
                          ),
                        ),
                        icon: const Icon(Icons.vpn_key_rounded, size: 18),
                        label: Text(app.t('Code', 'کوڈ')),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const DiscoverGroupsScreen(),
                          ),
                        ),
                        icon: const Icon(Icons.search_rounded, size: 18),
                        label: Text(app.t('Discover', 'تلاش')),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                )
              else
                ...active.map(
                  (g) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: GroupCard(
                      group: g,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              GroupDashboardScreen(groupId: g.groupId),
                        ),
                      ),
                      onLongPress: () => showGroupActionsSheet(context, g),
                    ),
                  ),
                ),
              if (archived.isNotEmpty) ...[
                const SizedBox(height: 18),
                StreakSectionHeader(title: app.t('Archived', 'آرکائیو')),
                ...archived.map(
                  (g) => GestureDetector(
                    onLongPress: () => showGroupActionsSheet(context, g),
                    child: _ArchivedRow(dark: isDark, group: g),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _ArchivedRow extends StatelessWidget {
  final bool dark;
  final GroupSummary group;

  const _ArchivedRow({required this.dark, required this.group});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: dark ? AppColors.darkSurface : AppColors.lightCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: dark ? AppColors.darkSurfaceAlt : AppColors.lightBorder,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.archive_outlined,
            size: 20,
            color: dark ? AppColors.darkMuted : AppColors.lightMutedText,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              group.name,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: dark
                    ? AppColors.darkMuted
                    : AppColors.lightSecondaryText,
              ),
            ),
          ),
          Text(
            '🔥 ${group.currentStreak} · ${app.t('best', 'بہترین')} ${group.bestStreak}',
            style: TextStyle(
              fontSize: 12,
              color: dark ? AppColors.darkMuted : AppColors.lightMutedText,
            ),
          ),
        ],
      ),
    );
  }
}
