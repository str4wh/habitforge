import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../main.dart' show kMaxContentWidth;
import '../models/habit_log.dart';
import '../providers/habits_provider.dart';
import '../providers/logs_provider.dart';

class MonthHeatmapScreen extends ConsumerStatefulWidget {
  const MonthHeatmapScreen({super.key});

  @override
  ConsumerState<MonthHeatmapScreen> createState() =>
      _MonthHeatmapScreenState();
}

class _MonthHeatmapScreenState extends ConsumerState<MonthHeatmapScreen> {
  late DateTime selectedMonth;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    selectedMonth = DateTime(now.year, now.month);
  }

  String get _monthKey =>
      '${selectedMonth.year}-${selectedMonth.month.toString().padLeft(2, '0')}';

  void _prevMonth() => setState(
      () => selectedMonth = DateTime(selectedMonth.year, selectedMonth.month - 1));

  void _nextMonth() {
    final now = DateTime.now();
    final next = DateTime(selectedMonth.year, selectedMonth.month + 1);
    if (next.isAfter(DateTime(now.year, now.month))) return;
    setState(() => selectedMonth = next);
  }

  bool get _canGoNext {
    final now = DateTime.now();
    return selectedMonth.year < now.year ||
        (selectedMonth.year == now.year &&
            selectedMonth.month < now.month);
  }

  @override
  Widget build(BuildContext context) {
    final logsAsync = ref.watch(monthLogsProvider(_monthKey));
    final activeCount = ref.watch(activeHabitsProvider).length;

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D1A),
        elevation: 0,
        title: const Text(
          'HabitForge',
          style: TextStyle(
            color: Color(0xFFFF6B35),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: kMaxContentWidth),
          child: Column(
            children: [
              _MonthNavBar(
                selectedMonth: selectedMonth,
                canGoNext: _canGoNext,
                onPrev: _prevMonth,
                onNext: _nextMonth,
              ),
              Expanded(
                child: logsAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) =>
                      Center(child: Text('Error: $e')),
                  data: (logs) => _HeatmapGrid(
                    month: selectedMonth,
                    logs: logs,
                    activeCount: activeCount > 0 ? activeCount : 9,
                  ),
                ),
              ),
              _Legend(),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Month nav bar ─────────────────────────────────────────────────────────────

class _MonthNavBar extends StatelessWidget {
  final DateTime selectedMonth;
  final bool canGoNext;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  const _MonthNavBar({
    required this.selectedMonth,
    required this.canGoNext,
    required this.onPrev,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF12122A),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left, color: Colors.white),
            onPressed: onPrev,
          ),
          Text(
            DateFormat('MMMM yyyy').format(selectedMonth),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.chevron_right,
              color: canGoNext ? Colors.white : Colors.white24,
            ),
            onPressed: canGoNext ? onNext : null,
          ),
        ],
      ),
    );
  }
}

// ── Heatmap grid ──────────────────────────────────────────────────────────────

class _HeatmapGrid extends StatelessWidget {
  final DateTime month;
  final Map<String, HabitLog> logs;
  final int activeCount;

  const _HeatmapGrid({
    required this.month,
    required this.logs,
    required this.activeCount,
  });

  Color _color(double pct) {
    if (pct <= 0) return const Color(0xFF1E1E3A);
    return Color.lerp(
      const Color(0xFFD32F2F),
      const Color(0xFF2E7D32),
      pct,
    )!;
  }

  @override
  Widget build(BuildContext context) {
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final firstWeekday = DateTime(month.year, month.month, 1).weekday;
    final leadingBlanks = firstWeekday - 1;
    final today = DateTime.now();
    final fmt = DateFormat('yyyy-MM-dd');
    final todayKey = fmt.format(today);

    const dayHeaders = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final rows = ((leadingBlanks + daysInMonth) / 7).ceil();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        children: [
          // Day-of-week header
          Row(
            children: dayHeaders
                .map(
                  (d) => Expanded(
                    child: Center(
                      child: Text(
                        d,
                        style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 8),
          // Grid
          Expanded(
            child: GridView.builder(
              physics: const NeverScrollableScrollPhysics(),
              shrinkWrap: true,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                mainAxisSpacing: 5,
                crossAxisSpacing: 5,
                childAspectRatio: 1,
              ),
              itemCount: rows * 7,
              itemBuilder: (context, index) {
                final dayIndex = index - leadingBlanks + 1;
                if (dayIndex < 1 || dayIndex > daysInMonth) {
                  return const SizedBox.shrink();
                }

                final date =
                    DateTime(month.year, month.month, dayIndex);
                final dateKey = fmt.format(date);
                final log = logs[dateKey];
                final completed = log?.completedHabits.length ?? 0;
                final pct =
                    activeCount > 0 ? completed / activeCount : 0.0;
                final isToday = dateKey == todayKey;
                final isFuture = date.isAfter(today);

                return Tooltip(
                  message: isFuture
                      ? ''
                      : log == null
                          ? 'No data'
                          : '$completed/$activeCount (${(pct * 100).round()}%)',
                  child: Container(
                    decoration: BoxDecoration(
                      color: isFuture
                          ? const Color(0xFF0D0D1A)
                          : _color(pct),
                      borderRadius: BorderRadius.circular(6),
                      border: isToday
                          ? Border.all(
                              color: const Color(0xFFFF6B35),
                              width: 2)
                          : null,
                    ),
                    child: Center(
                      child: Text(
                        '$dayIndex',
                        style: TextStyle(
                          color: isFuture
                              ? Colors.white12
                              : (pct > 0.4
                                  ? Colors.white
                                  : Colors.white54),
                          fontSize: 12,
                          fontWeight: isToday
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ── Legend ────────────────────────────────────────────────────────────────────

class _Legend extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('0%',
              style: TextStyle(color: Colors.white38, fontSize: 12)),
          const SizedBox(width: 8),
          ...List.generate(5, (i) {
            final pct = i / 4.0;
            return Container(
              width: 32,
              height: 14,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                color: Color.lerp(
                  const Color(0xFFD32F2F),
                  const Color(0xFF2E7D32),
                  pct,
                ),
                borderRadius: BorderRadius.circular(3),
              ),
            );
          }),
          const SizedBox(width: 8),
          const Text('100%',
              style: TextStyle(color: Colors.white38, fontSize: 12)),
        ],
      ),
    );
  }
}
