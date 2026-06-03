import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../main.dart' show kMaxContentWidth;
import '../models/habit.dart';
import '../models/habit_log.dart';
import '../models/workout_data.dart';
import '../providers/auth_provider.dart';
import '../providers/habits_provider.dart';
import '../providers/logs_provider.dart';
import '../services/firestore_service.dart';
import '../services/notification_service.dart';
import '../utils/habit_utils.dart';

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
      final target =
          await FirestoreService.getSavingsTarget(user.uid);
      if (target == null && mounted) {
        _showTargetDialog(context, user.uid);
      }
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
            onPressed: () => Navigator.pop(ctx),
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

class _CheckinBody extends StatefulWidget {
  final String uid;
  final List<Habit> activeHabits;
  final HabitLog? existingLog;

  const _CheckinBody({
    required this.uid,
    required this.activeHabits,
    required this.existingLog,
  });

  @override
  State<_CheckinBody> createState() => _CheckinBodyState();
}

class _CheckinBodyState extends State<_CheckinBody> {
  late List<String> _completedIds;
  double _savingsAmount = 0;
  double? _coldShowerMinutes;
  Map<String, int> _shukraniReach = {};
  String? _chakulaDeliverable;
  WorkoutData? _workout;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadFromLog(widget.existingLog);
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

  Future<void> _handleHabitTap(Habit habit) async {
    final type = habitTypeFor(habit.name);

    // Uncheck — always immediate
    if (_completedIds.contains(habit.id)) {
      setState(() => _completedIds.remove(habit.id));
      return;
    }

    // Simple check — no sheet needed
    if (!habitNeedsSheet(type)) {
      setState(() => _completedIds.add(habit.id));
      return;
    }

    // Show appropriate bottom sheet
    final confirmed = await _showSheet(habit, type);
    if (confirmed && mounted) {
      setState(() => _completedIds.add(habit.id));
    }
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
          builder: (_) => _WorkoutSheet(initial: _workout),
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

  Future<void> _save() async {
    setState(() => _saving = true);
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
      if (!kIsWeb &&
          _completedIds.length >= widget.activeHabits.length) {
        await NotificationService.cancelTodayRemaining();
      }
    } finally {
      if (mounted) setState(() => _saving = false);
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
                  ...active.map((habit) => _HabitTile(
                        habit: habit,
                        checked: _completedIds.contains(habit.id),
                        subtitle: _subtitleFor(habit),
                        onTap: () => _handleHabitTap(habit),
                      )),
                  const SizedBox(height: 24),
                  _SaveButton(
                    saving: _saving,
                    onPressed: _save,
                  ),
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

  const _HabitTile({
    required this.habit,
    required this.checked,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
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

// ── Save button ───────────────────────────────────────────────────────────────

class _SaveButton extends StatelessWidget {
  final bool saving;
  final VoidCallback onPressed;
  const _SaveButton({required this.saving, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: saving ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFFF6B35),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
          disabledBackgroundColor: const Color(0xFF3A3A5A),
        ),
        child: saving
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white))
            : const Text('SAVE CHECK-IN',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1)),
      ),
    );
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
  const _WorkoutSheet({this.initial});

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
        text: '${widget.initial?.pushups ?? 50}');
    _situps = TextEditingController(
        text: '${widget.initial?.situps ?? 50}');
    _jj = TextEditingController(
        text: '${widget.initial?.jumpingJacks ?? 60}');
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
              target: 50,
            ),
            const SizedBox(height: 12),
            _WorkoutInput(
              label: 'SITUPS',
              ctrl: _situps,
              target: 50,
            ),
            const SizedBox(height: 12),
            _WorkoutInput(
              label: 'JUMPING JACKS',
              ctrl: _jj,
              target: 60,
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
