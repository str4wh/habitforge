import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../main.dart' show kMaxContentWidth;
import '../models/habit.dart';
import '../models/habit_log.dart';
import '../models/weekly_deliverable.dart';
import '../models/why_data.dart';
import '../models/workout_data.dart';
import '../providers/auth_provider.dart';
import '../providers/habits_provider.dart';
import '../providers/logs_provider.dart';
import '../screens/habit_detail_screen.dart';
import '../screens/why_onboarding_screen.dart';
import '../services/firestore_service.dart';
import '../services/notification_service.dart';
import '../services/widget_service.dart';
import '../utils/habit_utils.dart';
import '../utils/week_utils.dart';

class DailyCheckinScreen extends ConsumerStatefulWidget {
  const DailyCheckinScreen({super.key});

  @override
  ConsumerState<DailyCheckinScreen> createState() =>
      _DailyCheckinScreenState();
}

class _DailyCheckinScreenState extends ConsumerState<DailyCheckinScreen> {
  bool _targetPromptShown = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (_targetPromptShown) return;
      _targetPromptShown = true;
      final user = ref.read(authProvider).valueOrNull;
      if (user == null || !mounted) return;

      // Don't show again if user previously dismissed or already set a target
      final prefs = await SharedPreferences.getInstance();
      final dismissed = prefs.getBool('savings_target_dismissed_${user.uid}') ?? false;
      if (dismissed) return;

      final target = await FirestoreService.getSavingsTarget(user.uid);
      if (target != null) {
        // Already set — mark as dismissed so we never check Firestore again
        await prefs.setBool('savings_target_dismissed_${user.uid}', true);
        return;
      }

      if (mounted) _showTargetDialog(context, user.uid);
    });
  }

  void _showTargetDialog(BuildContext ctx, String uid) {
    final ctrl = TextEditingController();
    showDialog(
      context: ctx,
      barrierDismissible: false,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: const Text('Set Savings Target',
            style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'How much do you want to save this month? (KES)',
              style: TextStyle(color: Colors.white54, fontSize: 14),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: ctrl,
              keyboardType: TextInputType.number,
              autofocus: true,
              style: const TextStyle(color: Colors.white, fontSize: 20),
              decoration: InputDecoration(
                prefixText: 'KES ',
                prefixStyle: const TextStyle(color: Colors.white54),
                hintText: '10000',
                hintStyle: const TextStyle(color: Colors.white24),
                filled: true,
                fillColor: const Color(0xFF0D0D1A),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(
                      color: Color(0xFFFF6B35), width: 1.5),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              // Remember the skip so the dialog never appears again
              final prefs = await SharedPreferences.getInstance();
              await prefs.setBool('savings_target_dismissed_$uid', true);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Skip',
                style: TextStyle(color: Colors.white38)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF6B35),
            ),
            onPressed: () async {
              final val = double.tryParse(ctrl.text);
              if (val != null && val > 0) {
                await FirestoreService.setSavingsTarget(uid, val);
                final prefs = await SharedPreferences.getInstance();
                await prefs.setBool('savings_target_dismissed_$uid', true);
                if (ctx.mounted) {
                  ref.invalidate(savingsTargetProvider);
                  Navigator.pop(ctx);
                }
              }
            },
            child: const Text('Set Target',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final logAsync = ref.watch(todayLogProvider);
    final activeHabits = ref.watch(activeHabitsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D1A),
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('HabitForge',
                style: TextStyle(
                    color: Color(0xFFFF6B35),
                    fontWeight: FontWeight.bold,
                    fontSize: 20)),
            Text(
              DateFormat('EEEE, d MMMM yyyy').format(DateTime.now()),
              style: const TextStyle(color: Colors.white38, fontSize: 12),
            ),
          ],
        ),
      ),
      body: auth.when(
        loading: () =>
            const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Auth error: $e')),
        data: (user) {
          if (user == null) return const SizedBox.shrink();
          return logAsync.when(
            loading: () =>
                const Center(child: CircularProgressIndicator()),
            error: (e, _) =>
                Center(child: Text('Log error: $e')),
            data: (existingLog) => _CheckinBody(
              uid: user.uid,
              activeHabits: activeHabits,
              existingLog: existingLog,
            ),
          );
        },
      ),
    );
  }
}

// ── CheckinBody ───────────────────────────────────────────────────────────────

class _CheckinBody extends ConsumerStatefulWidget {
  final String uid;
  final List<Habit> activeHabits;
  final HabitLog? existingLog;

  const _CheckinBody({
    required this.uid,
    required this.activeHabits,
    required this.existingLog,
  });

  @override
  ConsumerState<_CheckinBody> createState() => _CheckinBodyState();
}

class _CheckinBodyState extends ConsumerState<_CheckinBody> {
  late List<String> _completedIds;
  double _savingsAmount = 0;
  double? _coldShowerMinutes;
  Map<String, int> _shukraniReach = {};
  String? _chakulaDeliverable;
  WorkoutData? _workout;

  // Why cache: key present + null = no why data; key present + WhyData = has data
  final Map<String, WhyData?> _whyCache = {};

  // Workout progression targets (fetched from Firestore on init)
  WorkoutData _workoutTargets =
      const WorkoutData(pushups: 50, situps: 50, jumpingJacks: 60);

  // Weekly plan deliverables: habitId → list
  Map<String, List<WeeklyDeliverable>> _weeklyPlan = {};

  // Auto-save state
  Timer? _saveDebounce;
  bool _isSaving = false;
  bool _justSaved = false;

  @override
  void initState() {
    super.initState();
    _loadFromLog(widget.existingLog);
    _initShameNotifications();
    _loadAllWhy();
    _loadWorkoutTargets();
    _loadWeeklyPlan();
    // Refresh widget on every app open — Android only
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      WidgetService.updateWidget(widget.uid);
    }
  }

  Future<void> _loadWorkoutTargets() async {
    final targets = await FirestoreService.getWorkoutTargets(widget.uid);
    if (mounted) setState(() => _workoutTargets = targets);
  }

  Future<void> _loadWeeklyPlan() async {
    final weekKey = isoWeekKey(DateTime.now());
    final plan = await FirestoreService.getWeeklyPlan(widget.uid, weekKey);
    if (mounted) setState(() => _weeklyPlan = plan);
  }

  Future<void> _markDeliverableComplete(
      String habitId, WeeklyDeliverable d) async {
    final weekKey = isoWeekKey(DateTime.now());
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final updated = d.copyWith(completed: true, completedDate: today);
    await FirestoreService.updateDeliverable(widget.uid, weekKey, habitId, updated);
    if (mounted) {
      setState(() {
        final list = List<WeeklyDeliverable>.from(_weeklyPlan[habitId] ?? []);
        final idx = list.indexWhere((x) => x.id == d.id);
        if (idx >= 0) list[idx] = updated;
        _weeklyPlan = {..._weeklyPlan, habitId: list};
      });
    }
  }

  Future<void> _breakDownDeliverable(
      String habitId, WeeklyDeliverable d) async {
    final parts = <TextEditingController>[
      TextEditingController(),
      TextEditingController(),
    ];
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Break it down',
            style: TextStyle(color: Colors.white, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('"${d.text}"',
                style: const TextStyle(
                    color: Colors.white54, fontSize: 13, height: 1.4)),
            const SizedBox(height: 14),
            ...parts.map((c) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: TextField(
                    controller: c,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Smaller step…',
                      hintStyle:
                          const TextStyle(color: Colors.white24, fontSize: 13),
                      filled: true,
                      fillColor: const Color(0xFF0D0D1A),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none),
                    ),
                  ),
                )),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel',
                  style: TextStyle(color: Colors.white38))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF6B35)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Replace',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final newTexts =
        parts.map((c) => c.text.trim()).where((t) => t.isNotEmpty).toList();
    if (newTexts.isEmpty) return;

    final now = DateTime.now();
    final newItems = newTexts
        .asMap()
        .entries
        .map((e) => WeeklyDeliverable(
              id: '${now.millisecondsSinceEpoch}_${habitId}_breakdown_${e.key}',
              text: e.value,
              completed: false,
              rolloverCount: 0,
              originalDay: d.originalDay,
              createdAt: now,
            ))
        .toList();

    final weekKey = isoWeekKey(now);
    await FirestoreService.replaceDeliverable(
        widget.uid, weekKey, habitId, d.id, newItems);
    if (mounted) {
      setState(() {
        final list = List<WeeklyDeliverable>.from(_weeklyPlan[habitId] ?? []);
        final idx = list.indexWhere((x) => x.id == d.id);
        if (idx >= 0) {
          list.removeAt(idx);
          list.insertAll(idx, newItems);
        }
        _weeklyPlan = {..._weeklyPlan, habitId: list};
      });
    }
  }

  Future<void> _loadAllWhy() async {
    for (final habit in widget.activeHabits) {
      if (_whyCache.containsKey(habit.id)) continue;
      final why = await FirestoreService.getWhyData(widget.uid, habit.id);
      if (mounted) setState(() => _whyCache[habit.id] = why);
    }
  }

  Future<void> _initShameNotifications() async {
    if (kIsWeb) return;
    final completedNames = (widget.existingLog?.completedHabits ?? [])
        .expand((id) =>
            widget.activeHabits.where((h) => h.id == id).map((h) => h.name))
        .toList();
    final done = completedNames.length;

    // Load weekly plan for Layer 3 (incomplete deliverable counts per habit)
    final weekKey = isoWeekKey(DateTime.now());
    final plan = await FirestoreService.getWeeklyPlan(widget.uid, weekKey);
    final incompleteByName = <String, int>{};
    for (final habit in widget.activeHabits) {
      final count = (plan[habit.id] ?? [])
          .where((d) => !d.completed)
          .length;
      if (count > 0) incompleteByName[habit.name] = count;
    }

    // Total rollover count for end-of-day notification
    final totalRollovers = plan.values
        .expand((ds) => ds)
        .fold(0, (sum, d) => sum + d.rolloverCount);

    // Last week's review 'what changes' for zero-day notification
    String? lastReviewChange;
    try {
      final reviews = await FirestoreService.getAllWeeklyReviews(widget.uid);
      if (reviews.isNotEmpty) lastReviewChange = reviews.first.whatChanges;
    } catch (_) {}

    await NotificationService.scheduleShameNotifications(
      completedNames,
      incompleteDeliverablesByName: incompleteByName,
    );
    await NotificationService.scheduleEndOfDay(
      done,
      widget.activeHabits.length,
      rolloverCount: totalRollovers,
      lastReviewChange: lastReviewChange,
    );
  }

  Future<WhyData?> _resolveWhy(Habit habit) async {
    if (_whyCache.containsKey(habit.id)) return _whyCache[habit.id];
    final why = await FirestoreService.getWhyData(widget.uid, habit.id);
    _whyCache[habit.id] = why;
    return why;
  }

  @override
  void didUpdateWidget(_CheckinBody old) {
    super.didUpdateWidget(old);
    if (old.existingLog != widget.existingLog) {
      _loadFromLog(widget.existingLog);
    }
  }

  void _loadFromLog(HabitLog? log) {
    _completedIds = List.from(log?.completedHabits ?? []);
    _savingsAmount = log?.savingsAmount ?? 0;
    _coldShowerMinutes = log?.coldShowerMinutes;
    _shukraniReach = Map.from(log?.shukraniReach ?? {});
    _chakulaDeliverable = log?.chakulaDeliverable;
    _workout = log?.workout;
  }

  @override
  void dispose() {
    _saveDebounce?.cancel();
    super.dispose();
  }

  // Debounced auto-save — fires 600ms after the last change
  void _scheduleAutoSave() {
    _saveDebounce?.cancel();
    _saveDebounce =
        Timer(const Duration(milliseconds: 600), _autoSave);
  }

  Future<void> _autoSave() async {
    if (!mounted) return;
    setState(() => _isSaving = true);
    try {
      final log = HabitLog(
        date: DateFormat('yyyy-MM-dd').format(DateTime.now()),
        completedHabits: _completedIds,
        savingsAmount: _savingsAmount,
        completedAt: DateTime.now(),
        coldShowerMinutes: _coldShowerMinutes,
        shukraniReach: _shukraniReach,
        chakulaDeliverable: _chakulaDeliverable,
        workout: _workout,
      );
      await FirestoreService.upsertLog(widget.uid, log);

      if (!kIsWeb) {
        final done = _completedIds
            .where((id) => widget.activeHabits.any((h) => h.id == id))
            .length;
        if (done >= widget.activeHabits.length) {
          await NotificationService.cancelTodayRemaining();
        }
        final rollovers = _weeklyPlan.values
            .expand((ds) => ds)
            .fold(0, (sum, d) => sum + d.rolloverCount);
        await NotificationService.scheduleEndOfDay(
            done, widget.activeHabits.length,
            rolloverCount: rollovers);
      }

      // Push fresh data to the home screen widget — Android only
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        WidgetService.updateWidget(widget.uid);
      }

      // Invalidate month + stats providers so other tabs refresh
      final now = DateTime.now();
      final monthKey =
          '${now.year}-${now.month.toString().padLeft(2, '0')}';
      ref.invalidate(monthLogsProvider(monthKey));
      ref.invalidate(allLogsProvider);

      if (mounted) {
        setState(() {
          _isSaving = false;
          _justSaved = true;
        });
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) setState(() => _justSaved = false);
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _handleHabitTap(Habit habit) async {
    final type = habitTypeFor(habit.name);

    // Uncheck — always immediate, no why gate
    if (_completedIds.contains(habit.id)) {
      setState(() => _completedIds.remove(habit.id));
      if (!kIsWeb) NotificationService.rescheduleShameNotification(habit.name);
      _scheduleAutoSave();
      return;
    }

    // First-time gate: run onboarding if no why data yet
    final why = await _resolveWhy(habit);
    if (why == null && mounted) {
      final result = await Navigator.of(context).push<WhyData>(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => WhyOnboardingScreen(
            uid: widget.uid,
            habitId: habit.id,
            habitName: habit.name,
          ),
        ),
      );
      if (!mounted) return;
      if (result == null) return; // user cancelled
      _whyCache[habit.id] = result;
      // Reschedule so shame message picks up the new cost line
      if (!kIsWeb) {
        await NotificationService.rescheduleShameNotification(habit.name);
      }
    }

    if (!mounted) return;

    // Simple check — no sheet needed
    if (!habitNeedsSheet(type)) {
      setState(() => _completedIds.add(habit.id));
      if (!kIsWeb) NotificationService.cancelShameNotification(habit.name);
      _scheduleAutoSave();
      return;
    }

    // Show appropriate bottom sheet
    final confirmed = await _showSheet(habit, type);
    if (confirmed && mounted) {
      setState(() => _completedIds.add(habit.id));
      if (!kIsWeb) NotificationService.cancelShameNotification(habit.name);
      _scheduleAutoSave();
    }
  }

  Future<void> _handleHabitLongPress(Habit habit) async {
    final why = await _resolveWhy(habit);
    if (why == null || !mounted) return;
    final updated = await Navigator.of(context).push<WhyData>(
      MaterialPageRoute(
        builder: (_) =>
            HabitDetailScreen(habit: habit, why: why, uid: widget.uid),
      ),
    );
    if (updated != null && mounted) setState(() => _whyCache[habit.id] = updated);
  }

  Future<bool> _showSheet(Habit habit, HabitType type) async {
    switch (type) {
      case HabitType.coldShower:
        final mins = await showModalBottomSheet<double>(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) =>
              _ColdShowerSheet(initial: _coldShowerMinutes),
        );
        if (mins != null) {
          setState(() => _coldShowerMinutes = mins);
          return true;
        }
        return false;

      case HabitType.shukrani:
        final reach = await showModalBottomSheet<int>(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => _ShukraniSheet(
            habitName: habit.name,
            initial: _shukraniReach[habit.id],
          ),
        );
        if (reach != null) {
          setState(() => _shukraniReach[habit.id] = reach);
          return true;
        }
        return false;

      case HabitType.chakula:
        final deliverable = await showModalBottomSheet<String>(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) =>
              _ChakulaSheet(initial: _chakulaDeliverable),
        );
        if (deliverable != null && deliverable.isNotEmpty) {
          setState(() => _chakulaDeliverable = deliverable);
          return true;
        }
        return false;

      case HabitType.savings:
        final amount = await showModalBottomSheet<double>(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => _SavingsSheet(initial: _savingsAmount),
        );
        if (amount != null) {
          setState(() => _savingsAmount = amount);
          return true;
        }
        return false;

      case HabitType.workout:
        final workout = await showModalBottomSheet<WorkoutData>(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => _WorkoutSheet(
              initial: _workout, targets: _workoutTargets),
        );
        if (workout != null) {
          setState(() => _workout = workout);
          return true;
        }
        return false;

      default:
        return true;
    }
  }


  String? _subtitleFor(Habit habit) {
    if (!_completedIds.contains(habit.id)) return null;
    switch (habitTypeFor(habit.name)) {
      case HabitType.coldShower:
        return _coldShowerMinutes != null
            ? '${_coldShowerMinutes!.toStringAsFixed(1)} min'
            : null;
      case HabitType.shukrani:
        final r = _shukraniReach[habit.id];
        return r != null
            ? '${NumberFormat('#,###').format(r)} impressions'
            : null;
      case HabitType.chakula:
        return _chakulaDeliverable;
      case HabitType.savings:
        return _savingsAmount > 0
            ? 'KES ${NumberFormat('#,###').format(_savingsAmount)}'
            : null;
      case HabitType.workout:
        return _workout != null
            ? '${_workout!.pushups} pushups · ${_workout!.situps} situps · ${_workout!.jumpingJacks} JJs'
            : null;
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final active = widget.activeHabits;
    final done =
        _completedIds.where((id) => active.any((h) => h.id == id)).length;
    final total = active.length;
    final pct = total > 0 ? done / total : 0.0;

    return Column(
      children: [
        _ProgressHeader(done: done, total: total, pct: pct),
        Expanded(
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints:
                  const BoxConstraints(maxWidth: kMaxContentWidth),
              child: ListView(
                padding:
                    const EdgeInsets.fromLTRB(16, 16, 16, 32),
                children: [
                  _WhyCardsRow(
                    habits: active,
                    whyCache: _whyCache,
                    uid: widget.uid,
                    onTapEmpty: (habit) async {
                      _whyCache.remove(habit.id);
                      await _handleHabitTap(habit);
                    },
                    onTapFilled: (habit) async {
                      final why = _whyCache[habit.id];
                      if (why == null || !mounted) return;
                      final updated =
                          await Navigator.of(context).push<WhyData>(
                        MaterialPageRoute(
                          builder: (_) => HabitDetailScreen(
                            habit: habit,
                            why: why,
                            uid: widget.uid,
                          ),
                        ),
                      );
                      if (updated != null && mounted) {
                        setState(() => _whyCache[habit.id] = updated);
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  ...active.expand((habit) => [
                        _HabitTile(
                          habit: habit,
                          checked: _completedIds.contains(habit.id),
                          subtitle: _subtitleFor(habit),
                          onTap: () => _handleHabitTap(habit),
                          onLongPress: () => _handleHabitLongPress(habit),
                        ),
                        if ((_weeklyPlan[habit.id] ?? []).isNotEmpty)
                          _DeliverablesSection(
                            deliverables: _weeklyPlan[habit.id]!,
                            onMarkComplete: (d) =>
                                _markDeliverableComplete(habit.id, d),
                            onBreakDown: (d) =>
                                _breakDownDeliverable(habit.id, d),
                          ),
                      ]),
                  const SizedBox(height: 16),
                  _AutoSaveIndicator(
                      isSaving: _isSaving, justSaved: _justSaved),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Progress header ───────────────────────────────────────────────────────────

class _ProgressHeader extends StatelessWidget {
  final int done;
  final int total;
  final double pct;

  const _ProgressHeader(
      {required this.done, required this.total, required this.pct});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: const Color(0xFF12122A),
      child: Center(
        child: ConstrainedBox(
          constraints:
              const BoxConstraints(maxWidth: kMaxContentWidth),
          child: Padding(
            padding:
                const EdgeInsets.fromLTRB(20, 14, 20, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment:
                      MainAxisAlignment.spaceBetween,
                  children: [
                    Text('$done / $total habits',
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 18)),
                    Text('${(pct * 100).round()}%',
                        style: TextStyle(
                          color: pct >= 1.0
                              ? const Color(0xFF00E676)
                              : const Color(0xFFFF6B35),
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        )),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: pct,
                    minHeight: 8,
                    backgroundColor: const Color(0xFF2A2A4A),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      pct >= 1.0
                          ? const Color(0xFF00E676)
                          : const Color(0xFFFF6B35),
                    ),
                  ),
                ),
                if (pct >= 1.0) ...[
                  const SizedBox(height: 8),
                  const Text('All done. Respect.',
                      style: TextStyle(
                          color: Color(0xFF00E676), fontSize: 13)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Habit tile ────────────────────────────────────────────────────────────────

class _HabitTile extends StatelessWidget {
  final Habit habit;
  final bool checked;
  final String? subtitle;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _HabitTile({
    required this.habit,
    required this.checked,
    required this.subtitle,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: checked
              ? const Color(0xFF0F2A1A)
              : const Color(0xFF1A1A2E),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: checked
                ? const Color(0xFF00C853)
                : const Color(0xFF2A2A4A),
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: checked
                    ? const Color(0xFF00C853)
                    : Colors.transparent,
                border: Border.all(
                  color: checked
                      ? const Color(0xFF00C853)
                      : const Color(0xFF555577),
                  width: 2,
                ),
              ),
              child: checked
                  ? const Icon(Icons.check,
                      size: 16, color: Colors.black)
                  : null,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    habit.name,
                    style: TextStyle(
                      color: checked
                          ? Colors.white54
                          : Colors.white,
                      fontSize: 15,
                      decoration: checked
                          ? TextDecoration.lineThrough
                          : null,
                    ),
                  ),
                  if (subtitle != null && subtitle!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitle!,
                      style: const TextStyle(
                          color: Color(0xFF00C853),
                          fontSize: 12),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFF2A2A4A),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                habit.category,
                style: const TextStyle(
                    color: Colors.white38, fontSize: 11),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Deliverables section ──────────────────────────────────────────────────────

class _DeliverablesSection extends StatelessWidget {
  final List<WeeklyDeliverable> deliverables;
  final Future<void> Function(WeeklyDeliverable) onMarkComplete;
  final Future<void> Function(WeeklyDeliverable) onBreakDown;

  const _DeliverablesSection({
    required this.deliverables,
    required this.onMarkComplete,
    required this.onBreakDown,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10, left: 14, right: 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: deliverables.map((d) {
          final isRollover = d.rolloverCount > 0;
          final textColor = d.completed
              ? Colors.white24
              : isRollover
                  ? const Color(0xFFFF4444)
                  : const Color(0xFF9090CC);

          return GestureDetector(
            onTap: isRollover && !d.completed
                ? () async {
                    final choice = await showDialog<String>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        backgroundColor: const Color(0xFF1A1A2E),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                        title: Text(
                          '"${d.text}"',
                          style: const TextStyle(
                              color: Colors.white, fontSize: 14, height: 1.4),
                        ),
                        content: Text(
                          'Carried over ${d.rolloverCount}x. What do you want to do?',
                          style: const TextStyle(
                              color: Colors.white54, fontSize: 13),
                        ),
                        actions: [
                          TextButton(
                              onPressed: () => Navigator.pop(ctx, null),
                              child: const Text('Cancel',
                                  style: TextStyle(color: Colors.white38))),
                          TextButton(
                              onPressed: () =>
                                  Navigator.pop(ctx, 'breakdown'),
                              child: const Text('Break it down',
                                  style:
                                      TextStyle(color: Color(0xFFFF6B35)))),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF00C853)),
                            onPressed: () =>
                                Navigator.pop(ctx, 'complete'),
                            child: const Text('Mark complete',
                                style: TextStyle(color: Colors.black)),
                          ),
                        ],
                      ),
                    );
                    if (choice == 'complete') {
                      await onMarkComplete(d);
                    } else if (choice == 'breakdown') {
                      await onBreakDown(d);
                    }
                  }
                : null,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Icon(
                      d.completed
                          ? Icons.check_circle_outline
                          : Icons.radio_button_unchecked,
                      size: 14,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          d.text,
                          style: TextStyle(
                            color: textColor,
                            fontSize: 13,
                            decoration: d.completed
                                ? TextDecoration.lineThrough
                                : null,
                            height: 1.4,
                          ),
                        ),
                        if (isRollover && !d.completed)
                          Text(
                            'Carried over from ${d.originalDay} × ${d.rolloverCount}',
                            style: const TextStyle(
                                color: Color(0xFFFF4444),
                                fontSize: 11,
                                fontStyle: FontStyle.italic),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── Save button ───────────────────────────────────────────────────────────────

class _AutoSaveIndicator extends StatelessWidget {
  final bool isSaving;
  final bool justSaved;
  const _AutoSaveIndicator(
      {required this.isSaving, required this.justSaved});

  @override
  Widget build(BuildContext context) {
    if (isSaving) {
      return const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 13,
            height: 13,
            child: CircularProgressIndicator(
                strokeWidth: 2, color: Colors.white38),
          ),
          SizedBox(width: 8),
          Text('Saving…',
              style: TextStyle(color: Colors.white38, fontSize: 12)),
        ],
      );
    }
    if (justSaved) {
      return const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle_outline,
              color: Color(0xFF00E676), size: 15),
          SizedBox(width: 6),
          Text('Saved',
              style: TextStyle(
                  color: Color(0xFF00E676), fontSize: 12)),
        ],
      );
    }
    return const SizedBox(height: 8);
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Bottom sheets
// ══════════════════════════════════════════════════════════════════════════════

class _SheetBase extends StatelessWidget {
  final String title;
  final String icon;
  final Widget content;
  final VoidCallback onConfirm;
  final bool confirmEnabled;

  const _SheetBase({
    required this.title,
    required this.icon,
    required this.content,
    required this.onConfirm,
    this.confirmEnabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A2E),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF2A2A4A)),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Title
              Row(
                children: [
                  Text(icon,
                      style: const TextStyle(fontSize: 22)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        )),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              content,
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: confirmEnabled ? onConfirm : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF6B35),
                    disabledBackgroundColor:
                        const Color(0xFF3A3A5A),
                    shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(12)),
                  ),
                  child: const Text('DONE',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Widget _sheetInput(
  TextEditingController ctrl, {
  String? label,
  String? hint,
  String? suffix,
  TextInputType? keyboardType,
  List<TextInputFormatter>? inputFormatters,
  int maxLines = 1,
}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (label != null) ...[
        Text(label,
            style: const TextStyle(
                color: Colors.white38,
                fontSize: 11,
                letterSpacing: 1.3,
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
      ],
      TextField(
        controller: ctrl,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        maxLines: maxLines,
        autofocus: true,
        style: const TextStyle(color: Colors.white, fontSize: 18),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.white24),
          suffixText: suffix,
          suffixStyle:
              const TextStyle(color: Colors.white38, fontSize: 14),
          filled: true,
          fillColor: const Color(0xFF0D0D1A),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide:
                  const BorderSide(color: Color(0xFF2A2A4A))),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide:
                  const BorderSide(color: Color(0xFF2A2A4A))),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(
                  color: Color(0xFFFF6B35), width: 1.5)),
        ),
      ),
    ],
  );
}

// ── Cold Shower sheet ─────────────────────────────────────────────────────────

class _ColdShowerSheet extends StatefulWidget {
  final double? initial;
  const _ColdShowerSheet({this.initial});

  @override
  State<_ColdShowerSheet> createState() => _ColdShowerSheetState();
}

class _ColdShowerSheetState extends State<_ColdShowerSheet> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(
      text: widget.initial != null
          ? widget.initial!.toStringAsFixed(1)
          : '',
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _SheetBase(
      title: 'Cold Shower',
      icon: '🚿',
      confirmEnabled: double.tryParse(_ctrl.text) != null,
      onConfirm: () => Navigator.pop(
          context, double.tryParse(_ctrl.text)),
      content: _sheetInput(
        _ctrl,
        label: 'HOW LONG WAS IT?',
        hint: '3.0',
        suffix: 'minutes',
        keyboardType:
            const TextInputType.numberWithOptions(decimal: true),
      ),
    );
  }
}

// ── Shukrani sheet ────────────────────────────────────────────────────────────

class _ShukraniSheet extends StatefulWidget {
  final String habitName;
  final int? initial;
  const _ShukraniSheet({required this.habitName, this.initial});

  @override
  State<_ShukraniSheet> createState() => _ShukraniSheetState();
}

class _ShukraniSheetState extends State<_ShukraniSheet> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(
      text: widget.initial != null ? '${widget.initial}' : '',
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _SheetBase(
      title: widget.habitName,
      icon: '📣',
      confirmEnabled: int.tryParse(_ctrl.text) != null,
      onConfirm: () =>
          Navigator.pop(context, int.tryParse(_ctrl.text)),
      content: _sheetInput(
        _ctrl,
        label: 'REACH / IMPRESSIONS TODAY',
        hint: '1000',
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      ),
    );
  }
}

// ── Chakula sheet ─────────────────────────────────────────────────────────────

class _ChakulaSheet extends StatefulWidget {
  final String? initial;
  const _ChakulaSheet({this.initial});

  @override
  State<_ChakulaSheet> createState() => _ChakulaSheetState();
}

class _ChakulaSheetState extends State<_ChakulaSheet> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initial ?? '');
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _ctrl,
      builder: (context, _) => _SheetBase(
        title: 'Work on Chakula',
        icon: '🍽️',
        confirmEnabled: _ctrl.text.trim().isNotEmpty,
        onConfirm: () =>
            Navigator.pop(context, _ctrl.text.trim()),
        content: _sheetInput(
          _ctrl,
          label: 'WHAT DID YOU DELIVER TODAY?',
          hint: 'Describe what you built or shipped',
          keyboardType: TextInputType.multiline,
          maxLines: 3,
        ),
      ),
    );
  }
}

// ── Savings sheet ─────────────────────────────────────────────────────────────

class _SavingsSheet extends StatefulWidget {
  final double initial;
  const _SavingsSheet({required this.initial});

  @override
  State<_SavingsSheet> createState() => _SavingsSheetState();
}

class _SavingsSheetState extends State<_SavingsSheet> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(
      text: widget.initial > 0
          ? widget.initial.toStringAsFixed(0)
          : '',
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _SheetBase(
      title: 'Save Any Amount',
      icon: '💰',
      confirmEnabled: double.tryParse(_ctrl.text) != null,
      onConfirm: () =>
          Navigator.pop(context, double.tryParse(_ctrl.text)),
      content: _sheetInput(
        _ctrl,
        label: 'AMOUNT SAVED TODAY',
        hint: '500',
        suffix: 'KES',
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      ),
    );
  }
}

// ── Workout sheet ─────────────────────────────────────────────────────────────

class _WorkoutSheet extends StatefulWidget {
  final WorkoutData? initial;
  final WorkoutData targets;

  const _WorkoutSheet({
    this.initial,
    required this.targets,
  });

  @override
  State<_WorkoutSheet> createState() => _WorkoutSheetState();
}

class _WorkoutSheetState extends State<_WorkoutSheet> {
  late final TextEditingController _pushups;
  late final TextEditingController _situps;
  late final TextEditingController _jj;

  @override
  void initState() {
    super.initState();
    _pushups = TextEditingController(
        text: '${widget.initial?.pushups ?? widget.targets.pushups}');
    _situps = TextEditingController(
        text: '${widget.initial?.situps ?? widget.targets.situps}');
    _jj = TextEditingController(
        text: '${widget.initial?.jumpingJacks ?? widget.targets.jumpingJacks}');
  }

  @override
  void dispose() {
    _pushups.dispose();
    _situps.dispose();
    _jj.dispose();
    super.dispose();
  }

  bool get _valid =>
      int.tryParse(_pushups.text) != null &&
      int.tryParse(_situps.text) != null &&
      int.tryParse(_jj.text) != null;

  WorkoutData get _result => WorkoutData(
        pushups: int.parse(_pushups.text),
        situps: int.parse(_situps.text),
        jumpingJacks: int.parse(_jj.text),
      );

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable:
          Listenable.merge([_pushups, _situps, _jj]),
      builder: (context, _) => _SheetBase(
        title: 'Workout',
        icon: '💪',
        confirmEnabled: _valid,
        onConfirm: () => Navigator.pop(context, _result),
        content: Column(
          children: [
            _WorkoutInput(
              label: 'PUSHUPS',
              ctrl: _pushups,
              target: widget.targets.pushups,
            ),
            const SizedBox(height: 12),
            _WorkoutInput(
              label: 'SITUPS',
              ctrl: _situps,
              target: widget.targets.situps,
            ),
            const SizedBox(height: 12),
            _WorkoutInput(
              label: 'JUMPING JACKS',
              ctrl: _jj,
              target: widget.targets.jumpingJacks,
            ),
          ],
        ),
      ),
    );
  }
}

class _WorkoutInput extends StatelessWidget {
  final String label;
  final TextEditingController ctrl;
  final int target;

  const _WorkoutInput({
    required this.label,
    required this.ctrl,
    required this.target,
  });

  @override
  Widget build(BuildContext context) {
    final val = int.tryParse(ctrl.text) ?? 0;
    final isAboveTarget = val >= target;

    return Row(
      children: [
        Expanded(
          flex: 3,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(
                      color: Colors.white38,
                      fontSize: 11,
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text('Target: $target',
                  style: const TextStyle(
                      color: Colors.white24, fontSize: 11)),
            ],
          ),
        ),
        Expanded(
          flex: 2,
          child: TextField(
            controller: ctrl,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly
            ],
            textAlign: TextAlign.center,
            style: TextStyle(
              color:
                  isAboveTarget ? const Color(0xFF00E676) : Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
            decoration: InputDecoration(
              suffixText: 'reps',
              suffixStyle: const TextStyle(
                  color: Colors.white38, fontSize: 12),
              filled: true,
              fillColor: const Color(0xFF0D0D1A),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(
                  color: isAboveTarget
                      ? const Color(0xFF00C853)
                      : const Color(0xFF2A2A4A),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(
                  color: isAboveTarget
                      ? const Color(0xFF00C853)
                      : const Color(0xFF2A2A4A),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(
                    color: Color(0xFFFF6B35), width: 1.5),
              ),
            ),
          ),
        ),
      ],
    );
  }
}


// ── WHY Cards Row ─────────────────────────────────────────────────────────────

class _WhyCardsRow extends StatelessWidget {
  final List<Habit> habits;
  final Map<String, WhyData?> whyCache;
  final String uid;
  final Future<void> Function(Habit) onTapEmpty;
  final Future<void> Function(Habit)? onTapFilled;

  const _WhyCardsRow({
    required this.habits,
    required this.whyCache,
    required this.uid,
    required this.onTapEmpty,
    this.onTapFilled,
  });

  @override
  Widget build(BuildContext context) {
    if (habits.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 210,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.zero,
        itemCount: habits.length,
        separatorBuilder: (context, index) => const SizedBox(width: 12),
        itemBuilder: (context, i) {
          final habit = habits[i];
          final loaded = whyCache.containsKey(habit.id);
          final why = whyCache[habit.id];

          if (!loaded) {
            // Still fetching — ghost card
            return _WhyCardShell(
              child: const Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFFFF6B35),
                  ),
                ),
              ),
            );
          }

          if (why == null) {
            return _EmptyWhyCard(habit: habit, onTap: () => onTapEmpty(habit));
          }

          return _WhyCard(
            habit: habit,
            why: why,
            onTap: onTapFilled != null ? () => onTapFilled!(habit) : null,
          );
        },
      ),
    );
  }
}

class _WhyCardShell extends StatelessWidget {
  final Widget child;
  const _WhyCardShell({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2A2A4A)),
      ),
      padding: const EdgeInsets.all(16),
      child: child,
    );
  }
}

class _WhyCard extends StatelessWidget {
  final Habit habit;
  final WhyData why;
  final VoidCallback? onTap;

  const _WhyCard({required this.habit, required this.why, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
      width: 220,
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: const Color(0xFFFF6B35).withValues(alpha: 0.25)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            habit.name,
            style: const TextStyle(
              color: Colors.white38,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Text(
              why.statement.toUpperCase(),
              style: const TextStyle(
                color: Color(0xFFFF6B35),
                fontSize: 11,
                fontWeight: FontWeight.bold,
                height: 1.55,
                letterSpacing: 0.3,
              ),
              overflow: TextOverflow.fade,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'SKIPPING THIS COSTS YOU:',
            style: TextStyle(
              color: Color(0xFFFF5555),
              fontSize: 9,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            why.q3,
            style: const TextStyle(
              color: Color(0xFFFF8888),
              fontSize: 10,
              height: 1.4,
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
      ),
    );
  }
}

class _EmptyWhyCard extends StatelessWidget {
  final Habit habit;
  final VoidCallback onTap;

  const _EmptyWhyCard({required this.habit, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 220,
        decoration: BoxDecoration(
          color: const Color(0xFF12122A),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: const Color(0xFF2A2A4A),
              style: BorderStyle.solid),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              habit.name,
              style: const TextStyle(
                color: Colors.white24,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
            const Spacer(),
            Text(
              "YOU HAVEN'T DEFINED WHY YOU'RE DOING ${habit.name.toUpperCase()}. TAP TO FIX THAT.",
              style: const TextStyle(
                color: Colors.white30,
                fontSize: 11,
                fontWeight: FontWeight.bold,
                height: 1.55,
                letterSpacing: 0.3,
              ),
            ),
            const Spacer(),
            Row(
              children: const [
                Icon(Icons.add_circle_outline,
                    color: Color(0xFFFF6B35), size: 14),
                SizedBox(width: 6),
                Text(
                  'Define your why',
                  style: TextStyle(
                    color: Color(0xFFFF6B35),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

