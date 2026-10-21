import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/streak_v2.dart';
import '../../state/app_state.dart';
import '../../state/streak_state.dart';
import '../../theme/app_theme.dart';

enum _GroupAction { rename, leave, delete }

/// Long-press actions for a group card.
///
/// Owner/admin can rename; owner can permanently delete; everyone else can
/// leave. Returns true when the group list changed.
Future<bool> showGroupActionsSheet(
  BuildContext context,
  GroupSummary group,
) async {
  final app = context.read<AppState>();
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final canManage = group.role == 'owner' || group.role == 'admin';

  final action = await showModalBottomSheet<_GroupAction>(
    context: context,
    backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightCard,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
            child: Text(
              group.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: isDark ? AppColors.darkText : AppColors.lightText,
              ),
            ),
          ),
          if (canManage)
            ListTile(
              leading: const Icon(
                Icons.edit_outlined,
                color: AppColors.primary,
              ),
              title: Text(app.t('Rename group', 'گروپ کا نام بدلیں')),
              onTap: () => Navigator.of(ctx).pop(_GroupAction.rename),
            ),
          if (group.isOwner)
            ListTile(
              leading: const Icon(
                Icons.delete_forever_rounded,
                color: AppColors.danger,
              ),
              title: Text(
                app.t('Delete group', 'گروپ حذف کریں'),
                style: const TextStyle(color: AppColors.danger),
              ),
              onTap: () => Navigator.of(ctx).pop(_GroupAction.delete),
            )
          else
            ListTile(
              leading: const Icon(
                Icons.logout_rounded,
                color: AppColors.danger,
              ),
              title: Text(
                app.t('Leave group', 'گروپ چھوڑیں'),
                style: const TextStyle(color: AppColors.danger),
              ),
              onTap: () => Navigator.of(ctx).pop(_GroupAction.leave),
            ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );

  if (action == null || !context.mounted) return false;
  return switch (action) {
    _GroupAction.rename => _rename(context, group),
    _GroupAction.leave => _leave(context, group),
    _GroupAction.delete => _delete(context, group),
  };
}

Future<bool> _rename(BuildContext context, GroupSummary group) async {
  final app = context.read<AppState>();
  final controller = TextEditingController(text: group.name);
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) {
      final isDark = Theme.of(ctx).brightness == Brightness.dark;
      return AlertDialog(
        backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightCard,
        title: Text(app.t('Rename group', 'گروپ کا نام بدلیں')),
        content: TextField(
          controller: controller,
          maxLength: 60,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(app.t('Cancel', 'منسوخ')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(app.t('Save', 'محفوظ')),
          ),
        ],
      );
    },
  );
  final name = controller.text.trim();
  controller.dispose();
  if (ok != true || !context.mounted) return false;
  if (name.isEmpty || name == group.name) return false;

  final error = await context.read<StreakState>().renameGroup(
    group.groupId,
    name,
  );
  if (!context.mounted) return false;
  if (error != null) {
    _showError(context, app, error);
    return false;
  }
  return true;
}

Future<bool> _leave(BuildContext context, GroupSummary group) async {
  final app = context.read<AppState>();
  final confirm = await _confirm(
    context,
    app,
    title: app.t('Leave group?', 'گروپ چھوڑیں؟'),
    body: app.t(
      'Your past days stay in the group history. You can rejoin with an invite code.',
      'آپ کے گزرے دن گروپ کی تاریخ میں محفوظ رہیں گے۔ آپ کوڈ سے دوبارہ شامل ہو سکتے ہیں۔',
    ),
    danger: true,
  );
  if (confirm != true || !context.mounted) return false;

  final error = await context.read<StreakState>().leaveGroup(group.groupId);
  if (!context.mounted) return false;
  if (error != null) {
    _showError(context, app, error);
    return false;
  }
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(app.t('You left the group', 'آپ گروپ چھوڑ گئے'))),
  );
  return true;
}

Future<bool> _delete(BuildContext context, GroupSummary group) async {
  final app = context.read<AppState>();
  final confirm = await _confirm(
    context,
    app,
    title: app.t('Delete group permanently?', 'گروپ مستقل حذف کریں؟'),
    body: app.t(
      'This deletes all members, history and streak progress for everyone. This cannot be undone.',
      'یہ تمام ارکان، تاریخ اور اسٹریک کی پیش رفت سب کے لیے مستقل حذف کر دے گا۔ یہ واپس نہیں ہو سکتا۔',
    ),
    danger: true,
  );
  if (confirm != true || !context.mounted) return false;

  final error = await context.read<StreakState>().deleteGroup(group.groupId);
  if (!context.mounted) return false;
  if (error != null) {
    _showError(context, app, error);
    return false;
  }
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(app.t('Group deleted', 'گروپ حذف ہو گیا'))),
  );
  return true;
}

Future<bool?> _confirm(
  BuildContext context,
  AppState app, {
  required String title,
  required String body,
  bool danger = false,
}) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  return showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightCard,
      title: Text(
        title,
        style: TextStyle(
          color: isDark ? AppColors.darkText : AppColors.lightText,
        ),
      ),
      content: Text(
        body,
        style: TextStyle(
          height: 1.4,
          color: isDark ? AppColors.darkMuted : AppColors.lightSecondaryText,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(app.t('Cancel', 'منسوخ')),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: TextButton.styleFrom(
            foregroundColor: danger ? AppColors.danger : AppColors.primary,
          ),
          child: Text(app.t('Confirm', 'تصدیق')),
        ),
      ],
    ),
  );
}

void _showError(BuildContext context, AppState app, String error) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        error == 'network'
            ? app.t(
                'No connection. Check your internet.',
                'انٹرنیٹ نہیں چل رہا۔',
              )
            : error,
      ),
    ),
  );
}
