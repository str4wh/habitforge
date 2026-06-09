import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../models/habit.dart';
import '../models/weekly_review.dart';
import '../services/firestore_service.dart';
import '../services/notification_service.dart';
import 'chakula_assessment_screen.dart';

// ── Validation helpers ────────────────────────────────────────────────────────

const _deflections = {'nothing', 'none', 'no excuse', 'n/a', 'na', 'nope'};

String? _validateExcuse(String text) {
  final trimmed = text.trim().toLowerCase();
  if (_deflections.any((d) => trimmed == d || trimmed.startsWith('$d ') ||
      trimmed.endsWith(' $d'))) {
    return 'Everyone has an excuse. What was yours this week? Be honest.';
  }
  final words = text.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
  if (words.length < 10) {
    return 'That is not an excuse, that is a deflection. Be specific.';
  }
  return null;
}

String? _validateWhyNotQuitting(String text) {
  final words = text.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
  if (words.length < 10) {
    return 'Ten words minimum. Why haven\'t you quit? Be honest.';
  }
  return null;
}

String? _validateWhatChanges(String text) {
  final words = text.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
  if (words.length < 5) {
    return 'One thing. Not a list. What changes next week?';
  }
  if (words.length > 20) {
    return 'One thing. Not a list. What changes next week?';
  }
  return null;
}

// ── Screen ────────────────────────────────────────────────────────────────────

class WeeklyReviewScreen extends StatefulWidget {
  final String uid;
  final List<Habit> habits;
  final String weekKey;

  const WeeklyReviewScreen({
    super.key,
    required this.uid,
    required this.habits,
    required this.weekKey,
  });

  @override
  State<WeeklyReviewScreen> createState() => _WeeklyReviewScreenState();
}

class _WeeklyReviewScreenState extends State<WeeklyReviewScreen> {
  int _step = 0; // 0, 1, 2

  // Q1
  final _excuseCtrl = TextEditingController();
  String? _excuseError;

  // Q2
  String? _habitAtRisk;
  final _whyNotCtrl = TextEditingController();
  String? _whyNotError;

  // Q3
  final _changesCtrl = TextEditingController();
  String? _changesError;

  bool _submitting = false;

  @override
  void dispose() {
    _excuseCtrl.dispose();
    _whyNotCtrl.dispose();
    _changesCtrl.dispose();
    super.dispose();
  }

  void _nextStep() {
    setState(() {
      _excuseError = null;
      _whyNotError = null;
      _changesError = null;
    });

    if (_step == 0) {
      final err = _validateExcuse(_excuseCtrl.text);
      if (err != null) {
        setState(() => _excuseError = err);
        return;
      }
      setState(() => _step = 1);
    } else if (_step == 1) {
      if (_habitAtRisk == null) {
        setState(() => _whyNotError = 'Select a habit first.');
        return;
      }
      final err = _validateWhyNotQuitting(_whyNotCtrl.text);
      if (err != null) {
        setState(() => _whyNotError = err);
        return;
      }
      setState(() => _step = 2);
    } else {
      _submit();
    }
  }

  Future<void> _submit() async {
    final err = _validateWhatChanges(_changesCtrl.text);
    if (err != null) {
      setState(() => _changesError = err);
      return;
    }
    setState(() => _submitting = true);

    final review = WeeklyReview(
      weekKey: widget.weekKey,
      biggestExcuse: _excuseCtrl.text.trim(),
      habitAtRisk: _habitAtRisk!,
      whyNotQuitting: _whyNotCtrl.text.trim(),
      whatChanges: _changesCtrl.text.trim(),
      completedAt: DateTime.now(),
    );

    await FirestoreService.saveWeeklyReview(widget.uid, widget.weekKey, review);
    if (!kIsWeb) await NotificationService.cancelWeeklyReviewReminder();

    if (!mounted) return;

    // On Sundays, transition to Chakula assessment (Step 3 of 3)
    if (DateTime.now().weekday == DateTime.sunday) {
      final alreadyDone = await FirestoreService.isChakulaAssessmentSubmitted(
          widget.uid, widget.weekKey);
      if (!alreadyDone && mounted) {
        await Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            fullscreenDialog: true,
            builder: (_) => ChakulaAssessmentScreen(
              uid: widget.uid,
              weekKey: widget.weekKey,
              isSundayFlow: true,
            ),
          ),
        );
        return;
      }
    }
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: const Color(0xFF070714),
        appBar: AppBar(
          backgroundColor: const Color(0xFF070714),
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          automaticallyImplyLeading: false,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (DateTime.now().weekday == DateTime.sunday)
                const Text(
                  'SUNDAY CHECK-IN · 2 OF 3',
                  style: TextStyle(
                      color: Color(0xFFFF6B35),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5),
                ),
              Row(
                children: [
                  const Text(
                    'WEEKLY REVIEW',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'Q${_step + 1} / 3',
                    style: const TextStyle(
                        color: Colors.white38, fontSize: 14),
                  ),
                ],
              ),
            ],
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(3),
            child: LinearProgressIndicator(
              value: DateTime.now().weekday == DateTime.sunday
                  ? 2 / 3
                  : (_step + 1) / 3,
              backgroundColor: const Color(0xFF1A1A2E),
              valueColor: const AlwaysStoppedAnimation(Color(0xFFFF6B35)),
              minHeight: 3,
            ),
          ),
        ),
        body: AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          child: _buildStep(_step),
        ),
      ),
    );
  }

  Widget _buildStep(int step) {
    switch (step) {
      case 0:
        return _QuestionCard(
          key: const ValueKey(0),
          number: '01',
          question: 'What was your biggest excuse this week?',
          subtext: 'Be specific. Vague answers will be rejected.',
          submitting: _submitting,
          onNext: _nextStep,
          nextLabel: 'Next',
          child: _TextArea(
            ctrl: _excuseCtrl,
            hint: 'This week I kept telling myself that...',
            error: _excuseError,
            onChanged: (_) => setState(() => _excuseError = null),
          ),
        );
      case 1:
        return _QuestionCard(
          key: const ValueKey(1),
          number: '02',
          question:
              'Which habit are you most likely to quit?\nAnd why haven\'t you quit it yet?',
          subtext: 'Pick the honest answer, not the comfortable one.',
          submitting: _submitting,
          onNext: _nextStep,
          nextLabel: 'Next',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _HabitDropdown(
                habits: widget.habits,
                value: _habitAtRisk,
                onChanged: (v) =>
                    setState(() { _habitAtRisk = v; _whyNotError = null; }),
              ),
              const SizedBox(height: 12),
              _TextArea(
                ctrl: _whyNotCtrl,
                hint: 'I haven\'t quit because...',
                error: _whyNotError,
                onChanged: (_) => setState(() => _whyNotError = null),
              ),
            ],
          ),
        );
      default:
        return _QuestionCard(
          key: const ValueKey(2),
          number: '03',
          question: 'What specifically changes next week?',
          subtext: 'Name one thing, not five. Maximum 20 words.',
          submitting: _submitting,
          onNext: _nextStep,
          nextLabel: 'Submit Review',
          child: _TextArea(
            ctrl: _changesCtrl,
            hint: 'Next week I will specifically...',
            error: _changesError,
            onChanged: (_) => setState(() => _changesError = null),
            wordCountLimit: 20,
          ),
        );
    }
  }
}

// ── Shared question card ──────────────────────────────────────────────────────

class _QuestionCard extends StatelessWidget {
  final String number;
  final String question;
  final String subtext;
  final Widget child;
  final bool submitting;
  final VoidCallback onNext;
  final String nextLabel;

  const _QuestionCard({
    super.key,
    required this.number,
    required this.question,
    required this.subtext,
    required this.submitting,
    required this.onNext,
    required this.nextLabel,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    number,
                    style: const TextStyle(
                        color: Color(0xFFFF6B35),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 3),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    question,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        height: 1.3),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    subtext,
                    style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 13,
                        height: 1.4),
                  ),
                  const SizedBox(height: 28),
                  child,
                ],
              ),
            ),
          ),
          Container(
            color: const Color(0xFF0D0D1A),
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: submitting ? null : onNext,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF6B35),
                  disabledBackgroundColor: const Color(0xFF3A2A20),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  textStyle: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
                child: submitting
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : Text(nextLabel),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Text area ─────────────────────────────────────────────────────────────────

class _TextArea extends StatefulWidget {
  final TextEditingController ctrl;
  final String hint;
  final String? error;
  final void Function(String) onChanged;
  final int? wordCountLimit;

  const _TextArea({
    required this.ctrl,
    required this.hint,
    required this.error,
    required this.onChanged,
    this.wordCountLimit,
  });

  @override
  State<_TextArea> createState() => _TextAreaState();
}

class _TextAreaState extends State<_TextArea> {
  int _wordCount = 0;

  @override
  void initState() {
    super.initState();
    widget.ctrl.addListener(_updateCount);
  }

  void _updateCount() {
    final count = widget.ctrl.text
        .trim()
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .length;
    if (count != _wordCount) setState(() => _wordCount = count);
  }

  @override
  void dispose() {
    widget.ctrl.removeListener(_updateCount);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isOverLimit =
        widget.wordCountLimit != null && _wordCount > widget.wordCountLimit!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: widget.ctrl,
          onChanged: widget.onChanged,
          style: const TextStyle(color: Colors.white, fontSize: 15, height: 1.5),
          maxLines: 5,
          decoration: InputDecoration(
            hintText: widget.hint,
            hintStyle:
                const TextStyle(color: Colors.white24, fontSize: 14),
            filled: true,
            fillColor: const Color(0xFF1A1A2E),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                  color: Color(0xFFFF6B35), width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  const BorderSide(color: Color(0xFFFF4444), width: 1.5),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            if (widget.error != null)
              Expanded(
                child: Text(
                  widget.error!,
                  style: const TextStyle(
                      color: Color(0xFFFF5555), fontSize: 12, height: 1.3),
                ),
              )
            else
              const Spacer(),
            Text(
              '$_wordCount${widget.wordCountLimit != null ? ' / ${widget.wordCountLimit}' : ''} words',
              style: TextStyle(
                color: isOverLimit
                    ? const Color(0xFFFF4444)
                    : Colors.white24,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ── Habit dropdown ────────────────────────────────────────────────────────────

class _HabitDropdown extends StatelessWidget {
  final List<Habit> habits;
  final String? value;
  final void Function(String?) onChanged;

  const _HabitDropdown({
    required this.habits,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF2A2A4A)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          value: value,
          hint: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 14),
            child: Text('Select a habit…',
                style: TextStyle(color: Colors.white38, fontSize: 14)),
          ),
          dropdownColor: const Color(0xFF1A1A2E),
          borderRadius: BorderRadius.circular(12),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          items: habits
              .map((h) => DropdownMenuItem(
                    value: h.name,
                    child: Text(h.name,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 14)),
                  ))
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}

