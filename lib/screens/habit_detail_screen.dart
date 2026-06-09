import 'package:flutter/material.dart';
import '../models/habit.dart';
import '../models/why_data.dart';
import '../utils/habit_utils.dart';
import 'why_onboarding_screen.dart';

class HabitDetailScreen extends StatefulWidget {
  final Habit habit;
  final WhyData why;
  final String uid;

  const HabitDetailScreen({
    super.key,
    required this.habit,
    required this.why,
    required this.uid,
  });

  @override
  State<HabitDetailScreen> createState() => _HabitDetailScreenState();
}

class _HabitDetailScreenState extends State<HabitDetailScreen> {
  late WhyData _why;

  @override
  void initState() {
    super.initState();
    _why = widget.why;
  }

  Future<void> _editWhy() async {
    final result = await Navigator.of(context).push<WhyData>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => WhyOnboardingScreen(
          uid: widget.uid,
          habitId: widget.habit.id,
          habitName: widget.habit.name,
        ),
      ),
    );
    if (result != null && mounted) setState(() => _why = result);
  }

  @override
  Widget build(BuildContext context) {
    // Always pop with the current (possibly updated) WHY so the parent cache stays fresh
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(_why);
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0D0D1A),
        appBar: AppBar(
          backgroundColor: const Color(0xFF0D0D1A),
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new,
                color: Colors.white54, size: 18),
            onPressed: () => Navigator.of(context).pop(_why),
          ),
          title: Text(
            widget.habit.name,
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 17),
          ),
          actions: [
            TextButton.icon(
              onPressed: _editWhy,
              icon: const Icon(Icons.edit_outlined,
                  color: Color(0xFFFF6B35), size: 16),
              label: const Text(
                'Edit WHY',
                style: TextStyle(
                    color: Color(0xFFFF6B35),
                    fontSize: 13,
                    fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── WHY STATEMENT CARD ────────────────────────────────────────
              const Text(
                'YOUR WHY',
                style: TextStyle(
                  color: Color(0xFFFF6B35),
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2.5,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A2E),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: const Color(0xFFFF6B35).withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _why.statement,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        height: 1.7,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _dateLabel(_why.completedAt),
                      style: const TextStyle(
                          color: Colors.white24, fontSize: 11),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              // ── FULL Q&A ──────────────────────────────────────────────────
              const Text(
                'FULL ANSWERS',
                style: TextStyle(
                  color: Colors.white38,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 16),
              _QA("What do you want this habit to give you?", _why.q1),
              _QA("Why does that matter to you right now, specifically?",
                  _why.q2),
              _QA("What has NOT having this already cost you?", _why.q3,
                  highlight: true),
              _QA("Who are you becoming by doing this daily?", _why.q4),
              _QA(q5For(widget.habit.name), _why.q5),
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

class _QA extends StatelessWidget {
  final String question;
  final String answer;
  final bool highlight;

  const _QA(this.question, this.answer, {this.highlight = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: highlight
            ? const Color(0xFF1A0808)
            : const Color(0xFF12122A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: highlight
              ? const Color(0xFFFF4444).withValues(alpha: 0.3)
              : const Color(0xFF2A2A4A),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            question.toUpperCase(),
            style: TextStyle(
              color: highlight ? const Color(0xFFFF6666) : Colors.white38,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            answer,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}
