import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/habit.dart';
import '../models/habit_log.dart';
import '../models/workout_data.dart';
import '../services/firestore_service.dart';
import '../utils/habit_utils.dart';

// ── Punishment data ───────────────────────────────────────────────────────────

class MissedPunishment {
  final Habit habit;
  final String punishmentText;
  final WorkoutData? workoutMinimum;

  const MissedPunishment({
    required this.habit,
    required this.punishmentText,
    this.workoutMinimum,
  });
}

List<MissedPunishment> computePunishments(
  List<Habit> activeHabits,
  HabitLog? yesterdayLog,
) {
  final completed = yesterdayLog?.completedHabits ?? [];
  return activeHabits
      .where((h) => !completed.contains(h.id))
      .map((h) => _punishmentFor(h, yesterdayLog))
      .toList();
}

MissedPunishment _punishmentFor(Habit habit, HabitLog? log) {
  final type = habitTypeFor(habit.name);
  switch (type) {
    case HabitType.pray:
      return MissedPunishment(
        habit: habit,
        punishmentText: 'Pray 3x today — no negotiation',
      );

    case HabitType.coldShower:
      return MissedPunishment(
        habit: habit,
        punishmentText: 'Cold shower minimum 2x today',
      );

    case HabitType.savings:
      return MissedPunishment(
        habit: habit,
        punishmentText:
            "Save double today. You owe yesterday's amount plus today's.",
      );

    case HabitType.shukrani:
      return MissedPunishment(
        habit: habit,
        punishmentText: 'Post double on every platform you missed',
      );

    case HabitType.chakula:
      return MissedPunishment(
        habit: habit,
        punishmentText:
            "Two deliverables today, not one. Yesterday's counts against you.",
      );

    case HabitType.workout:
      final w = log?.workout;
      final bool allMissed =
          w == null || (w.pushups == 0 && w.situps == 0 && w.jumpingJacks == 0);

      late WorkoutData minimum;
      late String detail;

      if (allMissed) {
        minimum = const WorkoutData(pushups: 100, situps: 100, jumpingJacks: 120);
        detail = '100 pushups / 100 situps / 120 jumping jacks';
      } else {
        final pu = (w.pushups > 0) ? 50 : 100;
        final su = (w.situps > 0) ? 50 : 100;
        final jj = (w.jumpingJacks > 0) ? 60 : 120;
        minimum = WorkoutData(pushups: pu, situps: su, jumpingJacks: jj);
        final parts = <String>[];
        if (w.pushups == 0) parts.add('100 pushups');
        if (w.situps == 0) parts.add('100 situps');
        if (w.jumpingJacks == 0) parts.add('120 jumping jacks');
        detail = parts.join(' / ');
      }

      return MissedPunishment(
        habit: habit,
        punishmentText: 'Minimum today: $detail',
        workoutMinimum: minimum,
      );

    default:
      return MissedPunishment(
        habit: habit,
        punishmentText: 'Complete it today — no excuses.',
      );
  }
}

// ── Screen ────────────────────────────────────────────────────────────────────

class ShameWallScreen extends StatefulWidget {
  final String uid;
  final String todayDate;
  final List<MissedPunishment> punishments;
  final VoidCallback onAccepted;
  final List<String> extraMessages;

  const ShameWallScreen({
    super.key,
    required this.uid,
    required this.todayDate,
    required this.punishments,
    required this.onAccepted,
    this.extraMessages = const [],
  });

  @override
  State<ShameWallScreen> createState() => _ShameWallScreenState();
}

class _ShameWallScreenState extends State<ShameWallScreen> {
  final Set<int> _acknowledged = {};
  bool _saving = false;

  bool get _allDone => widget.punishments.isEmpty ||
      _acknowledged.length == widget.punishments.length;

  void _toggle(int index) {
    if (_saving) return;
    setState(() {
      if (_acknowledged.contains(index)) {
        _acknowledged.remove(index);
      } else {
        _acknowledged.add(index);
      }
    });
    if (_acknowledged.length == widget.punishments.length) {
      _proceed();
    }
  }

  void _proceed() {
    if (_saving) return;
    setState(() => _saving = true);

    // Write to Firestore in the background — don't block the transition
    final prefill = <String, dynamic>{};
    for (final p in widget.punishments) {
      if (p.workoutMinimum != null) {
        prefill['workout'] = p.workoutMinimum!.toMap();
        break;
      }
    }
    FirestoreService.writePunishmentAcknowledged(
      widget.uid,
      widget.todayDate,
      prefillFields: prefill.isEmpty ? null : prefill,
    );

    // Dismiss immediately
    widget.onAccepted();
  }

  @override
  Widget build(BuildContext context) {
    final remaining = widget.punishments.length - _acknowledged.length;

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: const Color(0xFF0D0005),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('💀', style: TextStyle(fontSize: 48)),
                      const SizedBox(height: 16),
                      const Text(
                        'You failed yesterday.\nOwn it.',
                        style: TextStyle(
                          color: Color(0xFFFF2222),
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          height: 1.2,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        DateFormat('EEEE, d MMMM yyyy')
                            .format(DateTime.now().subtract(const Duration(days: 1))),
                        style: const TextStyle(color: Colors.white30, fontSize: 13),
                      ),
                      if (widget.extraMessages.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        ...widget.extraMessages.map((msg) => Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1A000A),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: const Color(0xFFFF2222).withValues(alpha: 0.4)),
                          ),
                          child: Text(
                            msg,
                            style: const TextStyle(
                                color: Color(0xFFFF6666),
                                fontSize: 13,
                                height: 1.5),
                          ),
                        )),
                      ],
                      if (widget.punishments.isNotEmpty) ...[
                        const SizedBox(height: 36),
                        const Text(
                          'ACKNOWLEDGE EACH PUNISHMENT',
                          style: TextStyle(
                            color: Colors.white30,
                            fontSize: 11,
                            letterSpacing: 2,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ...List.generate(widget.punishments.length, (i) {
                          return _PunishmentTile(
                            punishment: widget.punishments[i],
                            checked: _acknowledged.contains(i),
                            onTap: () => _toggle(i),
                          );
                        }),
                      ] else ...[
                        const SizedBox(height: 36),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF8B0000)),
                            onPressed: _proceed,
                            child: const Text('Got it',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              // Progress hint pinned at bottom
              if (!_allDone)
                Container(
                  color: const Color(0xFF0D0005),
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                  child: Text(
                    remaining == widget.punishments.length
                        ? 'Tap each item above to acknowledge it.'
                        : '$remaining left to acknowledge.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white30, fontSize: 13),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Punishment tile ───────────────────────────────────────────────────────────

class _PunishmentTile extends StatelessWidget {
  final MissedPunishment punishment;
  final bool checked;
  final VoidCallback onTap;

  const _PunishmentTile({
    required this.punishment,
    required this.checked,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: checked ? const Color(0xFF0A1A0A) : const Color(0xFF1A0505),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: checked ? const Color(0xFF00C853) : const Color(0xFF4A1010),
            width: 1.5,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Tick circle — matches daily habit tile style
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(top: 1),
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: checked ? const Color(0xFF00C853) : Colors.transparent,
                border: Border.all(
                  color: checked ? const Color(0xFF00C853) : const Color(0xFF664444),
                  width: 2,
                ),
              ),
              child: checked
                  ? const Icon(Icons.check, size: 16, color: Colors.black)
                  : null,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          punishment.habit.name,
                          style: TextStyle(
                            color: checked ? Colors.white38 : Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            decoration: checked ? TextDecoration.lineThrough : null,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: checked
                              ? const Color(0xFF0A1A0A)
                              : const Color(0xFF2A0A0A),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          punishment.habit.category,
                          style: TextStyle(
                            color: checked ? Colors.white24 : Colors.white30,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        checked ? '✓ ' : '⚡ ',
                        style: const TextStyle(fontSize: 13),
                      ),
                      Expanded(
                        child: Text(
                          punishment.punishmentText,
                          style: TextStyle(
                            color: checked
                                ? Colors.white24
                                : const Color(0xFFFF6B35),
                            fontSize: 13,
                            height: 1.4,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
