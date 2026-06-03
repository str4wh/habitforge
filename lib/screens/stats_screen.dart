import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../main.dart' show kMaxContentWidth;
import '../models/habit.dart';
import '../models/habit_log.dart';
import '../models/workout_data.dart';
import '../providers/habits_provider.dart';
import '../providers/logs_provider.dart';
import '../utils/habit_utils.dart';

class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeCount = ref.watch(activeHabitsProvider).length;
    final habits = ref.watch(habitsProvider).maybeWhen(
        data: (h) => h, orElse: () => <Habit>[]);
    final statsAsync = ref.watch(statsWithCountProvider(activeCount));
    final targetAsync = ref.watch(savingsTargetProvider);

    final now = DateTime.now();
    final monthKey =
        '${now.year}-${now.month.toString().padLeft(2, '0')}';
    final monthLogsAsync = ref.watch(monthLogsProvider(monthKey));

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D1A),
        elevation: 0,
        title: const Text('HabitForge',
            style: TextStyle(
                color: Color(0xFFFF6B35),
                fontWeight: FontWeight.bold)),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints:
              const BoxConstraints(maxWidth: kMaxContentWidth),
          child: statsAsync.when(
            loading: () =>
                const Center(child: CircularProgressIndicator()),
            error: (e, _) =>
                Center(child: Text('Error: $e')),
            data: (stats) => monthLogsAsync.when(
              loading: () => const Center(
                  child: CircularProgressIndicator()),
              error: (e, _) =>
                  Center(child: Text('Error: $e')),
              data: (monthLogs) => _StatsBody(
                stats: stats,
                monthLogs: monthLogs,
                habits: habits,
                savingsTarget:
                    targetAsync.valueOrNull,
                activeCount: activeCount,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Body ──────────────────────────────────────────────────────────────────────

class _StatsBody extends StatelessWidget {
  final HabitStats stats;
  final Map<String, HabitLog> monthLogs;
  final List<Habit> habits;
  final double? savingsTarget;
  final int activeCount;

  const _StatsBody({
    required this.stats,
    required this.monthLogs,
    required this.habits,
    required this.savingsTarget,
    required this.activeCount,
  });

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width >= 600;

    final cards = [
      _CardData(
        label: 'CURRENT STREAK',
        value: '${stats.currentStreak}',
        unit: stats.currentStreak == 1 ? 'day' : 'days',
        icon: Icons.local_fire_department,
        color: stats.currentStreak > 0
            ? const Color(0xFFFF6B35)
            : Colors.white24,
        subtext: stats.currentStreak == 0
            ? 'Start today'
            : stats.currentStreak >= 7
                ? 'On a roll'
                : 'Keep going',
      ),
      _CardData(
        label: 'WEEKLY SCORE',
        value: '${(stats.weeklyScore * 100).round()}',
        unit: '%',
        icon: Icons.trending_up,
        color: _scoreColor(stats.weeklyScore),
        subtext: _weeklyLabel(stats.weeklyScore),
      ),
      _CardData(
        label: 'TOTAL SAVINGS',
        value: _fmt(stats.cumulativeSavings),
        unit: 'KES',
        icon: Icons.savings,
        color: const Color(0xFF00E676),
        subtext: stats.cumulativeSavings > 0
            ? 'Keep stacking'
            : 'Log first save',
      ),
      _CardData(
        label: 'BEST DAY',
        value: stats.bestDay != null
            ? '${(stats.bestDayScore * 100).round()}%'
            : '—',
        unit: '',
        icon: Icons.emoji_events,
        color: const Color(0xFFFFD600),
        subtext: stats.bestDay != null
            ? DateFormat('d MMM yyyy').format(
                DateFormat('yyyy-MM-dd').parse(stats.bestDay!))
            : 'No data yet',
      ),
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _sectionLabel('YOUR NUMBERS'),
          const SizedBox(height: 12),
          // Overview cards
          if (isWide)
            Row(
              children: cards
                  .map((c) => Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(right: 10),
                          child: _StatCard(data: c),
                        ),
                      ))
                  .toList(),
            )
          else ...[
            Row(children: [
              Expanded(child: _StatCard(data: cards[0])),
              const SizedBox(width: 12),
              Expanded(child: _StatCard(data: cards[1])),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: _StatCard(data: cards[2])),
              const SizedBox(width: 12),
              Expanded(child: _StatCard(data: cards[3])),
            ]),
          ],
          const SizedBox(height: 24),

          // Savings progress vs target
          if (savingsTarget != null && savingsTarget! > 0) ...[
            _sectionLabel('SAVINGS TARGET'),
            const SizedBox(height: 12),
            _SavingsTargetBar(
              saved: stats.cumulativeSavings,
              target: savingsTarget!,
            ),
            const SizedBox(height: 24),
          ],

          // Cold shower
          if (_hasAnyColdShower(monthLogs)) ...[
            _sectionLabel('COLD SHOWER — THIS MONTH'),
            const SizedBox(height: 12),
            _ColdShowerStats(logs: monthLogs),
            const SizedBox(height: 24),
          ],

          // Shukrani reach
          if (_hasAnyShukrani(monthLogs)) ...[
            _sectionLabel('SHUKRANI REACH — THIS WEEK'),
            const SizedBox(height: 12),
            _ShukraniReachTable(
                logs: monthLogs, habits: habits),
            const SizedBox(height: 24),
          ],

          // Workout progression
          if (_hasAnyWorkout(monthLogs)) ...[
            _sectionLabel('WORKOUT PROGRESSION — THIS MONTH'),
            const SizedBox(height: 12),
            _WorkoutGraph(logs: monthLogs),
            const SizedBox(height: 24),
          ],

          // Chakula deliverables
          if (_hasChakulaDeliverables(monthLogs)) ...[
            _sectionLabel('CHAKULA DELIVERABLES — THIS MONTH'),
            const SizedBox(height: 12),
            _ChakulaDeliverablesList(logs: monthLogs),
            const SizedBox(height: 24),
          ],

          // Weekly bar
          _WeeklyBar(weeklyScore: stats.weeklyScore),
          const SizedBox(height: 20),
          _MotivationBanner(
              streak: stats.currentStreak,
              weekly: stats.weeklyScore),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  bool _hasAnyColdShower(Map<String, HabitLog> logs) =>
      logs.values.any((l) => l.coldShowerMinutes != null);

  bool _hasAnyShukrani(Map<String, HabitLog> logs) =>
      logs.values.any((l) => l.shukraniReach.isNotEmpty);

  bool _hasAnyWorkout(Map<String, HabitLog> logs) =>
      logs.values.any((l) => l.workout != null);

  bool _hasChakulaDeliverables(Map<String, HabitLog> logs) =>
      logs.values
          .any((l) => l.chakulaDeliverable?.isNotEmpty == true);

  Color _scoreColor(double s) {
    if (s >= 0.8) return const Color(0xFF00E676);
    if (s >= 0.5) return const Color(0xFFFF6B35);
    return const Color(0xFFD32F2F);
  }

  String _weeklyLabel(double s) {
    if (s >= 0.9) return 'Exceptional';
    if (s >= 0.7) return 'Solid week';
    if (s >= 0.5) return 'Halfway there';
    if (s > 0) return 'Needs work';
    return 'No data yet';
  }

  String _fmt(double amount) {
    if (amount >= 1000000) {
      return '${(amount / 1000000).toStringAsFixed(1)}M';
    }
    if (amount >= 1000) {
      return '${(amount / 1000).toStringAsFixed(1)}K';
    }
    return amount.toStringAsFixed(0);
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

Widget _sectionLabel(String text) => Text(
      text,
      style: const TextStyle(
        color: Colors.white38,
        fontSize: 11,
        letterSpacing: 2,
        fontWeight: FontWeight.bold,
      ),
    );

// ── Savings target bar ────────────────────────────────────────────────────────

class _SavingsTargetBar extends StatelessWidget {
  final double saved;
  final double target;
  const _SavingsTargetBar(
      {required this.saved, required this.target});

  @override
  Widget build(BuildContext context) {
    final pct = (saved / target).clamp(0.0, 1.0);
    final fmt = NumberFormat('#,###');
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF12122A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2A2A4A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('KES ${fmt.format(saved)} saved',
                  style: const TextStyle(
                      color: Color(0xFF00E676),
                      fontWeight: FontWeight.bold,
                      fontSize: 16)),
              Text('Target: KES ${fmt.format(target)}',
                  style: const TextStyle(
                      color: Colors.white38, fontSize: 13)),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 12,
              backgroundColor: const Color(0xFF2A2A4A),
              valueColor: const AlwaysStoppedAnimation<Color>(
                  Color(0xFF00E676)),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${(pct * 100).round()}% of target reached',
            style: const TextStyle(
                color: Colors.white38, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

// ── Cold shower stats ─────────────────────────────────────────────────────────

class _ColdShowerStats extends StatelessWidget {
  final Map<String, HabitLog> logs;
  const _ColdShowerStats({required this.logs});

  @override
  Widget build(BuildContext context) {
    final entries = logs.values
        .where((l) => l.coldShowerMinutes != null)
        .toList();
    final avg = entries.isEmpty
        ? 0.0
        : entries
                .map((l) => l.coldShowerMinutes!)
                .reduce((a, b) => a + b) /
            entries.length;
    final best =
        entries.isEmpty ? 0.0 : entries.map((l) => l.coldShowerMinutes!).reduce(max);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF12122A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2A2A4A)),
      ),
      child: Row(
        children: [
          _MiniStat(
            label: 'AVERAGE',
            value: avg.toStringAsFixed(1),
            unit: 'min',
            color: const Color(0xFF42A5F5),
          ),
          Container(
              width: 1, height: 40, color: const Color(0xFF2A2A4A)),
          _MiniStat(
            label: 'LONGEST',
            value: best.toStringAsFixed(1),
            unit: 'min',
            color: const Color(0xFF00E676),
          ),
          Container(
              width: 1, height: 40, color: const Color(0xFF2A2A4A)),
          _MiniStat(
            label: 'SESSIONS',
            value: '${entries.length}',
            unit: 'this month',
            color: const Color(0xFFFF6B35),
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final Color color;

  const _MiniStat(
      {required this.label,
      required this.value,
      required this.unit,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(label,
              style: const TextStyle(
                  color: Colors.white38,
                  fontSize: 10,
                  letterSpacing: 1)),
          const SizedBox(height: 6),
          Text(value,
              style: TextStyle(
                  color: color,
                  fontSize: 24,
                  fontWeight: FontWeight.bold)),
          Text(unit,
              style: const TextStyle(
                  color: Colors.white38, fontSize: 11)),
        ],
      ),
    );
  }
}

// ── Shukrani reach table ──────────────────────────────────────────────────────

class _ShukraniReachTable extends StatelessWidget {
  final Map<String, HabitLog> logs;
  final List<Habit> habits;
  const _ShukraniReachTable(
      {required this.logs, required this.habits});

  @override
  Widget build(BuildContext context) {
    // Build per-platform weekly totals
    final weekStart = DateTime.now().subtract(const Duration(days: 6));
    final weekLogs = logs.entries.where((e) {
      final d = DateFormat('yyyy-MM-dd').parse(e.key);
      return !d.isBefore(DateFormat('yyyy-MM-dd').parse(
          DateFormat('yyyy-MM-dd').format(weekStart)));
    }).toList();

    // Map habitId → name for shukrani habits
    final shukraniHabits = habits
        .where((h) => habitTypeFor(h.name) == HabitType.shukrani)
        .toList();

    // Aggregate
    final weeklyReach = <String, int>{}; // habitId → total
    final monthlyReach = <String, int>{};
    for (final log in logs.values) {
      for (final entry in log.shukraniReach.entries) {
        monthlyReach[entry.key] =
            (monthlyReach[entry.key] ?? 0) + entry.value;
      }
    }
    for (final e in weekLogs) {
      for (final entry in e.value.shukraniReach.entries) {
        weeklyReach[entry.key] =
            (weeklyReach[entry.key] ?? 0) + entry.value;
      }
    }

    if (shukraniHabits.isEmpty) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF12122A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2A2A4A)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Row(
              children: const [
                Expanded(
                    child: Text('PLATFORM',
                        style: TextStyle(
                            color: Colors.white38,
                            fontSize: 10,
                            letterSpacing: 1))),
                SizedBox(
                    width: 90,
                    child: Text('THIS WEEK',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: Colors.white38,
                            fontSize: 10,
                            letterSpacing: 1))),
                SizedBox(
                    width: 90,
                    child: Text('THIS MONTH',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: Colors.white38,
                            fontSize: 10,
                            letterSpacing: 1))),
              ],
            ),
          ),
          const Divider(color: Color(0xFF2A2A4A), height: 1),
          ...shukraniHabits.map((h) {
            final wk = weeklyReach[h.id] ?? 0;
            final mo = monthlyReach[h.id] ?? 0;
            return Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text(h.name,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 13)),
                  ),
                  SizedBox(
                    width: 90,
                    child: Text(
                      wk > 0
                          ? NumberFormat('#,###').format(wk)
                          : '—',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: wk > 0
                            ? const Color(0xFF00E676)
                            : Colors.white24,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 90,
                    child: Text(
                      mo > 0
                          ? NumberFormat('#,###').format(mo)
                          : '—',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: mo > 0
                            ? const Color(0xFFFF6B35)
                            : Colors.white24,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ── Workout line graph ────────────────────────────────────────────────────────

class _WorkoutGraph extends StatelessWidget {
  final Map<String, HabitLog> logs;
  const _WorkoutGraph({required this.logs});

  @override
  Widget build(BuildContext context) {
    final points = logs.entries
        .where((e) => e.value.workout != null)
        .map((e) => (
              day: int.parse(e.key.split('-').last),
              data: e.value.workout!,
            ))
        .toList()
      ..sort((a, b) => a.day.compareTo(b.day));

    if (points.isEmpty) {
      return const _EmptySection(
          message: 'Complete your first workout to see progress');
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      decoration: BoxDecoration(
        color: const Color(0xFF12122A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2A2A4A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 160,
            child: CustomPaint(
              size: const Size(double.infinity, 160),
              painter: _WorkoutLinePainter(points: points),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              _LegendDot(
                  color: Color(0xFFFF6B35), label: 'Pushups'),
              SizedBox(width: 16),
              _LegendDot(
                  color: Color(0xFF42A5F5), label: 'Situps'),
              SizedBox(width: 16),
              _LegendDot(
                  color: Color(0xFF66BB6A),
                  label: 'Jumping Jacks'),
            ],
          ),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(
          width: 10, height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 5),
      Text(label,
          style:
              const TextStyle(color: Colors.white38, fontSize: 11)),
    ]);
  }
}

class _WorkoutLinePainter extends CustomPainter {
  final List<({int day, WorkoutData data})> points;
  const _WorkoutLinePainter({required this.points});

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    final maxVal = points
        .map((p) =>
            max(p.data.pushups, max(p.data.situps, p.data.jumpingJacks)))
        .reduce(max)
        .toDouble();
    if (maxVal == 0) return;

    final paddedMax = maxVal * 1.15;

    // Grid lines
    final gridPaint = Paint()
      ..color = Colors.white12
      ..strokeWidth = 0.5;
    for (int i = 1; i <= 4; i++) {
      final y = size.height * (1 - i / 4);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    _drawSeries(canvas, size, paddedMax,
        points.map((p) => p.data.pushups.toDouble()).toList(),
        const Color(0xFFFF6B35));
    _drawSeries(canvas, size, paddedMax,
        points.map((p) => p.data.situps.toDouble()).toList(),
        const Color(0xFF42A5F5));
    _drawSeries(canvas, size, paddedMax,
        points.map((p) => p.data.jumpingJacks.toDouble()).toList(),
        const Color(0xFF66BB6A));
  }

  void _drawSeries(Canvas canvas, Size size, double maxVal,
      List<double> values, Color color) {
    if (values.isEmpty) return;

    final linePaint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final dotPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path();
    for (int i = 0; i < values.length; i++) {
      final x = values.length == 1
          ? size.width / 2
          : i / (values.length - 1) * size.width;
      final y = size.height * (1 - values[i] / maxVal);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
      canvas.drawCircle(Offset(x, y), 3.5, dotPaint);
    }
    canvas.drawPath(path, linePaint);
  }

  @override
  bool shouldRepaint(covariant _WorkoutLinePainter old) =>
      old.points != points;
}

// ── Chakula deliverables ──────────────────────────────────────────────────────

class _ChakulaDeliverablesList extends StatelessWidget {
  final Map<String, HabitLog> logs;
  const _ChakulaDeliverablesList({required this.logs});

  @override
  Widget build(BuildContext context) {
    final entries = logs.entries
        .where((e) => e.value.chakulaDeliverable?.isNotEmpty == true)
        .toList()
      ..sort((a, b) => b.key.compareTo(a.key)); // newest first

    if (entries.isEmpty) {
      return const _EmptySection(
          message: 'Log your first Chakula deliverable');
    }

    return Container(
      constraints: const BoxConstraints(maxHeight: 320),
      decoration: BoxDecoration(
        color: const Color(0xFF12122A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2A2A4A)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: ListView.separated(
          shrinkWrap: true,
          padding: EdgeInsets.zero,
          itemCount: entries.length,
          separatorBuilder: (ctx, idx) =>
              const Divider(color: Color(0xFF2A2A4A), height: 1),
          itemBuilder: (_, i) {
            final date = DateFormat('d MMM').format(
                DateFormat('yyyy-MM-dd').parse(entries[i].key));
            return Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 52,
                    child: Text(date,
                        style: const TextStyle(
                            color: Color(0xFFFF6B35),
                            fontSize: 12,
                            fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      entries[i].value.chakulaDeliverable!,
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 13),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

// ── Weekly bar ────────────────────────────────────────────────────────────────

class _WeeklyBar extends StatelessWidget {
  final double weeklyScore;
  const _WeeklyBar({required this.weeklyScore});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF12122A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2A2A4A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionLabel('THIS WEEK'),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: weeklyScore,
              minHeight: 12,
              backgroundColor: const Color(0xFF2A2A4A),
              valueColor: AlwaysStoppedAnimation<Color>(
                weeklyScore >= 0.8
                    ? const Color(0xFF00E676)
                    : weeklyScore >= 0.5
                        ? const Color(0xFFFF6B35)
                        : const Color(0xFFD32F2F),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${(weeklyScore * 100).round()}% of possible habits completed',
            style: const TextStyle(
                color: Colors.white38, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

// ── Overview cards ────────────────────────────────────────────────────────────

class _CardData {
  final String label, value, unit, subtext;
  final IconData icon;
  final Color color;
  const _CardData(
      {required this.label,
      required this.value,
      required this.unit,
      required this.icon,
      required this.color,
      required this.subtext});
}

class _StatCard extends StatelessWidget {
  final _CardData data;
  const _StatCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF12122A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2A2A4A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(data.label,
                    style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 10,
                        letterSpacing: 1.1,
                        fontWeight: FontWeight.bold)),
              ),
              Icon(data.icon, color: data.color, size: 18),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Flexible(
                child: Text(data.value,
                    style: TextStyle(
                        color: data.color,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        height: 1)),
              ),
              if (data.unit.isNotEmpty) ...[
                const SizedBox(width: 4),
                Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Text(data.unit,
                      style: TextStyle(
                          color: data.color.withAlpha(160),
                          fontSize: 13)),
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          Text(data.subtext,
              style: const TextStyle(
                  color: Colors.white38, fontSize: 11),
              overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

// ── Empty section placeholder ─────────────────────────────────────────────────

class _EmptySection extends StatelessWidget {
  final String message;
  const _EmptySection({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF12122A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2A2A4A)),
      ),
      child: Center(
        child: Text(message,
            style: const TextStyle(
                color: Colors.white24, fontSize: 13)),
      ),
    );
  }
}

// ── Motivation banner ─────────────────────────────────────────────────────────

class _MotivationBanner extends StatelessWidget {
  final int streak;
  final double weekly;
  const _MotivationBanner(
      {required this.streak, required this.weekly});

  String get _message {
    if (streak >= 21) {
      return "Three weeks straight. You're building something real.";
    }
    if (streak >= 7) {
      return 'A week of consistency. Most people quit before this.';
    }
    if (streak >= 3) {
      return "Three days in a row. That's how habits actually start.";
    }
    if (weekly >= 0.8) return 'Strong week. Show up again tomorrow.';
    if (weekly >= 0.5) {
      return "Decent week. Not enough to change your life yet.";
    }
    return "The gap between who you are and who you want to be is daily decisions.";
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2A2A4A)),
      ),
      child: Row(
        children: [
          const Icon(Icons.format_quote,
              color: Color(0xFFFF6B35), size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Text(_message,
                style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    fontStyle: FontStyle.italic,
                    height: 1.5)),
          ),
        ],
      ),
    );
  }
}
