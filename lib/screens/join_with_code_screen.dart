import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/streak_v2_api.dart';
import '../state/app_state.dart';
import '../services/api_client.dart';
import '../theme/app_theme.dart';
import 'discover_groups_screen.dart';
import 'group_preview_screen.dart';

/// Join a group by typing its 6-character invite code (direct join).
class JoinWithCodeScreen extends StatefulWidget {
  const JoinWithCodeScreen({super.key});

  @override
  State<JoinWithCodeScreen> createState() => _JoinWithCodeScreenState();
}

class _JoinWithCodeScreenState extends State<JoinWithCodeScreen> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  String get _code => _controller.text.trim().toUpperCase();

  Future<void> _preview() async {
    final app = context.read<AppState>();
    if (_code.length != 6) {
      setState(() => _error = app.t('Enter the 6-character code', '۶ حروف کا کوڈ درج کریں'));
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final preview = await StreakV2Api.instance.getInvitePreview(_code);
      if (!mounted) return;
      setState(() => _busy = false);
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => GroupPreviewScreen(
            inviteCode: _code,
            initialPreview: preview,
          ),
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.isNetworkError
            ? app.t('No connection. Check your internet.', 'انٹرنیٹ نہیں چل رہا۔')
            : (e.code == 'INVALID_INVITE'
                ? app.t('That code doesn\u2019t exist. Check and try again.', 'یہ کوڈ موجود نہیں۔ دوبارہ کوشش کریں۔')
                : e.message);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: isDark ? AppColors.darkText : AppColors.lightText),
        title: Text(
          app.t('Join with code', 'کوڈ سے شامل ہوں'),
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: isDark ? AppColors.darkText : AppColors.lightText,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const SizedBox(height: 12),
          Icon(
            Icons.vpn_key_rounded,
            size: 56,
            color: AppColors.primary,
          ),
          const SizedBox(height: 18),
          Text(
            app.t('Have an invite code?', 'انوائٹ کوڈ ہے؟'),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w800,
              color: isDark ? AppColors.darkText : AppColors.lightText,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            app.t(
              'Ask a friend to share their group code, then enter it below.',
              'دوست سے گروپ کا کوڈ لیں اور نیچے درج کریں۔',
            ),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13.5,
              height: 1.5,
              color: isDark ? AppColors.darkMuted : AppColors.lightSecondaryText,
            ),
          ),
          const SizedBox(height: 28),
          TextField(
            controller: _controller,
            focusNode: _focus,
            autofocus: true,
            textAlign: TextAlign.center,
            maxLength: 6,
            textCapitalization: TextCapitalization.characters,
            style: TextStyle(
              fontSize: 26,
              letterSpacing: 8,
              fontWeight: FontWeight.w800,
              color: isDark ? AppColors.darkText : AppColors.lightText,
            ),
            decoration: InputDecoration(
              counterText: '',
              hintText: 'ABC123',
              hintStyle: TextStyle(
                color: isDark ? AppColors.darkMuted : AppColors.lightMutedText,
                letterSpacing: 8,
              ),
              filled: true,
              fillColor: isDark ? AppColors.darkSurface : AppColors.lightCard,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: isDark ? AppColors.darkSurfaceAlt : AppColors.lightBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: isDark ? AppColors.darkSurfaceAlt : AppColors.lightBorder),
              ),
            ),
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => _preview(),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: AppColors.danger, fontWeight: FontWeight.w600),
            ),
          ],
          const SizedBox(height: 20),
          SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: (_busy || _code.length != 6) ? null : _preview,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.4),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: _busy
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                  : Text(
                      app.t('Continue', 'جاری رکھیں'),
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
            ),
          ),
          const SizedBox(height: 24),
          Center(
            child: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const DiscoverGroupsScreen()),
              ),
              child: Text(
                app.t('Or search public groups', 'یا عوامی گروپ تلاش کریں'),
                style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppColors.primary),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
