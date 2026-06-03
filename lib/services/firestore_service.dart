import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/habit.dart';
import '../models/habit_log.dart';

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
}
