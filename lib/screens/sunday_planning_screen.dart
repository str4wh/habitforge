import 'package:flutter/material.dart';
import '../models/habit.dart';
import '../models/weekly_deliverable.dart';
import '../services/firestore_service.dart';
import '../services/notification_service.dart';
import '../utils/week_utils.dart';
import 'weekly_review_screen.dart';

// ── Generic word guard ────────────────────────────────────────────────────────

const _genericWords = {'do', 'work', 'improve', 'something', 'stuff', 'things'};

bool _isAllGeneric(String text) {
  final words = text.toLowerCase().split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
  return words.isNotEmpty && words.every((w) => _genericWords.contains(w));
}

// ── Screen ────────────────────────────────────────────────────────────────────

class SundayPlanningScreen extends StatefulWidget {
  final String uid;
  final List<Habit> habits;

  const SundayPlanningScreen({
    super.key,
    required this.uid,
    required this.habits,
  });

  @override
  State<SundayPlanningScreen> createState() => _SundayPlanningScreenState();
}

class _SundayPlanningScreenState extends State<SundayPlanningScreen> {
  /// habitId → list of TextEditingControllers (1–3 deliverables)
  late final Map<String, List<TextEditingController>> _ctrls;

  /// habitId → error messages per field index
  final Map<String, Map<int, String>> _errors = {};

  /// Last week's deliverable texts per habitId (for duplicate check)
  Map<String, List<String>> _lastWeekTexts = {};

  bool _submitting = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _ctrls = {
      for (final h in widget.habits) h.id: [TextEditingController()],
    };
    _loadLastWeek();
  }

  Future<void> _loadLastWeek() async {
    final lastWeekKey = isoWeekKey(DateTime.now().subtract(const Duration(days: 7)));
    final plan = await FirestoreService.getWeeklyPlan(widget.uid, lastWeekKey);
    setState(() {
      _lastWeekTexts = {
        for (final e in plan.entries)
          e.key: e.value.map((d) => d.text.trim().toLowerCase()).toList(),
      };
      _loading = false;
    });
  }

  @override
  void dispose() {
    for (final list in _ctrls.values) {
      for (final c in list) {
        c.dispose();
      }
    }
    super.dispose();
  }

  // ── Validation ────────────────────────────────────────────────────────────

  String? _validate(String habitId, int idx, String text) {
    final trimmed = text.trim();
    final words = trimmed.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();

    if (words.length < 4) {
      return 'Too vague. What specifically will you do?';
    }
    if (_isAllGeneric(trimmed)) {
      return 'That means nothing. Write something you can actually tick off.';
    }
    final lastWeek = _lastWeekTexts[habitId] ?? [];
    if (lastWeek.contains(trimmed.toLowerCase())) {
      return 'You wrote this last week. Did you actually do it? Write something new.';
    }
    return null;
  }

  // ── Submission ────────────────────────────────────────────────────────────

  Future<void> _submit() async {
    if (_submitting) return;

    // Validate all fields
    final newErrors = <String, Map<int, String>>{};
    bool hasError = false;

    for (final habit in widget.habits) {
      final controllers = _ctrls[habit.id]!;
      final fieldErrors = <int, String>{};

      // Must have at least one non-empty deliverable
      final nonEmpty = controllers.where((c) => c.text.trim().isNotEmpty).toList();
      if (nonEmpty.isEmpty) {
        fieldErrors[0] =
            "You haven't planned anything for ${habit.name}. You cannot skip this.";
        hasError = true;
      } else {
        for (int i = 0; i < controllers.length; i++) {
          final text = controllers[i].text.trim();
          if (text.isEmpty) continue;
          final err = _validate(habit.id, i, text);
          if (err != null) {
            fieldErrors[i] = err;
            hasError = true;
          }
        }
      }

      if (fieldErrors.isNotEmpty) newErrors[habit.id] = fieldErrors;
    }

    setState(() => _errors
      ..clear()
      ..addAll(newErrors));

    if (hasError) return;

    setState(() => _submitting = true);

    final now = DateTime.now();
    final weekKey = isoWeekKey(now);
    final today = dayName(now);

    final plan = <String, List<WeeklyDeliverable>>{};
    for (final habit in widget.habits) {
      final deliverables = <WeeklyDeliverable>[];
      final controllers = _ctrls[habit.id]!;
      for (int i = 0; i < controllers.length; i++) {
        final text = controllers[i].text.trim();
        if (text.isEmpty) continue;
        deliverables.add(WeeklyDeliverable(
          id: '${now.millisecondsSinceEpoch}_${habit.id}_$i',
          text: text,
          completed: false,
          rolloverCount: 0,
          originalDay: today,
          createdAt: now,
        ));
      }
      plan[habit.id] = deliverables;
    }

    await FirestoreService.saveWeeklyPlan(widget.uid, weekKey, plan);
    // Cancel the 9PM urgent reminder since the user has planned
    await NotificationService.cancelSundayUrgentReminder();

    // On Sundays, immediately transition to the Weekly Honest Review
    if (mounted && DateTime.now().weekday == DateTime.sunday) {
      final reviewed = await FirestoreService.isWeeklyReviewSubmitted(
          widget.uid, weekKey);
      if (!reviewed && mounted) {
        // Replace this screen with the review — user cannot back out of review
        await Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            fullscreenDialog: true,
            builder: (_) => WeeklyReviewScreen(
              uid: widget.uid,
              habits: widget.habits,
              weekKey: weekKey,
            ),
          ),
        );
        return; // review screen will pop itself when done
      }
    }

    if (mounted) Navigator.of(context).pop(true);
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D1A),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white54),
          onPressed: () => Navigator.of(context).pop(false),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (DateTime.now().weekday == DateTime.sunday)
              const Text(
                'SUNDAY CHECK-IN · 1 OF 3',
                style: TextStyle(
                    color: Color(0xFFFF6B35),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5),
              ),
            const Text(
              'WEEKLY PLAN',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 17,
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(3),
          child: DateTime.now().weekday == DateTime.sunday
              ? const LinearProgressIndicator(
                  value: 1 / 3,
                  backgroundColor: Color(0xFF1A1A2E),
                  valueColor: AlwaysStoppedAnimation(Color(0xFFFF6B35)),
                  minHeight: 3,
                )
              : Container(height: 1, color: const Color(0xFF2A2A4A)),
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFFF6B35)))
          : Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                    children: [
                      _Header(weekKey: isoWeekKey(DateTime.now())),
                      const SizedBox(height: 20),
                      ...widget.habits.map((h) => _HabitPlanCard(
                            habit: h,
                            controllers: _ctrls[h.id]!,
                            errors: _errors[h.id] ?? {},
                            onAddField: () => setState(() {
                              if (_ctrls[h.id]!.length < 3) {
                                _ctrls[h.id]!.add(TextEditingController());
                              }
                            }),
                            onRemoveField: (i) => setState(() {
                              if (_ctrls[h.id]!.length > 1) {
                                _ctrls[h.id]![i].dispose();
                                _ctrls[h.id]!.removeAt(i);
                              }
                            }),
                            onChanged: () {
                              // Clear field-level error when user types
                              if (_errors.containsKey(h.id)) {
                                setState(() => _errors.remove(h.id));
                              }
                            },
                          )),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
                _SubmitBar(
                  submitting: _submitting,
                  onSubmit: _submit,
                  habitCount: widget.habits.length,
                ),
              ],
            ),
    );
  }
}

// ── Header ────────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final String weekKey;
  const _Header({required this.weekKey});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          weekKey,
          style: const TextStyle(
              color: Color(0xFFFF6B35),
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 2),
        ),
        const SizedBox(height: 6),
        const Text(
          'What will you actually do this week?',
          style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        const Text(
          'Write at least one concrete deliverable per habit. '
          'Vague plans are no plans.',
          style: TextStyle(color: Colors.white38, fontSize: 13, height: 1.4),
        ),
      ],
    );
  }
}

// ── Per-habit plan card ───────────────────────────────────────────────────────

class _HabitPlanCard extends StatelessWidget {
  final Habit habit;
  final List<TextEditingController> controllers;
  final Map<int, String> errors;
  final VoidCallback onAddField;
  final void Function(int) onRemoveField;
  final VoidCallback onChanged;

  const _HabitPlanCard({
    required this.habit,
    required this.controllers,
    required this.errors,
    required this.onAddField,
    required this.onRemoveField,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final hasError = errors.isNotEmpty;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hasError
              ? const Color(0xFFFF4444).withValues(alpha: 0.6)
              : const Color(0xFF2A2A4A),
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Habit name chip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFF0D0D1A),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: const Color(0xFFFF6B35).withValues(alpha: 0.4)),
            ),
            child: Text(
              habit.name,
              style: const TextStyle(
                  color: Color(0xFFFF6B35),
                  fontSize: 12,
                  fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 14),
          // Deliverable fields
          ...List.generate(controllers.length, (i) => _DeliverableField(
                index: i,
                ctrl: controllers[i],
                error: errors[i],
                canRemove: controllers.length > 1,
                onRemove: () => onRemoveField(i),
                onChanged: onChanged,
              )),
          // Error at field 0 can also be habit-level
          if (errors[0] != null && controllers[0].text.trim().isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                errors[0]!,
                style: const TextStyle(
                    color: Color(0xFFFF5555), fontSize: 12, height: 1.3),
              ),
            ),
          // Add another button
          if (controllers.length < 3) ...[
            const SizedBox(height: 10),
            GestureDetector(
              onTap: onAddField,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.add_circle_outline,
                      color: Color(0xFFFF6B35), size: 16),
                  SizedBox(width: 6),
                  Text('Add another deliverable',
                      style: TextStyle(
                          color: Color(0xFFFF6B35),
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DeliverableField extends StatelessWidget {
  final int index;
  final TextEditingController ctrl;
  final String? error;
  final bool canRemove;
  final VoidCallback onRemove;
  final VoidCallback onChanged;

  const _DeliverableField({
    required this.index,
    required this.ctrl,
    required this.error,
    required this.canRemove,
    required this.onRemove,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: ctrl,
                  onChanged: (_) => onChanged(),
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'e.g. Record and upload episode 3 of the podcast',
                    hintStyle: const TextStyle(
                        color: Colors.white24, fontSize: 13),
                    filled: true,
                    fillColor: const Color(0xFF0D0D1A),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(
                          color: Color(0xFFFF6B35), width: 1.5),
                    ),
                    errorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(
                          color: Color(0xFFFF4444), width: 1.5),
                    ),
                  ),
                ),
              ),
              if (canRemove) ...[
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: onRemove,
                  child: const Icon(Icons.remove_circle_outline,
                      color: Colors.white24, size: 20),
                ),
              ],
            ],
          ),
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(top: 4, left: 2),
              child: Text(
                error!,
                style: const TextStyle(
                    color: Color(0xFFFF5555), fontSize: 12, height: 1.3),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Submit bar ────────────────────────────────────────────────────────────────

class _SubmitBar extends StatelessWidget {
  final bool submitting;
  final VoidCallback onSubmit;
  final int habitCount;

  const _SubmitBar({
    required this.submitting,
    required this.onSubmit,
    required this.habitCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF12122A),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Every habit must have at least 1 deliverable.',
            style: const TextStyle(color: Colors.white38, fontSize: 12),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: submitting ? null : onSubmit,
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
                  : const Text('Lock In This Week'),
            ),
          ),
        ],
      ),
    );
  }
}
