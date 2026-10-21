import 'package:flutter/material.dart';

import '../services/sajda_stats_service.dart';

/// A collectible achievement. Unlock rules read only on-device stats, so
/// badge status works offline and needs no backend changes.
class SajdaBadge {
  final String id;
  final String titleEn;
  final String titleUr;
  final String descriptionEn;
  final String descriptionUr;
  final IconData icon;
  final Color color;
  final bool Function(SajdaStatsSnapshot stats) isUnlocked;

  const SajdaBadge({
    required this.id,
    required this.titleEn,
    required this.titleUr,
    required this.descriptionEn,
    required this.descriptionUr,
    required this.icon,
    required this.color,
    required this.isUnlocked,
  });
}

const _gold = Color(0xFFD4A937);
const _green = Color(0xFF1B7F5C);
const _blue = Color(0xFF1F618D);
const _violet = Color(0xFF7D3C98);
const _rose = Color(0xFFC0392B);
const _teal = Color(0xFF117A65);
const _amber = Color(0xFFB9770E);

/// 18 badges spanning consistency, volume, and the app's other tools.
const List<SajdaBadge> sajdaBadges = [
  SajdaBadge(
    id: 'first_prayer',
    titleEn: 'First Step',
    titleUr: 'پہلا قدم',
    descriptionEn: 'Log your first prayer.',
    descriptionUr: 'اپنی پہلی نماز مکمل کریں۔',
    icon: Icons.directions_walk_rounded,
    color: _green,
    isUnlocked: _firstPrayer,
  ),
  SajdaBadge(
    id: 'first_complete_day',
    titleEn: 'A Perfect Day',
    titleUr: 'ایک مکمل دن',
    descriptionEn: 'Complete all five prayers in one day.',
    descriptionUr: 'ایک دن میں پانچوں نمازیں مکمل کریں۔',
    icon: Icons.check_circle_rounded,
    color: _green,
    isUnlocked: _firstCompleteDay,
  ),
  SajdaBadge(
    id: 'streak_3',
    titleEn: 'Three in a Row',
    titleUr: 'تین روزہ سلسلہ',
    descriptionEn: 'Reach a 3-day streak.',
    descriptionUr: 'تین دن کا سلسلہ بنائیں۔',
    icon: Icons.local_fire_department_rounded,
    color: _amber,
    isUnlocked: _streak3,
  ),
  SajdaBadge(
    id: 'streak_7',
    titleEn: 'Week of Light',
    titleUr: 'روشن ہفتہ',
    descriptionEn: 'Reach a 7-day streak.',
    descriptionUr: 'سات دن کا سلسلہ بنائیں۔',
    icon: Icons.auto_awesome_rounded,
    color: _gold,
    isUnlocked: _streak7,
  ),
  SajdaBadge(
    id: 'streak_30',
    titleEn: 'Month of Deen',
    titleUr: 'ایمان کا مہینہ',
    descriptionEn: 'Reach a 30-day streak.',
    descriptionUr: 'تیس دن کا سلسلہ بنائیں۔',
    icon: Icons.workspace_premium_rounded,
    color: _gold,
    isUnlocked: _streak30,
  ),
  SajdaBadge(
    id: 'streak_100',
    titleEn: 'Century of Sajda',
    titleUr: 'سو دن کا سجدہ',
    descriptionEn: 'Reach a 100-day streak.',
    descriptionUr: 'سو دن کا سلسلہ بنائیں۔',
    icon: Icons.military_tech_rounded,
    color: _violet,
    isUnlocked: _streak100,
  ),
  SajdaBadge(
    id: 'streak_365',
    titleEn: 'Year with Allah',
    titleUr: 'اللہ کے ساتھ ایک سال',
    descriptionEn: 'Reach a 365-day streak.',
    descriptionUr: 'ایک سال کا سلسلہ بنائیں۔',
    icon: Icons.emoji_events_rounded,
    color: _gold,
    isUnlocked: _streak365,
  ),
  SajdaBadge(
    id: 'prayers_50',
    titleEn: 'Fifty Prayers',
    titleUr: 'پچاس نمازیں',
    descriptionEn: 'Log 50 prayers.',
    descriptionUr: 'پچاس نمازیں مکمل کریں۔',
    icon: Icons.filter_5_rounded,
    color: _green,
    isUnlocked: _prayers50,
  ),
  SajdaBadge(
    id: 'prayers_500',
    titleEn: 'Five Hundred',
    titleUr: 'پانچ سو',
    descriptionEn: 'Log 500 prayers.',
    descriptionUr: 'پانچ سو نمازیں مکمل کریں۔',
    icon: Icons.bolt_rounded,
    color: _blue,
    isUnlocked: _prayers500,
  ),
  SajdaBadge(
    id: 'prayers_1000',
    titleEn: 'A Thousand Prayers',
    titleUr: 'ہزار نمازیں',
    descriptionEn: 'Log 1,000 prayers.',
    descriptionUr: 'ہزار نمازیں مکمل کریں۔',
    icon: Icons.whatshot_rounded,
    color: _rose,
    isUnlocked: _prayers1000,
  ),
  SajdaBadge(
    id: 'early_bird',
    titleEn: 'Early Bird',
    titleUr: 'صبح کا پہلا پرندہ',
    descriptionEn: 'Pray Fajr 21 times.',
    descriptionUr: 'اکیس بار فجر ادا کریں۔',
    icon: Icons.wb_twilight_rounded,
    color: _amber,
    isUnlocked: _earlyBird,
  ),
  SajdaBadge(
    id: 'night_guard',
    titleEn: 'Night Guard',
    titleUr: 'رات کا نگہبان',
    descriptionEn: 'Pray Isha 30 times.',
    descriptionUr: 'تیس بار عشاء ادا کریں۔',
    icon: Icons.nightlight_round,
    color: _violet,
    isUnlocked: _nightGuard,
  ),
  SajdaBadge(
    id: 'active_30',
    titleEn: 'Thirty Active Days',
    titleUr: 'تیس فعال دن',
    descriptionEn: 'Log prayers on 30 different days.',
    descriptionUr: 'تیس مختلف دنوں میں نمازیں مکمل کریں۔',
    icon: Icons.calendar_month_rounded,
    color: _teal,
    isUnlocked: _active30,
  ),
  SajdaBadge(
    id: 'active_100',
    titleEn: 'Hundred Days Strong',
    titleUr: 'سو دن مضبوط',
    descriptionEn: 'Log prayers on 100 different days.',
    descriptionUr: 'سو مختلف دنوں میں نمازیں مکمل کریں۔',
    icon: Icons.event_available_rounded,
    color: _blue,
    isUnlocked: _active100,
  ),
  SajdaBadge(
    id: 'tasbeeh_100',
    titleEn: 'Dhikr Heart',
    titleUr: 'ذکر والا دل',
    descriptionEn: 'Finish 100 tasbeeh sets.',
    descriptionUr: 'سو تسبیح کے دور مکمل کریں۔',
    icon: Icons.circle_rounded,
    color: _teal,
    isUnlocked: _tasbeeh100,
  ),
  SajdaBadge(
    id: 'tasbeeh_1000',
    titleEn: 'Ocean of Dhikr',
    titleUr: 'ذکر کا سمندر',
    descriptionEn: 'Finish 1,000 tasbeeh sets.',
    descriptionUr: 'ہزار تسبیح کے دور مکمل کریں۔',
    icon: Icons.water_rounded,
    color: _blue,
    isUnlocked: _tasbeeh1000,
  ),
  SajdaBadge(
    id: 'quiz_50',
    titleEn: 'Knowledge Seeker',
    titleUr: 'علم کا طالب',
    descriptionEn: 'Answer 50 quiz questions correctly.',
    descriptionUr: 'پچاس کوئز سوالات کے درست جواب دیں۔',
    icon: Icons.psychology_rounded,
    color: _violet,
    isUnlocked: _quiz50,
  ),
  SajdaBadge(
    id: 'quiz_250',
    titleEn: 'Quran Scholar',
    titleUr: 'قرآن کا عالم',
    descriptionEn: 'Answer 250 quiz questions correctly.',
    descriptionUr: 'ڈھائی سو کوئز سوالات کے درست جواب دیں۔',
    icon: Icons.school_rounded,
    color: _gold,
    isUnlocked: _quiz250,
  ),
];

bool _firstPrayer(SajdaStatsSnapshot s) => s.totalPrayers >= 1;
bool _firstCompleteDay(SajdaStatsSnapshot s) => s.completeDays >= 1;
bool _streak3(SajdaStatsSnapshot s) => s.bestStreak >= 3;
bool _streak7(SajdaStatsSnapshot s) => s.bestStreak >= 7;
bool _streak30(SajdaStatsSnapshot s) => s.bestStreak >= 30;
bool _streak100(SajdaStatsSnapshot s) => s.bestStreak >= 100;
bool _streak365(SajdaStatsSnapshot s) => s.bestStreak >= 365;
bool _prayers50(SajdaStatsSnapshot s) => s.totalPrayers >= 50;
bool _prayers500(SajdaStatsSnapshot s) => s.totalPrayers >= 500;
bool _prayers1000(SajdaStatsSnapshot s) => s.totalPrayers >= 1000;
bool _earlyBird(SajdaStatsSnapshot s) => s.fajrCount >= 21;
bool _nightGuard(SajdaStatsSnapshot s) => s.ishaCount >= 30;
bool _active30(SajdaStatsSnapshot s) => s.activeDays >= 30;
bool _active100(SajdaStatsSnapshot s) => s.activeDays >= 100;
bool _tasbeeh100(SajdaStatsSnapshot s) => s.tasbeehSets >= 100;
bool _tasbeeh1000(SajdaStatsSnapshot s) => s.tasbeehSets >= 1000;
bool _quiz50(SajdaStatsSnapshot s) => s.quizCorrect >= 50;
bool _quiz250(SajdaStatsSnapshot s) => s.quizCorrect >= 250;

int unlockedBadgeCount(SajdaStatsSnapshot stats) =>
    sajdaBadges.where((b) => b.isUnlocked(stats)).length;

/// Badge closest to unlocking — used by the achievements header.
SajdaBadge? nextLockedBadge(SajdaStatsSnapshot stats) {
  for (final badge in sajdaBadges) {
    if (!badge.isUnlocked(stats)) return badge;
  }
  return null;
}
