import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

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
}
