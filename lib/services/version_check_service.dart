import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/app_theme.dart';
import 'api_client.dart';

/// Launch-time update gate (soft + force).
///
/// Fetches `GET /api/app-config` (`min_required_version`, `latest_version`,
/// store URLs and release notes) once per app start, compares it against the
/// locally installed version via `package_info_plus`, and:
///
///  * installed < `latest_version`  → SOFT popup: "Update available" with
///    "Update Now" + "Later" (dismissible). Shown on every app start until
///    the user updates — this is the normal Play-Console-release flow.
///  * installed < `min_required_version` → FORCE gate: a NON-DISMISSABLE
///    dialog that blocks app usage until the user updates through the store.
///
/// Design rules:
///  * Never throws: a failed/offline config fetch must not block launch.
///  * `min_required_version == '0.0.0'` (or missing) = force gate disabled.
///  * Empty/`0.0.0` `latest_version` = soft popup disabled.
///  * The force dialog cannot be closed with the back button or by tapping
///    outside; the only action is "Update Now 🚀".
class VersionCheckService {
  VersionCheckService._();
  static final VersionCheckService instance = VersionCheckService._();

  static const String _fallbackPlayUrl =
      'https://play.google.com/store/apps/details?id=com.sajda.dataplus';

  /// Ensures the check runs at most once per app start.
  bool _checked = false;
  bool _showing = false;

  /// Call once after the splash screen (needs a mounted context for the
  /// dialog). Safe to call multiple times — subsequent calls are no-ops.
  Future<void> checkOnLaunch(BuildContext context) async {
    if (_checked) return;
    _checked = true;
    try {
      final json = await ApiClient.instance.get('/app-config');
      final data = json['data'] as Map<String, dynamic>? ?? const {};
      final minRequired =
          (data['min_required_version'] ?? '').toString().trim();
      final latest =
          (data['latest_version'] ?? '').toString().trim();

      final info = await PackageInfo.fromPlatform();
      final current = info.version; // e.g. "1.0.3" (build "+4" excluded)

      // 1) Force update — installed version is below the hard minimum.
      if (minRequired.isNotEmpty &&
          minRequired != '0.0.0' &&
          compareVersions(current, minRequired) < 0) {
        if (!context.mounted || _showing) return;
        _showing = true;
        // ignore: use_build_context_synchronously
        await showForceUpdateDialog(
          context,
          currentVersion: current,
          minVersion: minRequired,
          latestVersion: latest,
          releaseNotes: (data['release_notes'] ?? '').toString(),
          playStoreUrl: (data['play_store_url'] ?? '').toString(),
          appStoreUrl: (data['app_store_url'] ?? '').toString(),
        );
        return;
      }

      // 2) Soft update — a newer release is on the store but the app is
      //    still usable. Nudges the user with a dismissable popup.
      if (latest.isNotEmpty &&
          latest != '0.0.0' &&
          compareVersions(current, latest) < 0) {
        if (!context.mounted || _showing) return;
        _showing = true;
        // ignore: use_build_context_synchronously
        await showSoftUpdateDialog(
          context,
          currentVersion: current,
          latestVersion: latest,
          releaseNotes: (data['release_notes'] ?? '').toString(),
          playStoreUrl: (data['play_store_url'] ?? '').toString(),
          appStoreUrl: (data['app_store_url'] ?? '').toString(),
        );
      }
    } catch (_) {
      // Offline / server error / bad payload → never block the app start.
      // The next app launch will retry the check.
    }
  }

  /// Numeric dotted-version comparison: `1.2.9 < 1.2.10`, `2.0.0 < 2.0.1`.
  /// Build metadata (`1.0.3+4`) is ignored; missing parts count as 0.
  /// Returns <0 when [a] is older, 0 when equal, >0 when newer.
  static int compareVersions(String a, String b) {
    final pa = _segments(a);
    final pb = _segments(b);
    for (var i = 0; i < 3; i++) {
      final d = pa[i].compareTo(pb[i]);
      if (d != 0) return d;
    }
    return 0;
  }

  static List<int> _segments(String version) {
    final cleaned = version.split('+').first.trim();
    final parts = cleaned.split('.');
    return List<int>.generate(
      3,
      (i) => (i < parts.length ? int.tryParse(parts[i].trim()) : null) ?? 0,
    );
  }

  /// Store page URL for the current platform, preferring backend-provided
  /// links and falling back to the Play Store listing.
  static String _storeUrl({
    required String playStoreUrl,
    required String appStoreUrl,
  }) {
    if (Platform.isIOS && appStoreUrl.isNotEmpty) return appStoreUrl;
    if (playStoreUrl.isNotEmpty) return playStoreUrl;
    if (appStoreUrl.isNotEmpty) return appStoreUrl;
    return _fallbackPlayUrl;
  }

  /// The non-dismissible gate. Only "Update Now" can be pressed — back
  /// button and barrier taps are blocked.
  Future<void> showForceUpdateDialog(
    BuildContext context, {
    required String currentVersion,
    required String minVersion,
    String latestVersion = '',
    String releaseNotes = '',
    String playStoreUrl = '',
    String appStoreUrl = '',
  }) {
    final url = _storeUrl(playStoreUrl: playStoreUrl, appStoreUrl: appStoreUrl);
    final isUrdu = Localizations.maybeLocaleOf(context)?.languageCode == 'ur';
    final target = (latestVersion.isNotEmpty ? latestVersion : minVersion);

    return showDialog<void>(
      context: context,
      barrierDismissible: false, // tapping outside does nothing
      builder: (dialogContext) => PopScope(
        canPop: false, // Android back button does nothing
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          titlePadding: const EdgeInsets.fromLTRB(24, 28, 24, 0),
          contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
          actionsPadding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          title: Column(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: AppColors.gradientTeal,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: const Icon(Icons.system_update_rounded,
                    color: Colors.white, size: 32),
              ),
              const SizedBox(height: 16),
              Text(
                isUrdu ? 'ایپ ڈیٹ کریں' : 'Update Required',
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 19),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  isUrdu
                      ? 'ایپ استعمال جاری رکھنے کے لیے نیا ورژن دستیاب ہے۔'
                      : 'A new version of the app is available.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14.5,
                    height: 1.5,
                    color: Theme.of(dialogContext).textTheme.bodySmall?.color,
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    isUrdu
                        ? 'آپ کا ورژن: $currentVersion\nضروری ورژن: $target'
                        : 'Your version: $currentVersion\nRequired: $target',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                if (releaseNotes.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Text(
                    releaseNotes,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.5,
                      color:
                          Theme.of(dialogContext).textTheme.bodySmall?.color,
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _openStore(url),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  isUrdu ? 'ابھی ڈیٹ کریں 🚀' : 'Update Now 🚀',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Soft (optional) update popup — dismissable via "Later" / back button.
  /// Shown on every app start while the installed version is below
  /// `latest_version`, so the user is always nudged after a Play release.
  Future<void> showSoftUpdateDialog(
    BuildContext context, {
    required String currentVersion,
    required String latestVersion,
    String releaseNotes = '',
    String playStoreUrl = '',
    String appStoreUrl = '',
  }) {
    final url = _storeUrl(playStoreUrl: playStoreUrl, appStoreUrl: appStoreUrl);
    final isUrdu = Localizations.maybeLocaleOf(context)?.languageCode == 'ur';

    return showDialog<void>(
      context: context,
      barrierDismissible: true, // tapping outside dismisses
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        titlePadding: const EdgeInsets.fromLTRB(24, 28, 24, 0),
        contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
        actionsPadding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
        title: Column(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: AppColors.gradientTeal,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: const Icon(Icons.system_update_rounded,
                  color: Colors.white, size: 32),
            ),
            const SizedBox(height: 16),
            Text(
              isUrdu ? 'نیا ورژن دستیاب ہے' : 'Update Available',
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 19),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                isUrdu
                    ? 'ایپ کا نیا ورژن Play Store پر دستیاب ہے۔ بہترین تجربے کے لیے اپ ڈیٹ کریں۔'
                    : 'A new version of the app is on the Play Store. Update for the best experience.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14.5,
                  height: 1.5,
                  color: Theme.of(dialogContext).textTheme.bodySmall?.color,
                ),
              ),
              const SizedBox(height: 14),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  isUrdu
                      ? 'آپ کا ورژن: $currentVersion\nنیا ورژن: $latestVersion'
                      : 'Your version: $currentVersion\nNew version: $latestVersion',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ),
              if (releaseNotes.isNotEmpty) ...[
                const SizedBox(height: 14),
                Text(
                  releaseNotes,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.5,
                    color:
                        Theme.of(dialogContext).textTheme.bodySmall?.color,
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ElevatedButton(
                  onPressed: () => _openStore(url),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    isUrdu ? 'ابھی ڈیٹ کریں 🚀' : 'Update Now 🚀',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: Text(
                    isUrdu ? 'بعد میں' : 'Later',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color:
                          Theme.of(dialogContext).textTheme.bodySmall?.color,
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

  Future<void> _openStore(String url) async {
    final uri = Uri.parse(url);
    // Force an external browser/app link; in-app views must not swallow it.
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
