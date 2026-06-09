import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/chakula_assessment.dart';
import '../models/habit.dart';
import '../models/habit_log.dart';
import '../models/weekly_deliverable.dart';
import '../models/weekly_review.dart';
import '../models/why_data.dart';
import '../models/workout_data.dart';

class FirestoreService {
  static final _db = FirebaseFirestore.instance;

  static CollectionReference<Map<String, dynamic>> _habitsCol(String uid) =>
      _db.collection('users').doc(uid).collection('habits');

  static CollectionReference<Map<String, dynamic>> _logsCol(String uid) =>
      _db.collection('users').doc(uid).collection('logs');

  static DocumentReference<Map<String, dynamic>> _metaDoc(
          String uid, String key) =>
      _db.collection('users').doc(uid).collection('meta').doc(key);

  // ── Habits ────────────────────────────────────────────────────────────────

  static Stream<List<Habit>> habitsStream(String uid) {
    return _habitsCol(uid)
        .orderBy('createdAt')
        .snapshots()
        .map((s) => s.docs.map(Habit.fromFirestore).toList());
  }

  static Future<void> seedIfNeeded(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('seeded_$uid') == true) return;

    final snap = await _habitsCol(uid).limit(1).get();
    if (snap.docs.isNotEmpty) {
      await prefs.setBool('seeded_$uid', true);
      return;
    }

    final seeds = [
      ('Pray 2x', 'spiritual'),
      ('Cold Shower', 'health'),
      ('Work on Chakula', 'work'),
      ('Post on Uncles', 'social'),
      ('Post Shukrani', 'social'),
      ('Reddit Shukrani', 'social'),
      ('Tweet Shukrani', 'social'),
      ('Save Any Amount', 'finance'),
      ('Workout (50 pushups / 50 situps / 60 jumping jacks)', 'health'),
    ];

    final batch = _db.batch();
    for (final (name, category) in seeds) {
      final ref = _habitsCol(uid).doc();
      batch.set(ref, {
        'name': name,
        'category': category,
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
    await prefs.setBool('seeded_$uid', true);
  }

  static Future<List<Habit>> fetchActiveHabits(String uid) async {
    final snap = await _habitsCol(uid)
        .where('isActive', isEqualTo: true)
        .orderBy('createdAt')
        .get();
    return snap.docs.map(Habit.fromFirestore).toList();
  }

  static Future<void> toggleHabitActive(String uid, Habit habit) async {
    await _habitsCol(uid)
        .doc(habit.id)
        .update({'isActive': !habit.isActive});
  }

  // ── Logs ──────────────────────────────────────────────────────────────────

  static Stream<HabitLog?> logStream(String uid, String date) {
    return _logsCol(uid).doc(date).snapshots().map((snap) {
      if (!snap.exists) return null;
      return HabitLog.fromFirestore(snap);
    });
  }

  static Future<void> upsertLog(String uid, HabitLog log) async {
    await _logsCol(uid)
        .doc(log.date)
        .set(log.toFirestore(), SetOptions(merge: true));
  }

  static Future<HabitLog?> fetchLog(String uid, String date) async {
    final snap = await _logsCol(uid).doc(date).get();
    if (!snap.exists) return null;
    return HabitLog.fromFirestore(snap);
  }

  static Future<void> writePunishmentAcknowledged(
    String uid,
    String todayDate, {
    Map<String, dynamic>? prefillFields,
  }) async {
    final data = <String, dynamic>{'punishmentAcknowledged': true};
    if (prefillFields != null) data.addAll(prefillFields);
    await _logsCol(uid).doc(todayDate).set(data, SetOptions(merge: true));
  }

  static Future<Map<String, HabitLog>> monthLogs(
      String uid, int year, int month) async {
    final start = '$year-${month.toString().padLeft(2, '0')}-01';
    final endMonth = month == 12 ? 1 : month + 1;
    final endYear = month == 12 ? year + 1 : year;
    final end =
        '$endYear-${endMonth.toString().padLeft(2, '0')}-01';

    final snap = await _logsCol(uid)
        .where(FieldPath.documentId, isGreaterThanOrEqualTo: start)
        .where(FieldPath.documentId, isLessThan: end)
        .get();

    return {
      for (final doc in snap.docs) doc.id: HabitLog.fromFirestore(doc)
    };
  }

  static Future<Map<String, HabitLog>> allLogs(String uid) async {
    final snap =
        await _logsCol(uid).orderBy(FieldPath.documentId).get();
    return {
      for (final doc in snap.docs) doc.id: HabitLog.fromFirestore(doc)
    };
  }

  // ── Savings target ────────────────────────────────────────────────────────

  static Future<double?> getSavingsTarget(String uid) async {
    final doc = await _metaDoc(uid, 'savingsTarget').get();
    if (!doc.exists) return null;
    return (doc.data()?['target'] as num?)?.toDouble();
  }

  static Future<void> setSavingsTarget(String uid, double target) async {
    await _metaDoc(uid, 'savingsTarget')
        .set({'target': target}, SetOptions(merge: true));
  }

  // ── Weekly plans ─────────────────────────────────────────────────────────

  static DocumentReference<Map<String, dynamic>> _planDoc(
          String uid, String weekKey) =>
      _db.collection('users').doc(uid).collection('weeklyPlans').doc(weekKey);

  /// Returns {habitId → deliverables} for [weekKey], or {} if no plan exists.
  static Future<Map<String, List<WeeklyDeliverable>>> getWeeklyPlan(
      String uid, String weekKey) async {
    final doc = await _planDoc(uid, weekKey).get();
    if (!doc.exists || doc.data() == null) return {};
    final raw = doc.data()!['habits'] as Map<String, dynamic>? ?? {};
    return {
      for (final e in raw.entries)
        e.key: ((e.value['deliverables'] as List<dynamic>?) ?? [])
            .map((d) => WeeklyDeliverable.fromMap(d as Map<String, dynamic>))
            .toList(),
    };
  }

  static Future<bool> isWeeklyPlanSubmitted(
      String uid, String weekKey) async {
    final doc = await _planDoc(uid, weekKey).get();
    return doc.exists && doc.data()?['submittedAt'] != null;
  }

  static Future<void> saveWeeklyPlan(
      String uid,
      String weekKey,
      Map<String, List<WeeklyDeliverable>> plan) async {
    await _planDoc(uid, weekKey).set({
      'submittedAt': FieldValue.serverTimestamp(),
      'habits': {
        for (final e in plan.entries)
          e.key: {'deliverables': e.value.map((d) => d.toMap()).toList()},
      },
    });
  }

  static Future<void> _updateHabitDeliverables(String uid, String weekKey,
      String habitId, List<WeeklyDeliverable> deliverables) async {
    final doc = await _planDoc(uid, weekKey).get();
    if (!doc.exists) return;
    final habits = Map<String, dynamic>.from(
        doc.data()!['habits'] as Map<String, dynamic>? ?? {});
    habits[habitId] = {
      'deliverables': deliverables.map((d) => d.toMap()).toList()
    };
    await _planDoc(uid, weekKey).update({'habits': habits});
  }

  static Future<void> updateDeliverable(String uid, String weekKey,
      String habitId, WeeklyDeliverable updated) async {
    final plan = await getWeeklyPlan(uid, weekKey);
    final list = List<WeeklyDeliverable>.from(plan[habitId] ?? []);
    final idx = list.indexWhere((d) => d.id == updated.id);
    if (idx >= 0) list[idx] = updated;
    await _updateHabitDeliverables(uid, weekKey, habitId, list);
  }

  static Future<void> replaceDeliverable(String uid, String weekKey,
      String habitId, String oldId, List<WeeklyDeliverable> newItems) async {
    final plan = await getWeeklyPlan(uid, weekKey);
    final list = List<WeeklyDeliverable>.from(plan[habitId] ?? []);
    final idx = list.indexWhere((d) => d.id == oldId);
    if (idx >= 0) {
      list.removeAt(idx);
      list.insertAll(idx, newItems);
    }
    await _updateHabitDeliverables(uid, weekKey, habitId, list);
  }

  /// Increments rolloverCount for every uncompleted deliverable.
  /// Returns deliverables that just hit counts of 3 or 5 (for notifications).
  static Future<List<WeeklyDeliverable>> incrementRollovers(
      String uid, String weekKey) async {
    final plan = await getWeeklyPlan(uid, weekKey);
    if (plan.isEmpty) return [];

    final triggered = <WeeklyDeliverable>[];
    final updatedHabits = <String, List<WeeklyDeliverable>>{};

    for (final entry in plan.entries) {
      final updated = <WeeklyDeliverable>[];
      for (final d in entry.value) {
        if (d.completed) {
          updated.add(d);
        } else {
          final next = d.copyWith(rolloverCount: d.rolloverCount + 1);
          updated.add(next);
          if (next.rolloverCount == 3 || next.rolloverCount == 5) {
            triggered.add(next);
          }
        }
      }
      updatedHabits[entry.key] = updated;
    }

    // Write updated plan back
    final doc = await _planDoc(uid, weekKey).get();
    if (!doc.exists) return triggered;
    final habits = <String, dynamic>{};
    for (final e in updatedHabits.entries) {
      habits[e.key] = {
        'deliverables': e.value.map((d) => d.toMap()).toList()
      };
    }
    await _planDoc(uid, weekKey).update({'habits': habits});
    return triggered;
  }

  /// Aggregate rollover counts per habitId across all weeks in [year]/[month].
  static Future<Map<String, int>> monthRolloverSummary(
      String uid, int year, int month) async {
    // Collect all week keys that have days in this month
    final weekKeys = <String>{};
    final isLeap = (year % 4 == 0 && year % 100 != 0) || year % 400 == 0;
    const dpm = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
    final daysInMonth = month == 2 && isLeap ? 29 : dpm[month - 1];
    for (int d = 1; d <= daysInMonth; d++) {
      final dt = DateTime(year, month, d);
      final monday = dt.subtract(Duration(days: dt.weekday - 1));
      final thursday = monday.add(const Duration(days: 3));
      final wYear = thursday.year;
      final jan4 = DateTime(wYear, 1, 4);
      final week1Monday =
          jan4.subtract(Duration(days: jan4.weekday - 1));
      final weekNum = monday.difference(week1Monday).inDays ~/ 7 + 1;
      weekKeys.add('$wYear-W${weekNum.toString().padLeft(2, '0')}');
    }

    final totals = <String, int>{};
    for (final key in weekKeys) {
      final plan = await getWeeklyPlan(uid, key);
      for (final entry in plan.entries) {
        final total = entry.value.fold(0, (s, d) => s + d.rolloverCount);
        totals[entry.key] = (totals[entry.key] ?? 0) + total;
      }
    }
    return totals;
  }

  // ── Workout targets ───────────────────────────────────────────────────────

  static const _defaultTargets =
      WorkoutData(pushups: 50, situps: 50, jumpingJacks: 60);

  static Future<WorkoutData> getWorkoutTargets(String uid) async {
    final doc = await _metaDoc(uid, 'workoutTargets').get();
    if (!doc.exists || doc.data() == null) return _defaultTargets;
    return WorkoutData.fromMap(doc.data()!);
  }

  static Future<void> setWorkoutTargets(
      String uid, WorkoutData targets) async {
    await _metaDoc(uid, 'workoutTargets')
        .set(targets.toMap(), SetOptions(merge: true));
  }

  // ── Weekly reviews ────────────────────────────────────────────────────────

  static CollectionReference<Map<String, dynamic>> _reviewsCol(String uid) =>
      _db.collection('users').doc(uid).collection('weeklyReviews');

  static Future<bool> isWeeklyReviewSubmitted(
      String uid, String weekKey) async {
    final doc = await _reviewsCol(uid).doc(weekKey).get();
    return doc.exists;
  }

  static Future<void> saveWeeklyReview(
      String uid, String weekKey, WeeklyReview review) async {
    await _reviewsCol(uid).doc(weekKey).set(review.toMap());
  }

  /// Returns all past reviews, newest first.
  static Future<List<WeeklyReview>> getAllWeeklyReviews(String uid) async {
    final snap = await _reviewsCol(uid)
        .orderBy('completedAt', descending: true)
        .get();
    return snap.docs
        .map((d) => WeeklyReview.fromMap(d.id, d.data()))
        .toList();
  }

  // ── Chakula assessments ───────────────────────────────────────────────────

  static CollectionReference<Map<String, dynamic>> _assessmentsCol(String uid) =>
      _db.collection('users').doc(uid).collection('chakulaAssessments');

  static Future<bool> isChakulaAssessmentSubmitted(
      String uid, String weekKey) async {
    final doc = await _assessmentsCol(uid).doc(weekKey).get();
    return doc.exists;
  }

  static Future<void> saveChakulaAssessment(
      String uid, String weekKey, ChakulaAssessment a) async {
    await _assessmentsCol(uid).doc(weekKey).set(a.toMap());
  }

  static Future<List<ChakulaAssessment>> getAllChakulaAssessments(
      String uid) async {
    final snap = await _assessmentsCol(uid)
        .orderBy('completedAt', descending: false)
        .get();
    return snap.docs
        .map((d) => ChakulaAssessment.fromMap(d.id, d.data()))
        .toList();
  }

  /// Returns all chakulaDeliverable strings logged in the ISO week containing [date].
  static Future<List<String>> getChakulaDeliverablesForWeek(
      String uid, DateTime date) async {
    final monday = date.subtract(Duration(days: date.weekday - 1));
    final results = <String>[];
    for (int i = 0; i < 7; i++) {
      final day = monday.add(Duration(days: i));
      final dateStr =
          '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
      final log = await fetchLog(uid, dateStr);
      if (log?.chakulaDeliverable?.isNotEmpty == true) {
        results.add(log!.chakulaDeliverable!);
      }
    }
    return results;
  }

  // ── Why data ──────────────────────────────────────────────────────────────

  static Future<WhyData?> getWhyData(String uid, String habitId) async {
    final doc = await _habitsCol(uid).doc(habitId).get();
    if (!doc.exists) return null;
    final raw = doc.data()?['why'] as Map<String, dynamic>?;
    if (raw == null) return null;
    return WhyData.fromMap(raw);
  }

  static Future<void> saveWhyData(
      String uid, String habitId, WhyData data) async {
    await _habitsCol(uid)
        .doc(habitId)
        .set({'why': data.toMap()}, SetOptions(merge: true));
  }

  static Future<void> clearWhyData(String uid, String habitId) async {
    await _habitsCol(uid)
        .doc(habitId)
        .update({'why': FieldValue.delete()});
  }
}
