import 'package:flutter/services.dart';

/// Thin bridge to native system-settings screens used by the background
/// playback setup flow (battery-optimization exemption, notification
/// settings). Every call is best-effort and never throws.
class SystemSettingsService {
  static const _channel = MethodChannel('sajda/system_settings');

  static Future<bool> isIgnoringBatteryOptimizations() async {
    try {
      final value =
          await _channel.invokeMethod<bool>('isIgnoringBatteryOptimizations');
      return value ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  static Future<void> requestIgnoreBatteryOptimizations() async {
    try {
      await _channel.invokeMethod('requestIgnoreBatteryOptimizations');
    } on PlatformException {
      // ROM without the dialog — nothing more we can do here.
    } on MissingPluginException {
      // Non-Android platform.
    }
  }

  static Future<void> openNotificationSettings() async {
    try {
      await _channel.invokeMethod('openNotificationSettings');
    } on PlatformException {
      // ignore
    } on MissingPluginException {
      // Non-Android platform.
    }
  }
}
