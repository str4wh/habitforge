import 'package:cloud_firestore/cloud_firestore.dart';
import 'workout_data.dart';

class HabitLog {
  final String date; // 'yyyy-MM-dd'
  final List<String> completedHabits;
  final double savingsAmount;
  final DateTime completedAt;
  // Enhanced fields
  final double? coldShowerMinutes;
  final Map<String, int> shukraniReach; // habitId → impressions
  final String? chakulaDeliverable;
  final WorkoutData? workout;

  const HabitLog({
    required this.date,
    required this.completedHabits,
    required this.savingsAmount,
    required this.completedAt,
    this.coldShowerMinutes,
    this.shukraniReach = const {},
    this.chakulaDeliverable,
    this.workout,
  });

  factory HabitLog.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return HabitLog(
      date: doc.id,
      completedHabits: List<String>.from(data['completedHabits'] ?? []),
      savingsAmount: (data['savingsAmount'] as num?)?.toDouble() ?? 0.0,
      completedAt: data['completedAt'] != null
          ? (data['completedAt'] as Timestamp).toDate()
          : DateTime.now(),
      coldShowerMinutes:
          (data['coldShowerMinutes'] as num?)?.toDouble(),
      shukraniReach: data['shukraniReach'] != null
          ? Map<String, int>.from(
              (data['shukraniReach'] as Map).map(
                (k, v) => MapEntry(k.toString(), (v as num).toInt()),
              ),
            )
          : {},
      chakulaDeliverable: data['chakulaDeliverable'] as String?,
      workout: data['workout'] != null
          ? WorkoutData.fromMap(
              data['workout'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toFirestore() {
    final map = <String, dynamic>{
      'completedHabits': completedHabits,
      'savingsAmount': savingsAmount,
      'completedAt': Timestamp.fromDate(completedAt),
    };
    if (coldShowerMinutes != null) {
      map['coldShowerMinutes'] = coldShowerMinutes;
    }
    if (shukraniReach.isNotEmpty) {
      map['shukraniReach'] = shukraniReach;
    }
    if (chakulaDeliverable != null && chakulaDeliverable!.isNotEmpty) {
      map['chakulaDeliverable'] = chakulaDeliverable;
    }
    if (workout != null) {
      map['workout'] = workout!.toMap();
    }
    return map;
  }
}
