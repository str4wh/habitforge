import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/workout_data.dart';
import 'firestore_service.dart';
import 'notification_service.dart';

class ProgressionService {
  static const _prefsKey = 'last_progression_monday';

  // Starting floors — targets never drop below these
  static const _floorPushups = 50;
  static const _floorSitups = 50;
  static const _floorJJ = 60;

  /// Call on every WorkManager tick. No-ops unless it's Monday and
  /// progression hasn't already been applied this week.
  static Future<void> maybeRunMonday(String uid) async {
    final now = DateTime.now();
    if (now.weekday != DateTime.monday) return;

    // Guard: only run once per Monday
    final prefs = await SharedPreferences.getInstance();
    final todayKey = DateFormat('yyyy-MM-dd').format(now);
    if (prefs.getString(_prefsKey) == todayKey) return;
    await prefs.setString(_prefsKey, todayKey);

    // Count workout completions from Mon–Sun of last week
    final lastMonday = now.subtract(const Duration(days: 7));
    int workoutDays = 0;
    for (int i = 0; i < 7; i++) {
      final day = lastMonday.add(Duration(days: i));
      final log =
          await FirestoreService.fetchLog(uid, DateFormat('yyyy-MM-dd').format(day));
      if (log?.workout != null) workoutDays++;
    }

    // Fetch current targets
    final current = await FirestoreService.getWorkoutTargets(uid);

    // Apply progression rules
    final updated = _applyRules(current, workoutDays);

    // Persist updated targets
    await FirestoreService.setWorkoutTargets(uid, updated);

    // Fire the appropriate notification
    await NotificationService.fireProgressionNotification(workoutDays, updated);
  }

  static WorkoutData _applyRules(WorkoutData current, int workoutDays) {
    if (workoutDays == 7) {
      // Full week — bump by 5
      return WorkoutData(
        pushups: current.pushups + 5,
        situps: current.situps + 5,
        jumpingJacks: current.jumpingJacks + 5,
      );
    } else if (workoutDays >= 5) {
      // 5–6 days — flat
      return current;
    } else if (workoutDays >= 3) {
      // 3–4 days — drop by 5, floor at defaults
      return WorkoutData(
        pushups: (current.pushups - 5).clamp(_floorPushups, 9999),
        situps: (current.situps - 5).clamp(_floorSitups, 9999),
        jumpingJacks: (current.jumpingJacks - 5).clamp(_floorJJ, 9999),
      );
    } else {
      // <3 days — drop by 10, floor at defaults
      return WorkoutData(
        pushups: (current.pushups - 10).clamp(_floorPushups, 9999),
        situps: (current.situps - 10).clamp(_floorSitups, 9999),
        jumpingJacks: (current.jumpingJacks - 10).clamp(_floorJJ, 9999),
      );
    }
  }
}
