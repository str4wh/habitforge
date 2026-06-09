import 'package:cloud_firestore/cloud_firestore.dart';

class WeeklyDeliverable {
  final String id;
  final String text;
  final bool completed;
  final String? completedDate; // 'yyyy-MM-dd'
  final int rolloverCount;
  final String originalDay; // 'Monday', 'Tuesday', …
  final DateTime createdAt;

  const WeeklyDeliverable({
    required this.id,
    required this.text,
    required this.completed,
    this.completedDate,
    required this.rolloverCount,
    required this.originalDay,
    required this.createdAt,
  });

  factory WeeklyDeliverable.fromMap(Map<String, dynamic> m) =>
      WeeklyDeliverable(
        id: m['id'] as String,
        text: m['text'] as String,
        completed: (m['completed'] as bool?) ?? false,
        completedDate: m['completedDate'] as String?,
        rolloverCount: (m['rolloverCount'] as num?)?.toInt() ?? 0,
        originalDay: (m['originalDay'] as String?) ?? 'Monday',
        createdAt: m['createdAt'] is Timestamp
            ? (m['createdAt'] as Timestamp).toDate()
            : DateTime.now(),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'text': text,
        'completed': completed,
        if (completedDate != null) 'completedDate': completedDate,
        'rolloverCount': rolloverCount,
        'originalDay': originalDay,
        'createdAt': Timestamp.fromDate(createdAt),
      };

  WeeklyDeliverable copyWith({
    bool? completed,
    String? completedDate,
    int? rolloverCount,
    String? text,
    String? originalDay,
  }) =>
      WeeklyDeliverable(
        id: id,
        text: text ?? this.text,
        completed: completed ?? this.completed,
        completedDate: completedDate ?? this.completedDate,
        rolloverCount: rolloverCount ?? this.rolloverCount,
        originalDay: originalDay ?? this.originalDay,
        createdAt: createdAt,
      );
}
