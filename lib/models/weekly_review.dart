import 'package:cloud_firestore/cloud_firestore.dart';

class WeeklyReview {
  final String weekKey;
  final String biggestExcuse;
  final String habitAtRisk;
  final String whyNotQuitting;
  final String whatChanges;
  final DateTime completedAt;

  const WeeklyReview({
    required this.weekKey,
    required this.biggestExcuse,
    required this.habitAtRisk,
    required this.whyNotQuitting,
    required this.whatChanges,
    required this.completedAt,
  });

  factory WeeklyReview.fromMap(String weekKey, Map<String, dynamic> m) =>
      WeeklyReview(
        weekKey: weekKey,
        biggestExcuse: m['biggestExcuse'] as String? ?? '',
        habitAtRisk: m['habitAtRisk'] as String? ?? '',
        whyNotQuitting: m['whyNotQuitting'] as String? ?? '',
        whatChanges: m['whatChanges'] as String? ?? '',
        completedAt: m['completedAt'] is Timestamp
            ? (m['completedAt'] as Timestamp).toDate()
            : DateTime.now(),
      );

  Map<String, dynamic> toMap() => {
        'biggestExcuse': biggestExcuse,
        'habitAtRisk': habitAtRisk,
        'whyNotQuitting': whyNotQuitting,
        'whatChanges': whatChanges,
        'completedAt': Timestamp.fromDate(completedAt),
      };
}
