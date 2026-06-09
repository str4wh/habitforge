import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/week_utils.dart';
import 'firestore_service.dart';
import 'notification_service.dart';

class RolloverService {
  static const _prefsKey = 'last_rollover_date';

  /// Runs at most once per calendar day. Safe to call on app open or from
  /// WorkManager — the SharedPrefs guard prevents double-running.
  static Future<void> maybeRunMidnight(String uid) async {
    final now = DateTime.now();
    final prefs = await SharedPreferences.getInstance();
    final todayKey = DateFormat('yyyy-MM-dd').format(now);
    if (prefs.getString(_prefsKey) == todayKey) return;
    await prefs.setString(_prefsKey, todayKey);

    final weekKey = isoWeekKey(now);
    final triggered = await FirestoreService.incrementRollovers(uid, weekKey);

    for (final d in triggered) {
      await NotificationService.fireRolloverNotification(d.rolloverCount, d.text);
    }
  }
}
