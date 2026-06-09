import 'package:cloud_firestore/cloud_firestore.dart';

class ChakulaAssessment {
  final String weekKey;
  final int rating;
  final List<String> weeklyDeliverables;
  final String unshippedReason;
  final DateTime completedAt;

  const ChakulaAssessment({
    required this.weekKey,
    required this.rating,
    required this.weeklyDeliverables,
    required this.unshippedReason,
    required this.completedAt,
  });

  factory ChakulaAssessment.fromMap(String weekKey, Map<String, dynamic> m) =>
      ChakulaAssessment(
        weekKey: weekKey,
        rating: (m['rating'] as num?)?.toInt() ?? 0,
        weeklyDeliverables: List<String>.from(m['weeklyDeliverables'] ?? []),
        unshippedReason: m['unshippedReason'] as String? ?? '',
        completedAt: m['completedAt'] is Timestamp
            ? (m['completedAt'] as Timestamp).toDate()
            : DateTime.now(),
      );

  Map<String, dynamic> toMap() => {
        'rating': rating,
        'weeklyDeliverables': weeklyDeliverables,
        'unshippedReason': unshippedReason,
        'completedAt': Timestamp.fromDate(completedAt),
      };
}
