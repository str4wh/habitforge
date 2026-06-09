import 'package:cloud_firestore/cloud_firestore.dart';

class WhyData {
  final String q1, q2, q3, q4, q5;
  final String statement;
  final DateTime completedAt;

  const WhyData({
    required this.q1,
    required this.q2,
    required this.q3,
    required this.q4,
    required this.q5,
    required this.statement,
    required this.completedAt,
  });

  factory WhyData.fromMap(Map<String, dynamic> data) => WhyData(
        q1: (data['q1'] ?? '') as String,
        q2: (data['q2'] ?? '') as String,
        q3: (data['q3'] ?? '') as String,
        q4: (data['q4'] ?? '') as String,
        q5: (data['q5'] ?? '') as String,
        statement: (data['statement'] ?? '') as String,
        completedAt: data['completedAt'] != null
            ? (data['completedAt'] as Timestamp).toDate()
            : DateTime.now(),
      );

  Map<String, dynamic> toMap() => {
        'q1': q1,
        'q2': q2,
        'q3': q3,
        'q4': q4,
        'q5': q5,
        'statement': statement,
        'completedAt': Timestamp.fromDate(completedAt),
      };
}
