import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/streak_v2.dart';
import '../services/streak_v2_api.dart';
import '../state/app_state.dart';
import '../services/api_client.dart';
import '../theme/app_theme.dart';
import '../widgets/glass/glass_background.dart';
import '../widgets/glass/glass_panel.dart';
import '../widgets/streak/streak_components.dart';

const _monthNamesEn = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];

const _monthNamesUr = [
  'جنوری', 'فروری', 'مارچ', 'اپریل', 'مئی', 'جون',
  'جولائی', 'اگست', 'ستمبر', 'اکتوبر', 'نومبر', 'دسمبر',
];

/// Reusable month-history view with a colored calendar grid. Used by both
/// solo history and group history.
class MonthHistoryView extends StatefulWidget {
  final Future<HistoryData> Function(int year, int month) fetch;
  final String title;

  const MonthHistoryView({super.key, required this.fetch, required this.title});

  @override
  State<MonthHistoryView> createState() => _MonthHistoryViewState();
}

class _MonthHistoryViewState extends State<MonthHistoryView> {
  late int _year;
  late int _month;
  HistoryData? _data;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _year = now.year;
    _month = now.month;
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await widget.fetch(_year, _month);
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

  void _shift(int delta) {
    var m = _month + delta;
    var y = _year;
    if (m < 1) {
      m = 12;
      y--;
    } else if (m > 12) {
      m = 1;
      y++;
    }
    setState(() {
      _month = m;
      _year = y;
    });
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = AppColors.accent(isDark);
    final textMain = AppColors.textMain(isDark);
    final textSub = AppColors.textSub(isDark);
    final monthName =
        app.isUrdu ? _monthNamesUr[_month - 1] : _monthNamesEn[_month - 1];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GlassPanel(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                onPressed: _loading ? null : () => _shift(-1),
                icon: const Icon(Icons.chevron_left_rounded),
                color: accent,
              ),
              Text(
                '$monthName $_year',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: textMain,
                ),
              ),
              IconButton(
                onPressed: _loading ? null : () => _shift(1),
                icon: const Icon(Icons.chevron_right_rounded),
                color: accent,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (_loading)
          const LoadingList()
        else if (_error != null)
          ErrorCard(
            message: _error == 'network'
                ? app.t('No connection. Check your internet.', 'انٹرنیٹ نہیں چل رہا۔')
                : _error!,
            onRetry: _load,
          )
        else ...[
          _buildGrid(app, isDark, accent, textMain, textSub),
          const SizedBox(height: 14),
          _buildLegend(app, isDark, accent, textSub),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _SummaryChip(
                  dark: isDark,
                  label: app.t('Current', 'موجودہ'),
                  value: '🔥 ${_data!.currentStreak}',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _SummaryChip(
                  dark: isDark,
                  label: app.t('Best', 'بہترین'),
                  value: '🏆 ${_data!.bestStreak}',
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildGrid(
    AppState app,
    bool isDark,
    Color accent,
    Color textMain,
    Color textSub,
  ) {
    final data = _data!;
    final firstWeekday = DateTime(_year, _month, 1).weekday;
    final daysInMonth = DateTime(_year, _month + 1, 0).day;
    final dayMap = {for (final d in data.calendar) d.day: d};

    final labels = [
      app.t('M', 'س'), app.t('T', 'و'), app.t('W', 'ب'),
      app.t('T', 'پ'), app.t('F', 'ج'), app.t('S', 'ہ'), app.t('S', 'ہ'),
    ];

    return GlassPanel(
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          Row(
            children: labels
                .map((l) => Expanded(
                      child: Center(
                        child: Text(
                          l,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: textSub,
                          ),
                        ),
                      ),
                    ))
                .toList(),
          ),
          const SizedBox(height: 8),
          ...List.generate(((firstWeekday - 1 + daysInMonth) / 7).ceil(), (row) {
            return Row(
              children: List.generate(7, (col) {
                final dayNum = row * 7 + col - (firstWeekday - 1) + 1;
                if (dayNum < 1 || dayNum > daysInMonth) {
                  return const Expanded(child: SizedBox(height: 38));
                }
                final MonthDay? md = dayMap[dayNum];
                return Expanded(
                  child: Center(
                    child: _DayCell(
                      dark: isDark,
                      day: dayNum,
                      state: md?.state ?? 'none',
                      completedCount: md?.completedCount ?? 0,
                    ),
                  ),
                );
              }),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildLegend(
    AppState app,
    bool isDark,
    Color accent,
    Color textSub,
  ) {
    final items = [
      (accent, app.t('Complete (5/5)', 'مکمل (۵/۵)')),
      (accent.withValues(alpha: 0.35), app.t('Partial', 'نامکمل')),
      (isDark ? AppColors.darkSurfaceAlt : AppColors.lightDivider,
          app.t('Missed', 'چھوٹا')),
    ];
    return GlassPanel(
      darken: true,
      radius: 16,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Wrap(
        spacing: 16,
        runSpacing: 6,
        children: items
            .map((i) => Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration:
                          BoxDecoration(color: i.$1, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      i.$2,
                      style: TextStyle(fontSize: 11.5, color: textSub),
                    ),
                  ],
                ))
            .toList(),
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  final bool dark;
  final int day;
  final String state;
  final int completedCount;

  const _DayCell({
    required this.dark,
    required this.day,
    required this.state,
    required this.completedCount,
  });

  @override
  Widget build(BuildContext context) {
    final accent = AppColors.accent(dark);
    Color bg;
    Color fg;
    switch (state) {
      case 'complete':
        bg = accent;
        fg = Colors.white;
        break;
      case 'today':
        bg = accent.withValues(alpha: 0.25);
        fg = dark ? AppColors.darkText : AppColors.emerald;
        break;
      case 'missed':
        bg = dark ? AppColors.darkSurfaceAlt : AppColors.lightDivider;
        fg = dark ? AppColors.darkMuted : AppColors.lightMutedText;
        break;
      case 'partial':
        bg = accent.withValues(alpha: 0.35);
        fg = dark ? AppColors.darkText : AppColors.emerald;
        break;
      default: // future / none
        bg = Colors.transparent;
        fg = dark ? AppColors.darkMuted : AppColors.lightMutedText;
    }
    return Tooltip(
      message: state == 'partial' || state == 'complete' ? '$completedCount/5' : '',
      child: Container(
        width: 34,
        height: 34,
        margin: const EdgeInsets.symmetric(vertical: 2),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: bg,
          shape: BoxShape.circle,
          border: state == 'today' ? Border.all(color: accent, width: 1.6) : null,
        ),
        child: Text(
          '$day',
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: state == 'complete' || state == 'today'
                ? FontWeight.w700
                : FontWeight.w500,
            color: fg,
          ),
        ),
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  final bool dark;
  final String label;
  final String value;

  const _SummaryChip({required this.dark, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      radius: 14,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: dark ? AppColors.darkMuted : AppColors.lightSecondaryText,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: dark ? AppColors.darkText : AppColors.lightText,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Solo history screen
// ─────────────────────────────────────────────────────────────────────

class SoloHistoryScreen extends StatelessWidget {
  const SoloHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: AppColors.textMain(isDark)),
        title: Text(
          app.t('Solo history', 'اکیلے کی تاریخ'),
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.textMain(isDark),
          ),
        ),
      ),
      body: GlassBackground(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          child: MonthHistoryView(
            title: app.t('Solo history', 'اکیلے کی تاریخ'),
            fetch: (y, m) => StreakV2Api.instance.getSoloHistory(year: y, month: m),
          ),
        ),
      ),
    );
  }
}
