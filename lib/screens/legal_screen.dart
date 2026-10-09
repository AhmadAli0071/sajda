import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../state/app_state.dart';
import '../theme/app_theme.dart';

class LegalScreen extends StatelessWidget {
  const LegalScreen({super.key});

  static const _privacyPolicyUrl = String.fromEnvironment(
    'PRIVACY_POLICY_URL',
    defaultValue: 'https://sajdapolicy.57.129.161.5.nip.io',
  );

  static const _deleteAccountUrl = String.fromEnvironment(
    'DELETE_ACCOUNT_URL',
    defaultValue: 'https://sajdapolicy.57.129.161.5.nip.io/delete-account/',
  );

  Future<void> _openDeleteAccount(BuildContext context) async {
    final state = context.read<AppState>();
    final uri = Uri.tryParse(_deleteAccountUrl);
    if (uri == null) return;
    try {
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched) {
        if (!context.mounted) return;
        showAppSnack(
          context,
          state.t('Could not open deletion page link.', 'اکاؤنٹ ڈیلیٹ صفحہ کھولنے میں مسئلہ۔'),
          error: true,
        );
      }
    } catch (_) {
      if (!context.mounted) return;
      showAppSnack(
        context,
        state.t('Could not open deletion page link.', 'اکاؤنٹ ڈیلیٹ صفحہ کھولنے میں مسئلہ۔'),
        error: true,
      );
    }
  }

  Future<void> _openPrivacyPolicy(BuildContext context) async {
    final state = context.read<AppState>();
    final uri = Uri.tryParse(_privacyPolicyUrl);
    if (uri == null) return;
    try {
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched) {
        if (!context.mounted) return;
        showAppSnack(
          context,
          state.t('Could not open privacy policy link.', 'رازداری کی پالیسی کھولنے میں مسئلہ۔'),
          error: true,
        );
      }
    } catch (_) {
      if (!context.mounted) return;
      showAppSnack(
        context,
        state.t('Could not open privacy policy link.', 'رازداری کی پالیسی کھولنے میں مسئلہ۔'),
        error: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(state.t('Legal & Attributions', 'قانونی اور تشریحات'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(state.t('Privacy Policy', 'رازداری کی پالیسی'), style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                Text(
                  state.t(
                    'Read our privacy policy to understand how we handle your data.',
                    'ہمارے ڈیٹا کے ساتھ کیا کیا جاتا ہے سمجھنے کے لیے رازداری کی پالیسی پڑھیں۔',
                  ),
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: () => _openPrivacyPolicy(context),
                  icon: const Icon(Icons.open_in_new_rounded),
                  label: Text(state.t('Open Privacy Policy', 'رازداری کی پالیسی کھولیں')),
                ),
                const SizedBox(height: 10),
                Text(
                  state.t(
                    'Want to delete your account and data? Use the web deletion page — no app required.',
                    'اپنا اکاؤنٹ اور ڈیٹا ڈیلیٹ کرنا چاہتے ہیں؟ ویب ڈیلیشن صفحہ استعمال کریں — ایپ کی ضرورت نہیں۔',
                  ),
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () => _openDeleteAccount(context),
                  icon: const Icon(Icons.delete_outline_rounded),
                  label: Text(state.t('Delete Account (Web)', 'اکاؤنٹ ڈیلیٹ کریں (ویب)')),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(state.t('Open-Source Licenses', 'اوپن سورس لائسنسز'), style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                Text(
                  state.t(
                    'This app uses the following open-source packages and datasets:',
                    'اس ایپ میں درج ذیل اوپن سورس پیکجوں اور ڈیٹا سیٹس استعمال کئے گئے ہیں:',
                  ),
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 10),
                _licenseRow('Flutter SDK', 'BSD-3', 'https://flutter.dev'),
                _licenseRow('provider', 'MIT', 'https://pub.dev/packages/provider'),
                _licenseRow('http', 'BSD-3', 'https://pub.dev/packages/http'),
                _licenseRow('shared_preferences', 'BSD-3', 'https://pub.dev/packages/shared_preferences'),
                _licenseRow('geolocator', 'MIT', 'https://pub.dev/packages/geolocator'),
                _licenseRow('flutter_compass', 'MIT', 'https://pub.dev/packages/flutter_compass'),
                _licenseRow('flutter_local_notifications', 'BSD-3', 'https://pub.dev/packages/flutter_local_notifications'),
                _licenseRow('timezone', 'BSD-3', 'https://pub.dev/packages/timezone'),
                _licenseRow('flutter_timezone', 'MIT', 'https://pub.dev/packages/flutter_timezone'),
                _licenseRow('quran', 'MIT', 'https://pub.dev/packages/quran'),
                _licenseRow('just_audio', 'MIT', 'https://pub.dev/packages/just_audio'),
                _licenseRow('audio_service', 'MIT', 'https://pub.dev/packages/audio_service'),
                _licenseRow('share_plus', 'MIT', 'https://pub.dev/packages/share_plus'),
                _licenseRow('wakelock_plus', 'MIT', 'https://pub.dev/packages/wakelock_plus'),
                _licenseRow('url_launcher', 'BSD-3', 'https://pub.dev/packages/url_launcher'),
                _licenseRow('in_app_review', 'BSD-3', 'https://pub.dev/packages/in_app_review'),
                _licenseRow('path_provider', 'BSD-3', 'https://pub.dev/packages/path_provider'),
                _licenseRow('flutter_map', 'BSD-3', 'https://pub.dev/packages/flutter_map'),
                _licenseRow('latlong2', 'BSD-2', 'https://pub.dev/packages/latlong2'),
                _licenseRow('hijri', 'MIT', 'https://pub.dev/packages/hijri'),
                _licenseRow('timezone_finder', 'MIT', 'https://pub.dev/packages/timezone_finder'),
                _licenseRow('uuid', 'MIT', 'https://pub.dev/packages/uuid'),
                _licenseRow('intl', 'BSD-3', 'https://pub.dev/packages/intl'),
                _licenseRow('flutter_localizations', 'BSD-3', 'https://flutter.dev'),
                const SizedBox(height: 12),
                 Text(
                   state.t('Content Attribution', 'مواد کی تشریح'),
                   style: theme.textTheme.titleSmall,
                 ),
                 const SizedBox(height: 6),
                     Text(
                       state.t(
                          'Quran text provided by Tanzil Project. Tanzil Quran Text is used under Creative Commons Attribution 3.0. https://tanzil.net/ Quran translations and Tafsir provided by Quran Foundation Content API. Ayat of the Day translations sourced via the Al Quran Cloud API (https://alquran.cloud) from published editions: Fateh Muhammad Jalandhry (Urdu), Saheeh International (English), Suhel Farooq Khan & Saifur Rahman Nadwi (Hindi), Kemenag (Indonesian). Adhkar (Hisnul Muslim) translations into Urdu, English, Hindi and Indonesian are generated using AI translation tools. Quran audio recitations provided by the Al Quran Cloud API (https://alquran.cloud) and streamed from the islamic.network CDN, which distributes them freely for public use. Live Quran Radio streams provided by MP3Quran.net (qurango.net). Adhan audio: Aishatu98, Wikimedia Commons, released under CC0 1.0 Universal. Source: https://commons.wikimedia.org/wiki/File:Adhan.ogg',
                          'قرآن کی تحریر Tanzil Project کی طرف سے فراہم کی گئی ہے۔ Tanzil Quran Text کو Creative Commons Attribution 3.0 کے تحت استعمال کیا جاتا ہے۔ https://tanzil.net/ قرآن کے ترجمے اور تفسیر Quran Foundation Content API کی طرف سے فراہم کیے گئے ہیں۔ آج کی آیت کے ترجمے Al Quran Cloud API (https://alquran.cloud) کے ذریعے شائع شدہ ایڈیشنز سے لیے گئے ہیں: فتح محمد جالندھری (اردو)، Saheeh International (انگریزی)، سہیل فاروق خان و سیف الرحمٰن ندوی (ہندی)، کیمیناگ (انڈونیشیائی)۔ اذکار (حصن مسلم) کے اردو، انگریزی، ہندی اور انڈونیشیائی ترجمے AI ترجمہ ٹولز کے ذریعے تیار کیے گئے ہیں۔ قرآن کی آڈیو تلاوتات Al Quran Cloud API (https://alquran.cloud) کی طرف سے فراہم کی جاتی ہیں اور islamic.network CDN سے اسٹریم ہوتی ہیں جو انہیں عوامی استعمال کے لیے آزادانہ طور پر تقسیم کرتا ہے۔ لائیو قرآن ریڈیو کی نشریات MP3Quran.net (qurango.net) فراہم کرتا ہے۔ آذان کا آڈیو: عیشتو۸، ویکیمیڈیا کامنز، CC0 1.0 universal کے تحت۔ ماخذ: https://commons.wikimedia.org/wiki/File:Adhan.ogg',
                       ),
                    style: theme.textTheme.bodySmall,
                  ),
                 const SizedBox(height: 8),
                 Text(
                   state.t(
                     'If you believe any content violates copyright, contact us for removal.',
                     'اگر آپ کو لگتا ہے کہ کسی مواد کا copyright خلاف ورزی کر رہا ہے، تو ہم سے رابطہ کریں۔',
                   ),
                   style: theme.textTheme.bodySmall,
                 ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(state.t('App Version', 'ایپ ورژن'), style: theme.textTheme.titleMedium),
                const SizedBox(height: 6),
                Text('Sajda: Daily Athan & Qibla v1.0.3', style: theme.textTheme.bodySmall),
                Text('Package: com.sajda.dataplus', style: theme.textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _licenseRow(String name, String license, String url) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(child: Text(name, style: const TextStyle(fontSize: 13))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(license, style: const TextStyle(fontSize: 11, color: AppColors.primary)),
          ),
        ],
      ),
    );
  }
}



