import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'screens/main_shell.dart';
import 'screens/onboarding_screen.dart';
import 'screens/location_setup_screen.dart';
import 'services/ayah_notification_service.dart';
import 'services/adhkar_service.dart';
import 'services/azkar_audio_provider.dart';
import 'services/deep_link_service.dart';
import 'services/dua_notification_service.dart';
import 'services/firebase_auth_service.dart';
import 'services/notification_router.dart';
import 'services/prayer_notification_service.dart';
import 'services/quran_translation_provider.dart';
import 'services/tafsir_provider.dart';
import 'services/wazifa_notification_service.dart';
import 'services/auth_service.dart';
import 'screens/group_preview_screen.dart';
import 'state/app_state.dart';
import 'state/audio_player_state.dart';
import 'state/streak_state.dart';
import 'theme/app_theme.dart';
import 'config.dart';
import 'widgets/splash_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.dark,
      systemNavigationBarDividerColor: Colors.transparent,
    ),
  );
  // ONE initialize() for the shared FlutterLocalNotificationsPlugin singleton
  // — every notification service routes taps through NotificationRouter.
  // A per-service initialize() stole the tap callback from the others.
  await NotificationRouter.instance.ensureInitialized();
  await PrayerNotificationService.instance.init();
  await DuaNotificationService.instance.init();
  await WazifaNotificationService.instance.init();
  await AyahNotificationService.instance.init();
  // Firebase powers passwordless (magic link) auth for the Streak system.
  // Failure must never block the rest of the app.
  try {
    await FirebaseAuthService.instance.ensureInitialized();
  } catch (_) {}
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppState()..load()),
        ChangeNotifierProvider(create: (_) => StreakState()),
        ChangeNotifierProvider(create: (_) => AudioPlayerState()),
        ChangeNotifierProvider(create: (_) => AzkarAudioProvider()),
        ChangeNotifierProvider(create: (_) => AdhkarService.instance..ensureTranslations()),
        ChangeNotifierProvider(create: (_) => QuranTranslationProvider()),
        ChangeNotifierProvider(create: (_) => TafsirProvider()),
        Provider(create: (_) => AuthService.instance),
      ],
      child: const SajdaApp(),
    ),
  );
}

class SajdaApp extends StatelessWidget {
  const SajdaApp({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    if (!state.loaded) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: state.themeMode,
        home: const Scaffold(body: Center(child: CircularProgressIndicator())),
      );
    }

    final isUrdu = state.isUrdu;
    final lang = state.language;

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Sajda: Daily Athan & Qibla',
      // Notification taps route through this key (NotificationRouter).
      navigatorKey: NotificationRouter.navigatorKey,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: state.themeMode,
      locale: lang == 'en' ? const Locale('en') : Locale(lang),
      supportedLocales:
          AppStrings.supportedLanguages.map((l) => Locale(l.code)).toList(),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) {
        // Keep status / nav bar icons readable as the theme switches
        // (including system-default mode, which can flip mid-session).
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness:
                isDark ? Brightness.light : Brightness.dark,
            statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
            systemNavigationBarColor: Colors.transparent,
            systemNavigationBarIconBrightness:
                isDark ? Brightness.light : Brightness.dark,
            systemNavigationBarDividerColor: Colors.transparent,
          ),
          child: SafeArea(
            // Edge-to-edge is on, so keep the WHOLE app above the system
            // navigation bar: devices with a navbar get their content
            // lifted above it (padding.bottom > 0), devices without one
            // have padding.bottom == 0 and stay truly full screen. Top is
            // left to each screen's AppBar/SafeArea.
            top: false,
            bottom: true,
            child: Directionality(
              textDirection: isUrdu ? TextDirection.rtl : TextDirection.ltr,
              child: child ?? const SizedBox.shrink(),
            ),
          ),
        );
      },
      home: const _Root(),
    );
  }
}

class _Root extends StatefulWidget {
  const _Root();

  @override
  State<_Root> createState() => _RootState();
}

class _RootState extends State<_Root> {
  bool _showSplash = true;
  StreamSubscription<String>? _linkSub;
  bool _handlingLink = false;
  bool _handlingAuthLink = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initDeepLinks());
  }

  void _initDeepLinks() {
    DeepLinkService.instance.start();
    _linkSub = DeepLinkService.instance.links.listen(_handleLink);
  }

  void _handleLink(String link) {
    // Firebase magic link (passwordless sign-in) takes priority — it can
    // arrive while the user is anywhere in the app.
    if (FirebaseAuthService.instance.isSignInLink(link)) {
      _handleMagicLink(link);
      return;
    }
    final restore = DeepLinkService.instance.restoreFromLink(link);
    if (restore != null) {
      _handleRestoreLink(restore);
      return;
    }
    if (_handlingLink) return;
    _handlingLink = true;
    try {
      final code = DeepLinkService.instance.codeFromLink(link);
      if (code == null) return;
      final app = context.read<AppState>();
      if (!app.isAuthenticated) return; // gate handled in Streak tab
      final navigator = Navigator.of(context, rootNavigator: true);
      navigator.push(
        MaterialPageRoute(builder: (_) => GroupPreviewScreen(inviteCode: code)),
      );
    } finally {
      _handlingLink = false;
    }
  }

  /// Completes magic-link sign-in, exchanges the Firebase ID token on our
  /// backend (binding streak data to the verified identity) and boots the
  /// streak state.
  Future<void> _handleMagicLink(String link) async {
    if (_handlingAuthLink) return;
    _handlingAuthLink = true;
    String? error;
    try {
      error = await FirebaseAuthService.instance.tryCompleteSignIn(link);
      if (error == null) {
        final token = await FirebaseAuthService.instance.idToken;
        final name = await FirebaseAuthService.takePendingName();
        if (token == null) {
          error = 'session_missing';
        } else {
          error = await AuthService.instance.exchangeFirebaseToken(
            idToken: token,
            displayName: name,
          );
        }
      }
    } finally {
      _handlingAuthLink = false;
    }
    await FirebaseAuthService.clearPending();
    if (!mounted) return;
    final app = context.read<AppState>();
    if (error == null) {
      app.adoptFirebaseSession();
      unawaited(context.read<StreakState>().initialize());
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error == null
              ? app.t('Signed in — welcome!', 'داخل ہو گیا — خوش آمدید!')
              : app.t('Sign-in failed: $error', 'داخلہ ناکام: $error')),
        ),
      );
    }
  }

  Future<void> _handleRestoreLink(RestoreLink link) async {
    final app = context.read<AppState>();
    final error = await AuthService.instance.restoreWithToken(
      token: link.token,
      userId: link.userId,
      displayName: link.displayName,
    );
    if (!mounted) return;
    final isUrdu = app.isUrdu;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(error == null
            ? app.t('Account restored', 'اکاؤنٹ بحال ہو گیا')
            : app.t('Restore failed', 'بحالی ناکام')),
        content: Text(
          error ??
              app.t(
                  'Signed in as ${link.displayName}. Please close and reopen the app.',
                  '${link.displayName} کے طور پر داخل ہو گئے۔ براہ کرم ایپ بند کر کے دوبارہ کھولیں۔'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(isUrdu ? 'ٹھیک ہے' : 'OK'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _linkSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    if (!state.loaded) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_showSplash) {
      return PopScope(
        canPop: false,
        child: SplashScreen(onDone: () => setState(() => _showSplash = false)),
      );
    }
    if (!state.onboardingDone) {
      return const PopScope(canPop: false, child: OnboardingScreen());
    }
    if (!state.locationConfigured) {
      return const PopScope(canPop: false, child: LocationSetupScreen());
    }
    return const PopScope(canPop: true, child: MainShell());
  }
}
