import 'package:flutter/material.dart';
import '../models/why_data.dart';
import '../services/firestore_service.dart';
import '../services/notification_service.dart';
import '../utils/habit_utils.dart';

class WhyOnboardingScreen extends StatefulWidget {
  final String uid;
  final String habitId;
  final String habitName;

  const WhyOnboardingScreen({
    super.key,
    required this.uid,
    required this.habitId,
    required this.habitName,
  });

  @override
  State<WhyOnboardingScreen> createState() => _WhyOnboardingScreenState();
}

class _WhyOnboardingScreenState extends State<WhyOnboardingScreen> {
  int _step = 0; // 0–4 = questions, 5 = WHY card
  final List<String> _answers = ['', '', '', '', ''];
  final _ctrl = TextEditingController();
  String? _error;
  bool _saving = false;
  WhyData? _result;

  // ── Validation ──────────────────────────────────────────────────────────────

  static const _genericWords = {
    'better', 'improve', 'good', 'great', 'nice', 'more', 'less', 'healthy',
    'fit', 'productive', 'success', 'successful', 'growth', 'motivation',
    'motivated', 'discipline', 'disciplined', 'best', 'stronger', 'smarter',
  };
  static const _stopwords = {
    'i', 'want', 'to', 'be', 'a', 'an', 'the', 'my', 'and', 'or', 'for',
    'of', 'in', 'on', 'at', 'it', 'is', 'me', 'you', 'we', 'us', 'so',
    'that', 'this', 'with', 'have', 'will', 'just', 'get', 'can', 'do',
    'am', 'are', 'was', 'were', 'been', 'being', 'need', 'make',
  };

  List<String> _words(String text) =>
      text.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();

  bool _isValid() {
    final words = _words(_ctrl.text);
    switch (_step) {
      case 0: // min 10 words
        return words.length >= 10;
      case 1: // must have ≥2 words that are neither stopwords nor generic
        final meaningful =
            words.where((w) => !_stopwords.contains(w.toLowerCase())).toList();
        final specific = meaningful
            .where((w) => !_genericWords.contains(w.toLowerCase()))
            .toList();
        return specific.length >= 2;
      case 2: // min 15 words
        return words.length >= 15;
      case 3: // min 10 words
        return words.length >= 10;
      case 4: // min 10 words
        return words.length >= 10;
      default:
        return true;
    }
  }

  String get _rejectionMessage {
    switch (_step) {
      case 0:
        return "That's a goal, not a reason. Go deeper.";
      case 1:
        return "Better than what? Be specific about where you are right now.";
      case 2:
        return "You're being vague. What has this actually cost you?";
      case 3:
        return "Describe that person concretely. Who are they, specifically?";
      case 4:
        return "Go deeper. A real answer has substance.";
      default:
        return '';
    }
  }

  String get _question {
    switch (_step) {
      case 0:
        return "What do you want this habit to give you?";
      case 1:
        return "Why does that matter to you right now, specifically?";
      case 2:
        return "What has NOT having this already cost you? Be honest.";
      case 3:
        return "Who are you becoming by doing this daily? Describe that person.";
      case 4:
        return q5For(widget.habitName);
      default:
        return '';
    }
  }

  // ── Navigation ──────────────────────────────────────────────────────────────

  void _goBack(BuildContext context) {
    if (_step == 0) {
      Navigator.of(context).pop();
    } else {
      setState(() {
        _step--;
        _ctrl.text = _answers[_step];
        _error = null;
      });
    }
  }

  void _advance() {
    if (!_isValid()) {
      setState(() => _error = _rejectionMessage);
      return;
    }
    final answer = _ctrl.text.trim();
    final wasLast = _step == 4;
    setState(() {
      _error = null;
      _answers[_step] = answer;
      if (!wasLast) {
        _step++;
        _ctrl.clear();
      }
    });
    if (wasLast) _save();
  }

  // ── Storage ─────────────────────────────────────────────────────────────────

  Future<void> _save() async {
    setState(() => _saving = true);

    final statement = _buildStatement();
    final why = WhyData(
      q1: _answers[0],
      q2: _answers[1],
      q3: _answers[2],
      q4: _answers[3],
      q5: _answers[4],
      statement: statement,
      completedAt: DateTime.now(),
    );

    await FirestoreService.saveWhyData(widget.uid, widget.habitId, why);
    await NotificationService.saveCostLine(
        widget.habitName, _condense(_answers[2], 12));

    if (mounted) {
      setState(() {
        _saving = false;
        _result = why;
        _step = 5;
      });
    }
  }

  String _condense(String text, int maxWords) {
    final words = _words(text);
    if (words.length <= maxWords) return text;
    return '${words.take(maxWords).join(' ')}...';
  }

  String _buildStatement() {
    final q2c = _condense(_answers[1], 20);
    final q3c = _condense(_answers[2], 15);
    final q4c = _condense(_answers[3], 15);
    return "You are doing ${widget.habitName} because $q2c. "
        "The version of you that skips this $q3c. "
        "The person you are becoming $q4c.";
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // Block all system/gesture back navigation for the entire flow
    return PopScope(
      canPop: _step == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _step > 0) _goBack(context);
      },
      child: _step == 5 && _result != null
          ? _WhyCardScreen(
              habitName: widget.habitName,
              why: _result!,
              onDone: () => Navigator.of(context).pop(_result),
            )
          : _QuestionScreen(
              step: _step,
              question: _question,
              error: _error,
              ctrl: _ctrl,
              saving: _saving,
              isLastQuestion: _step == 4,
              habitName: widget.habitName,
              onAdvance: _advance,
              onBack: () => _goBack(context),
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
            ),
    );
  }
}

// ── Question screen ──────────────────────────────────────────────────────────

class _QuestionScreen extends StatelessWidget {
  final int step;
  final String question;
  final String? error;
  final TextEditingController ctrl;
  final bool saving;
  final bool isLastQuestion;
  final String habitName;
  final VoidCallback onAdvance;
  final VoidCallback onBack;
  final ValueChanged<String> onChanged;

  const _QuestionScreen({
    required this.step,
    required this.question,
    required this.error,
    required this.ctrl,
    required this.saving,
    required this.isLastQuestion,
    required this.habitName,
    required this.onAdvance,
    required this.onBack,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D1A),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Top bar: progress only, no back button ─────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 16, 20, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new,
                        color: Colors.white54, size: 18),
                    onPressed: onBack,
                    splashRadius: 20,
                    tooltip: step == 0 ? 'Exit' : 'Previous question',
                  ),
                  Text(
                    'Question ${step + 1} of 5',
                    style: const TextStyle(
                        color: Colors.white38, fontSize: 13),
                  ),
                  // Dot indicators
                  Row(
                    children: List.generate(5, (i) {
                      final filled = i <= step;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.only(left: 5),
                        width: filled ? 18 : 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: filled
                              ? const Color(0xFFFF6B35)
                              : const Color(0xFF2A2A4A),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      );
                    }),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            // Progress bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: (step + 1) / 5,
                  minHeight: 2,
                  backgroundColor: const Color(0xFF2A2A4A),
                  valueColor:
                      const AlwaysStoppedAnimation(Color(0xFFFF6B35)),
                ),
              ),
            ),
            const SizedBox(height: 28),
            // Habit context chip
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A2E),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: const Color(0xFFFF6B35).withValues(alpha: 0.45)),
                ),
                child: Text(
                  habitName,
                  style: const TextStyle(
                    color: Color(0xFFFF6B35),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            // Question — slides in from the right on each step change
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 240),
                transitionBuilder: (child, anim) => SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0.08, 0),
                    end: Offset.zero,
                  ).animate(
                      CurvedAnimation(parent: anim, curve: Curves.easeOut)),
                  child: FadeTransition(opacity: anim, child: child),
                ),
                child: Text(
                  question,
                  key: ValueKey(step),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    height: 1.35,
                  ),
                ),
              ),
            ),
            // Rejection message — animates in/out
            AnimatedSize(
              duration: const Duration(milliseconds: 160),
              child: error != null
                  ? Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.error_outline,
                              color: Color(0xFFFF5555), size: 15),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              error!,
                              style: const TextStyle(
                                color: Color(0xFFFF5555),
                                fontSize: 13,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  : const SizedBox(height: 12),
            ),
            const SizedBox(height: 12),
            // Answer text field — expands to fill space
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: TextField(
                  controller: ctrl,
                  autofocus: true,
                  maxLines: null,
                  expands: true,
                  textAlignVertical: TextAlignVertical.top,
                  style: const TextStyle(
                      color: Colors.white, fontSize: 17, height: 1.65),
                  decoration: const InputDecoration(
                    hintText: 'Type your answer here...',
                    hintStyle: TextStyle(color: Colors.white24, fontSize: 15),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                  onChanged: onChanged,
                ),
              ),
            ),
            // Continue / finish button
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              child: SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: saving ? null : onAdvance,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF6B35),
                    disabledBackgroundColor: const Color(0xFF3A2A20),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    textStyle: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  child: saving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : Text(isLastQuestion ? 'See My Why' : 'Continue'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── WHY card ─────────────────────────────────────────────────────────────────

class _WhyCardScreen extends StatelessWidget {
  final String habitName;
  final WhyData why;
  final VoidCallback onDone;

  const _WhyCardScreen({
    required this.habitName,
    required this.why,
    required this.onDone,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D1A),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'YOUR WHY',
                style: TextStyle(
                  color: Color(0xFFFF6B35),
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2.5,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                habitName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 32),
              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1A2E),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: const Color(0xFFFF6B35).withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: SingleChildScrollView(
                          child: Text(
                            why.statement,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 19,
                              height: 1.75,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Divider(color: Colors.white12),
                      const SizedBox(height: 8),
                      Text(
                        _dateLabel(why.completedAt),
                        style: const TextStyle(
                            color: Colors.white24, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: onDone,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF6B35),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    textStyle: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  child: const Text('Start Logging This Habit'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _dateLabel(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return 'Committed ${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }
}
