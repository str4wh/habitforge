import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'firestore_service.dart';
import '../models/workout_data.dart';
import '../utils/savings_velocity.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Get this from Firebase Console →
//   Project Settings → Cloud Messaging → Web push certificates
//   → Generate key pair  (copy the Key pair value)
// ─────────────────────────────────────────────────────────────────────────────
const _vapidKey = 'BOtmUGa_QHcAsMBYQCztDjHD9CvnHz-q_IQ_fX64TfZd_jLoloGmiCRasPIulVoFZPwJZY3-EEmeGylFbA6RHi0';

class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();

  static const _channel = AndroidNotificationChannel(
    'habitforge_daily',
    'HabitForge Daily',
    description: 'Daily habit reminders',
    importance: Importance.high,
  );

  static const _schedule = [
    (1, 6, 0, "You're awake. Now stop wasting the first hour of your day."),
    (2, 12, 0, "Halfway through the day. How many habits done? Be honest."),
    (3, 18, 0, "You have 2 hours before you run out of excuses for today."),
    (4, 21, 0, "You didn't finish today's habits did you? Log them anyway."),
    (5, 22, 0, "Another day gone. Was it worth it or did you just survive it?"),
  ];

  // Shame notifications: (notifId, habitName, deadlineHour, deadlineMinute, message)
  static const _shameData = [
    (100, 'Pray 2x', 9, 0,
        "You've been awake for hours and haven't prayed once. What exactly are you waiting for?"),
    (101, 'Cold Shower', 8, 0,
        "You skipped the cold shower again. Warm showers are for people with no goals."),
    (102, 'Work on Chakula', 17, 0,
        "You haven't logged a single Chakula deliverable today. What did you actually do?"),
    (103, 'Post Shukrani', 14, 0,
        "Shukrani won't market itself. You've been silent all day."),
    (104, 'Tweet Shukrani', 14, 0,
        "Still no tweet. Your competitors posted hours ago."),
    (105, 'Reddit Shukrani', 15, 0,
        "Reddit post missing. Consistency is what you said you wanted, remember?"),
    (106, 'Post on Uncles', 15, 0,
        "No Uncles post today. You're building nothing by staying quiet."),
    (107, 'Save Any Amount', 20, 0,
        "You haven't saved a single shilling today. Where did your money go?"),
    (108, 'Workout', 19, 0,
        "No workout logged. 50 pushups takes 3 minutes. You had 1,440 of them today."),
  ];

  static const _endOfDayId = 109;
  static const _sundayPlanId = 111;
  static const _sundayUrgentId = 112;
  static const _sundayReviewId = 113;
  static const _rollover3Id = 200;
  static const _rollover5Id = 201;

  // ── Android / iOS native notifications ────────────────────────────────────

  static Future<void> init() async {
    if (kIsWeb) return;

    tz.initializeTimeZones();
    final localTz = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(localTz));

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    await _plugin.initialize(
      const InitializationSettings(
          android: androidSettings, iOS: iosSettings),
    );

    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);
  }

  static Future<void> scheduleAll() async {
    if (kIsWeb) return;
    await _plugin.cancelAll();
    for (final (id, hour, minute, message) in _schedule) {
      await _plugin.zonedSchedule(
        id,
        'HabitForge',
        message,
        _nextInstance(hour, minute),
        NotificationDetails(
          android: AndroidNotificationDetails(
            _channel.id,
            _channel.name,
            channelDescription: _channel.description,
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: const DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    }
    await scheduleSundayReminders();
    await scheduleWeeklyReviewReminder();
  }

  // ── Savings velocity notification (ID 6, 8 PM, one-shot) ─────────────────

  /// Fetches today's month savings + target, then schedules or cancels
  /// the 8 PM savings-velocity push (Android only; web is handled server-side).
  /// Safe to call on every app launch — reschedules with fresh data each time.
  static Future<void> scheduleSavingsVelocityNotification(String uid) async {
    if (kIsWeb) return;
    const id = 6;
    await _plugin.cancel(id);

    final target = await FirestoreService.getSavingsTarget(uid);
    if (target == null || target <= 0) return;

    final now = DateTime.now();
    final monthLogs =
        await FirestoreService.monthLogs(uid, now.year, now.month);
    final monthSaved =
        monthLogs.values.fold(0.0, (s, l) => s + l.savingsAmount);

    final velocity =
        computeVelocity(monthSaved: monthSaved, target: target, now: now);

    // Skip if projected is at or above 90 % of target
    if (velocity.projected >= target * 0.9) return;

    final body = buildVelocityNotificationBody(velocity);

    await _plugin.zonedSchedule(
      id,
      'HabitForge',
      body,
      _nextInstance(20, 0), // 8 PM
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      // No matchDateTimeComponents — one-shot; rescheduled on next app launch
    );
  }

  static Future<void> cancelTodayRemaining() async {
    if (kIsWeb) return;
    await _plugin.cancelAll();
    final now = tz.TZDateTime.now(tz.local);
    for (final (id, hour, minute, message) in _schedule) {
      final todayAt = tz.TZDateTime(
          tz.local, now.year, now.month, now.day, hour, minute);
      final startTime = todayAt.isAfter(now)
          ? todayAt.add(const Duration(days: 1))
          : _nextInstance(hour, minute);
      await _plugin.zonedSchedule(
        id,
        'HabitForge',
        message,
        startTime,
        NotificationDetails(
          android: AndroidNotificationDetails(
            _channel.id,
            _channel.name,
            channelDescription: _channel.description,
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: const DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    }
  }

  static tz.TZDateTime _nextInstance(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
        tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  // ── Web push via FCM ───────────────────────────────────────────────────────

  /// Call once after anonymous sign-in on web.
  /// Requests browser permission, saves the FCM token to Firestore.
  static Future<void> initWeb(String uid) async {
    if (!kIsWeb) return;
    try {
      final messaging = FirebaseMessaging.instance;

      final settings = await messaging.requestPermission(
        alert: true,
        sound: true,
        badge: true,
      );

      if (settings.authorizationStatus !=
          AuthorizationStatus.authorized) {
        return; // user denied — respect it
      }

      final token = await messaging.getToken(vapidKey: _vapidKey);
      if (token != null) await _saveWebToken(uid, token);

      // Keep token fresh
      messaging.onTokenRefresh
          .listen((t) => _saveWebToken(uid, t));
    } catch (_) {
      // Fail silently — native notifications still work on Android
    }
  }

  static Future<void> _saveWebToken(String uid, String token) async {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('meta')
        .doc('fcmToken')
        .set({
      'token': token,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // ── Sunday planning reminders ─────────────────────────────────────────────

  static Future<void> scheduleSundayReminders() async {
    if (kIsWeb) return;
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channel.id, _channel.name,
        channelDescription: _channel.description,
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: const DarwinNotificationDetails(),
    );
    await _plugin.zonedSchedule(
      _sundayPlanId,
      'HabitForge',
      'Plan your week now. No excuses. Unplanned weeks fail.',
      _nextWeekday(DateTime.sunday, 19, 0),
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
    );
    await _plugin.zonedSchedule(
      _sundayUrgentId,
      'HabitForge',
      "It is 9PM. You still have not planned your week. "
          "People who don't plan fail. Open the app.",
      _nextWeekday(DateTime.sunday, 21, 0),
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
    );
  }

  static Future<void> cancelSundayUrgentReminder() async {
    if (kIsWeb) return;
    await _plugin.cancel(_sundayUrgentId);
  }

  static Future<void> scheduleWeeklyReviewReminder() async {
    if (kIsWeb) return;
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channel.id, _channel.name,
        channelDescription: _channel.description,
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: const DarwinNotificationDetails(),
    );
    await _plugin.zonedSchedule(
      _sundayReviewId,
      'HabitForge',
      'You skipped your weekly review. That means you learned nothing from this week. Open the app.',
      _nextWeekday(DateTime.sunday, 23, 0),
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
    );
  }

  static Future<void> cancelWeeklyReviewReminder() async {
    if (kIsWeb) return;
    await _plugin.cancel(_sundayReviewId);
  }

  static tz.TZDateTime _nextWeekday(int weekday, int hour, int minute) {
    var dt = tz.TZDateTime.now(tz.local);
    // Advance until we hit the target weekday
    while (dt.weekday != weekday) {
      dt = dt.add(const Duration(days: 1));
    }
    dt = tz.TZDateTime(tz.local, dt.year, dt.month, dt.day, hour, minute);
    if (dt.isBefore(tz.TZDateTime.now(tz.local))) {
      dt = dt.add(const Duration(days: 7));
    }
    return dt;
  }

  // ── Rollover notifications ─────────────────────────────────────────────────

  static Future<void> fireRolloverNotification(
      int days, String deliverableText) async {
    if (kIsWeb) return;
    final String body;
    if (days == 3) {
      body = '"$deliverableText" has rolled over 3 days in a row. '
          'You are either avoiding this or it is too big to complete as written. '
          'Break it into smaller steps or admit you will not do it.';
    } else {
      body = '5 days. "$deliverableText" has sat undone for 5 days. '
          'This is not a planning problem. This is an avoidance problem. '
          'Deal with it today or delete it and be honest with yourself.';
    }
    final id = days == 3 ? _rollover3Id : _rollover5Id;
    await _plugin.show(
      id,
      'HabitForge',
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id, _channel.name,
          channelDescription: _channel.description,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
    );
  }

  // ── Shame notifications ───────────────────────────────────────────────────

  /// Called on app launch and after each save. Schedules deadline shame
  /// notifications for every habit NOT yet in [completedHabitNames], and
  /// cancels them for habits that are already logged.
  static Future<void> scheduleShameNotifications(
    List<String> completedHabitNames, {
    Map<String, int> incompleteDeliverablesByName = const {},
  }) async {
    if (kIsWeb) return;
    // Persist deliverable counts for Layer 3 (read inside _scheduleShameIfBeforeDeadline)
    for (final entry in incompleteDeliverablesByName.entries) {
      await saveDeliverableCount(entry.key, entry.value);
    }
    for (final (id, name, hour, minute, message) in _shameData) {
      if (completedHabitNames.contains(name)) {
        await _plugin.cancel(id);
        await saveDeliverableCount(name, 0); // clear stale count
      } else {
        await _scheduleShameIfBeforeDeadline(id, name, hour, minute, message);
      }
    }
  }

  /// Cancel a single habit's shame notification the moment it is checked off.
  static Future<void> cancelShameNotification(String habitName) async {
    if (kIsWeb) return;
    for (final (id, name, _, _, _) in _shameData) {
      if (name == habitName) {
        await _plugin.cancel(id);
        return;
      }
    }
  }

  /// Re-schedule a single habit's shame notification when it is unchecked
  /// (only fires if the deadline hasn't already passed today).
  static Future<void> rescheduleShameNotification(String habitName) async {
    if (kIsWeb) return;
    for (final (id, name, hour, minute, message) in _shameData) {
      if (name == habitName) {
        await _scheduleShameIfBeforeDeadline(id, name, hour, minute, message);
        return;
      }
    }
  }

  /// Persist the Q3 cost line so it can be appended to future shame messages.
  static Future<void> saveCostLine(
      String habitName, String costLine) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('why_cost_$habitName', costLine);
  }

  static Future<String?> _getCostLine(String habitName) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('why_cost_$habitName');
  }

  /// Persist incomplete deliverable count per habit for Layer 3 notifications.
  static Future<void> saveDeliverableCount(
      String habitName, int count) async {
    final prefs = await SharedPreferences.getInstance();
    if (count > 0) {
      await prefs.setInt('deliverable_count_$habitName', count);
    } else {
      await prefs.remove('deliverable_count_$habitName');
    }
  }

  static Future<int> _getDeliverableCount(String habitName) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('deliverable_count_$habitName') ?? 0;
  }

  static Future<void> _scheduleShameIfBeforeDeadline(
      int id, String habitName, int hour, int minute, String baseMessage) async {
    final now = tz.TZDateTime.now(tz.local);
    final deadline =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (now.isAfter(deadline)) return; // deadline already passed today

    // Layer 2: cost of failure (Q3) or WHY nudge
    final cost = await _getCostLine(habitName);
    final layer2 = cost != null
        ? '\nYou said skipping this costs you: $cost'
        : '\nYou have not even defined why you are doing this. That is its own problem.';

    // Layer 3: incomplete deliverables for this habit this week
    final incompleteCount = await _getDeliverableCount(habitName);
    final layer3 = incompleteCount > 0
        ? '\nYou also have $incompleteCount unfinished deliverable${incompleteCount == 1 ? '' : 's'} for this habit this week. You are falling behind on your own plan.'
        : '';

    final body = '$baseMessage$layer2$layer3';

    await _plugin.cancel(id);
    await _plugin.zonedSchedule(
      id,
      'HabitForge',
      body,
      deadline,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      // No matchDateTimeComponents — one-shot for today only
    );
  }

  /// Schedule the 10:30 PM end-of-day shame check. Pass the current
  /// [done] count so the right message is chosen at schedule time.
  /// Cancels the notification entirely if [done] >= 6.
  // ── Monday workout progression notification ───────────────────────────────

  static Future<void> fireProgressionNotification(
      int workoutDays, WorkoutData targets) async {
    if (kIsWeb) return;
    final String body;
    if (workoutDays == 7) {
      body = 'Your workout targets increased to ${targets.pushups} pushups, '
          '${targets.situps} situps, ${targets.jumpingJacks} jumping jacks. '
          'You earned it. Don\'t waste it.';
    } else if (workoutDays >= 5) {
      body = 'Same targets this week. You were inconsistent. Be better.';
    } else {
      body = 'You didn\'t show up enough last week. Targets dropped to '
          '${targets.pushups}/${targets.situps}/${targets.jumpingJacks}. '
          'That should embarrass you.';
    }

    await _plugin.show(
      110,
      'HabitForge',
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
    );
  }

  static Future<void> scheduleEndOfDay(
    int done,
    int total, {
    int rolloverCount = 0,
    String? lastReviewChange,
  }) async {
    if (kIsWeb) return;
    await _plugin.cancel(_endOfDayId);
    if (total > 0 && done / total >= 0.7) return; // at or above 70% — no shame

    final now = tz.TZDateTime.now(tz.local);
    final fireTime =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, 22, 30);
    if (now.isAfter(fireTime)) return;

    String message;
    if (done == 0 && total > 0) {
      message =
          "Zero habits. Not one. You basically didn't exist today. Get yourself together.";
      if (rolloverCount > 0) {
        message +=
            ' Every deliverable rolled over. This is not a bad day. This is a pattern.';
      }
      if (lastReviewChange != null && lastReviewChange.isNotEmpty) {
        message +=
            ' Last week you said: "$lastReviewChange". Did you do it?';
      }
    } else {
      message =
          "Below 70% today. You didn't have a bad day — you made bad choices. Tomorrow is not guaranteed, fix it now.";
      if (rolloverCount > 0) {
        message +=
            ' You also have $rolloverCount carried-over deliverable${rolloverCount == 1 ? '' : 's'} this week. Your plan is collapsing.';
      }
    }

    await _plugin.zonedSchedule(
      _endOfDayId,
      'HabitForge',
      message,
      fireTime,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }
}
