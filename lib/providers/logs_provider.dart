import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/habit_log.dart';
import '../services/firestore_service.dart';
import 'auth_provider.dart';

final _fmt = DateFormat('yyyy-MM-dd');

String get _today => _fmt.format(DateTime.now());

// Today's log (live stream)
final todayLogProvider = StreamProvider<HabitLog?>((ref) {
  final auth = ref.watch(authProvider);
  return auth.when(
    data: (user) {
      if (user == null) return const Stream.empty();
      return FirestoreService.logStream(user.uid, _today);
    },
    loading: () => const Stream.empty(),
    error: (e, _) => const Stream.empty(),
  );
});

// Month logs keyed by 'yyyy-MM'
final monthLogsProvider =
    FutureProvider.family<Map<String, HabitLog>, String>((ref, monthKey) async {
  final auth = await ref.watch(authProvider.future);
  if (auth == null) return {};
  final parts = monthKey.split('-');
  return FirestoreService.monthLogs(
    auth.uid,
    int.parse(parts[0]),
    int.parse(parts[1]),
  );
});

// All logs — used by global stats
final allLogsProvider = FutureProvider<Map<String, HabitLog>>((ref) async {
  final auth = await ref.watch(authProvider.future);
  if (auth == null) return {};
  return FirestoreService.allLogs(auth.uid);
});

// Savings target
final savingsTargetProvider = FutureProvider<double?>((ref) async {
  final auth = await ref.watch(authProvider.future);
  if (auth == null) return null;
  return FirestoreService.getSavingsTarget(auth.uid);
});

// ── Stats models ──────────────────────────────────────────────────────────────

class HabitStats {
  final int currentStreak;
  final double weeklyScore;
  final double cumulativeSavings;
  final String? bestDay;
  final double bestDayScore;

  const HabitStats({
    required this.currentStreak,
    required this.weeklyScore,
    required this.cumulativeSavings,
    required this.bestDay,
    required this.bestDayScore,
  });
}

final statsWithCountProvider =
    FutureProvider.family<HabitStats, int>((ref, activeCount) async {
  final logs = await ref.watch(allLogsProvider.future);
  return _computeStats(logs, activeCount);
});

HabitStats _computeStats(Map<String, HabitLog> logs, int activeCount) {
  if (logs.isEmpty || activeCount == 0) {
    return const HabitStats(
      currentStreak: 0,
      weeklyScore: 0,
      cumulativeSavings: 0,
      bestDay: null,
      bestDayScore: 0,
    );
  }

  final sortedDates = logs.keys.toList()..sort();
  final today = _fmt.format(DateTime.now());

  // Streak
  int streak = 0;
  var current = DateTime.now();
  for (int i = 0; i <= 365; i++) {
    final dateKey = _fmt.format(current);
    final log = logs[dateKey];
    final completed = log?.completedHabits.length ?? 0;
    if (completed >= activeCount) {
      streak++;
      current = current.subtract(const Duration(days: 1));
    } else {
      if (dateKey == today && streak == 0) {
        current = current.subtract(const Duration(days: 1));
        continue;
      }
      break;
    }
  }

  // Weekly score
  double weeklyTotal = 0;
  for (int i = 6; i >= 0; i--) {
    final d = DateTime.now().subtract(Duration(days: i));
    final key = _fmt.format(d);
    final log = logs[key];
    if (log != null && activeCount > 0) {
      weeklyTotal += log.completedHabits.length / activeCount;
    }
  }

  // Cumulative savings
  final cumulativeSavings =
      logs.values.fold(0.0, (sum, l) => sum + l.savingsAmount);

  // Best day
  String? bestDay;
  double bestDayScore = 0;
  for (final date in sortedDates) {
    final log = logs[date]!;
    final score =
        activeCount > 0 ? log.completedHabits.length / activeCount : 0.0;
    if (score > bestDayScore) {
      bestDayScore = score;
      bestDay = date;
    }
  }

  return HabitStats(
    currentStreak: streak,
    weeklyScore: weeklyTotal / 7,
    cumulativeSavings: cumulativeSavings,
    bestDay: bestDay,
    bestDayScore: bestDayScore,
  );
}
