import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/quiz_service.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../utils/share_image.dart';

/// F5 — daily 10-question Islamic quiz.
class QuizScreen extends StatefulWidget {
  const QuizScreen({super.key});

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  late final String _day;
  late final List<QuizQuestion> _questions;
  QuizProgress? _progress;
  bool _loading = true;
  bool _playing = false;
  bool _finished = false;
  int _index = 0;
  int _correct = 0;
  int? _selected;

  @override
  void initState() {
    super.initState();
    _day = QuizService.dayKey(DateTime.now());
    _questions = QuizService.instance.dailyQuestions();
    _load();
  }

  Future<void> _load() async {
    final progress = await QuizService.instance.loadProgress();
    if (!mounted) return;
    setState(() {
      _progress = progress;
      _loading = false;
    });
  }

  void _start() {
    setState(() {
      _playing = true;
      _finished = false;
      _index = 0;
      _correct = 0;
      _selected = null;
    });
  }

  Future<void> _finish() async {
    final progress = await QuizService.instance.submit(
      day: _day,
      correct: _correct,
      total: _questions.length,
    );
    if (!mounted) return;
    setState(() {
      _progress = progress;
      _playing = false;
      _finished = true;
    });
  }

  void _choose(int i) {
    if (_selected != null) return;
    setState(() {
      _selected = i;
      if (i == _questions[_index].correctIndex) _correct++;
    });
  }

  void _next() {
    if (_index + 1 >= _questions.length) {
      _finish();
      return;
    }
    setState(() {
      _index++;
      _selected = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final completedToday = _progress?.completedOn(_day) ?? false;

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        title: Text(app.t('Daily Islamic Quiz', 'روزانہ اسلامی کوئز')),
        actions: [
          if (_playing)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Text(
                  '${_index + 1}/${_questions.length}',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _playing
              ? _buildQuestion(context, app, isDark)
              : _buildIntroOrResult(
                  context, app, isDark, completedToday || _finished),
    );
  }

  Widget _buildQuestion(BuildContext context, AppState app, bool isDark) {
    final question = _questions[_index];
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: (_index + 1) / _questions.length,
            minHeight: 8,
            backgroundColor:
                isDark ? AppColors.darkSurfaceAlt : AppColors.lightBorder,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: 22),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(30),
          ),
          child: Text(
            question.category.toUpperCase(),
            style: const TextStyle(
              color: AppColors.primaryDark,
              fontSize: 10,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          question.prompt,
          style: const TextStyle(
            fontSize: 23,
            height: 1.35,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 26),
        ...List.generate(question.options.length, (i) {
          final isCorrect = i == question.correctIndex;
          final isSelected = i == _selected;
          Color? border;
          Color? fill;
          if (_selected != null) {
            if (isCorrect) {
              border = AppColors.success;
              fill = AppColors.success.withValues(alpha: 0.12);
            } else if (isSelected) {
              border = AppColors.danger;
              fill = AppColors.danger.withValues(alpha: 0.12);
            }
          }
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => _choose(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                decoration: BoxDecoration(
                  color: fill ??
                      (isDark ? AppColors.darkSurface : AppColors.lightCard),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: border ??
                        (isDark
                            ? AppColors.darkSurfaceAlt
                            : AppColors.lightBorder),
                    width: border != null ? 1.6 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 30,
                      height: 30,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.primary.withValues(alpha: 0.1),
                      ),
                      child: Text(
                        String.fromCharCode(65 + i),
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        question.options[i],
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (_selected != null && isCorrect)
                      const Icon(Icons.check_circle_rounded,
                          color: AppColors.success),
                    if (_selected != null && isSelected && !isCorrect)
                      const Icon(Icons.cancel_rounded,
                          color: AppColors.danger),
                  ],
                ),
              ),
            ),
          );
        }),
        const SizedBox(height: 10),
        if (_selected != null)
          FilledButton(
            onPressed: _next,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: Text(
              _index + 1 >= _questions.length
                  ? app.t('See result', 'نتیجہ دیکھیں')
                  : app.t('Next question', 'اگلا سوال'),
            ),
          ),
      ],
    );
  }

  Widget _buildIntroOrResult(
    BuildContext context,
    AppState app,
    bool isDark,
    bool completed,
  ) {
    final progress = _progress;
    final score = _finished ? _correct : (progress?.lastScore ?? 0);
    final total = _questions.length;
    final isResult = completed || _finished;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(26),
            gradient: const LinearGradient(
              colors: [AppColors.primaryDeep, AppColors.primary],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Column(
            children: [
              const Icon(Icons.psychology_rounded,
                  color: Colors.white, size: 54),
              const SizedBox(height: 14),
              Text(
                isResult
                    ? app.t('Today\'s quiz complete', 'آج کا کوئز مکمل')
                    : app.t('Quiz of the Day', 'آج کا کوئز'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                isResult
                    ? app.t(
                        'You answered $score of $total correctly.',
                        'آپ نے $total میں سے $score درست جواب دیے۔',
                      )
                    : app.t(
                        '10 questions from the Quran, refreshed every day.',
                        'قرآن سے 10 سوالات، ہر روز نئے۔',
                      ),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.82),
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
              if (isResult) ...[
                const SizedBox(height: 22),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _resultStat('$score/$total',
                        app.t('Score', 'اسکور')),
                    const SizedBox(width: 28),
                    _resultStat('${progress?.streak ?? 0}',
                        app.t('Day streak', 'روز کا سلسلہ')),
                    const SizedBox(width: 28),
                    _resultStat('${progress?.bestScore ?? 0}',
                        app.t('Best', 'بہترین')),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 18),
        if (!isResult)
          FilledButton.icon(
            onPressed: _start,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(54),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            icon: const Icon(Icons.play_arrow_rounded),
            label: Text(app.t('Start quiz', 'کوئز شروع کریں')),
          )
        else ...[
          OutlinedButton.icon(
            onPressed: () => shareWidgetAsImage(
              context: context,
              widget: _QuizShareCard(
                score: score,
                total: total,
                streak: progress?.streak ?? 0,
                best: progress?.bestScore ?? 0,
                isUrdu: app.isUrdu,
              ),
              fileName: 'sajda_quiz_result',
              caption:
                  '${app.t('I scored $score/$total on the Sajda daily quiz!', 'میں نے سجدة کے روزانہ کوئز میں $score/$total اسکور کیا!')}\n'
                  'https://play.google.com/store/apps/details?id=com.sajda.dataplus',
            ),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            icon: const Icon(Icons.ios_share_rounded),
            label: Text(app.t('Share result', 'نتیجہ شیئر کریں')),
          ),
          const SizedBox(height: 10),
          Text(
            app.t(
              'A new quiz unlocks at midnight. Come back tomorrow!',
              'آدھی رات کو نیا کوئز آئے گا۔ کل دوبارہ آئیں!',
            ),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        const SizedBox(height: 26),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : AppColors.lightCard,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isDark ? AppColors.darkSurfaceAlt : AppColors.lightBorder,
            ),
          ),
          child: Row(
            children: [
              const Icon(Icons.info_outline_rounded,
                  color: AppColors.primary, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  app.t(
                    'Questions are generated offline from the Quran data already in the app.',
                    'سوالات ایپ میں موجود قرآنی ڈیٹا سے آف لائن بنائے جاتے ہیں۔',
                  ),
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.4,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _resultStat(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 21,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 10,
          ),
        ),
      ],
    );
  }
}

class _QuizShareCard extends StatelessWidget {
  final int score;
  final int total;
  final int streak;
  final int best;
  final bool isUrdu;

  const _QuizShareCard({
    required this.score,
    required this.total,
    required this.streak,
    required this.best,
    required this.isUrdu,
  });

  @override
  Widget build(BuildContext context) {
    final pct = total == 0 ? 0 : ((score / total) * 100).round();
    return Container(
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [Color(0xFF123C33), Color(0xFF0B211A)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.mosque_rounded, color: Colors.white70, size: 18),
              const SizedBox(width: 6),
              Text(
                'SAJDA',
                style: TextStyle(
                  letterSpacing: 3,
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                  color: Colors.white.withValues(alpha: 0.85),
                ),
              ),
              const Spacer(),
              Text(
                isUrdu ? 'روزانہ کوئز' : 'DAILY QUIZ',
                style: TextStyle(
                  letterSpacing: 1.5,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: Colors.white.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
          const SizedBox(height: 34),
          Container(
            width: 150,
            height: 150,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [AppColors.primary, AppColors.primaryDark],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.4),
                  blurRadius: 34,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '$score/$total',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 34,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  '$pct%',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.72),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          Text(
            isUrdu
                ? 'میں نے آج کا اسلامی کوئز مکمل کیا!'
                : 'I completed today\'s Islamic quiz!',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _stat('$streak', isUrdu ? 'دن کا سلسلہ' : 'DAY STREAK'),
              const SizedBox(width: 36),
              _stat('$best', isUrdu ? 'بہترین' : 'BEST SCORE'),
            ],
          ),
          const SizedBox(height: 32),
          Text(
            isUrdu ? 'سجدة • روزانہ اذان اور قبلہ' : 'Sajda • Daily Athan & Qibla',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.55),
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'play.google.com/store/apps/details?id=com.sajda.dataplus',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.35),
              fontSize: 8,
            ),
          ),
        ],
      ),
    );
  }

  Widget _stat(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.55),
            fontSize: 9,
            letterSpacing: 1.1,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
