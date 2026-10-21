import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../state/app_state.dart';
import 'notification_router.dart';
import 'system_settings_service.dart';

const _kPromptedKey = 'sajda_bg_audio_prompted';

/// One-time setup prompt shown before the first background-playback attempt.
///
/// Two things reliably kill background audio on real devices:
///  - Android 13+: a denied notification permission hides the media
///    notification (and on OEM ROMs that also gets the foreground service
///    deprioritised/killed).
///  - Aggressive OEM ROMs (Tecno/HiOS, Infinix, MIUI…): the process is frozen
///    or killed seconds after backgrounding unless the app is exempt from
///    battery optimization.
///
/// Both are surfaced contextually, right before the user starts playback, so
/// "Allow" → system permission dialog + battery-optimization dialog. The
/// prompt is only ever shown once per install and never blocks playback.
Future<void> ensureBackgroundAudioReady(BuildContext context) async {
  try {
    final android = NotificationRouter.instance.plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return;

    final state = context.read<AppState>();
    final notificationsEnabled =
        await android.areNotificationsEnabled() ?? true;
    final ignoringBattery =
        await SystemSettingsService.isIgnoringBatteryOptimizations();
    if (notificationsEnabled && ignoringBattery) return;

    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_kPromptedKey) ?? false) return;
    if (!context.mounted) return;
    await prefs.setBool(_kPromptedKey, true);
    if (!context.mounted) return;

    final approved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(state.t('Keep audio playing', 'آڈیو جاری رکھیں')),
        content: Text(state.t(
          'To keep Quran recitation and radio playing while the app is in the background, allow notifications and switch off battery optimization for Sajda.',
          'ایپ بیک گراؤنڈ میں ہونے پر تلاوت اور ریڈیو جاری رکھنے کے لیے نوٹیفکیشن کی اجازت دیں اور سجدا کے لیے بیٹری آپٹیمائزیشن بند کریں۔',
        )),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(state.t('Later', 'بعد میں')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(state.t('Allow', 'اجازت دیں')),
          ),
        ],
      ),
    );
    if (approved != true) return;

    // Notifications first (system dialog), then the battery screen.
    if (!notificationsEnabled) {
      await android.requestNotificationsPermission();
    }
    if (!ignoringBattery) {
      await SystemSettingsService.requestIgnoreBatteryOptimizations();
    }

    if (!context.mounted) return;
    final stillDisabled = await android.areNotificationsEnabled() ?? true;
    if (!stillDisabled) return;
    if (!context.mounted) return;
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(
        content: Text(state.t(
          'Notifications are off. Enable them in system settings so audio keeps playing in the background.',
          'نوٹیفکیشنز بند ہیں۔ بیک گراؤنڈ آڈیو کے لیے سسٹم سیٹنگز میں انہیں آن کریں۔',
        )),
        action: SnackBarAction(
          label: state.t('Settings', 'سیٹنگز'),
          onPressed: () => SystemSettingsService.openNotificationSettings(),
        ),
      ),
    );
  } catch (_) {
    // Never block playback on a permissions/settings hiccup.
  }
}
