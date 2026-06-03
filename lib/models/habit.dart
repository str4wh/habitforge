import 'package:cloud_firestore/cloud_firestore.dart';

class Habit {
  final String id;
  final String name;
  final String category;
  final bool isActive;
  final DateTime createdAt;

  const Habit({
    required this.id,
    required this.name,
    required this.category,
    required this.isActive,
    required this.createdAt,
  });

  factory Habit.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Habit(
      id: doc.id,
      name: data['name'] as String,
      category: data['category'] as String? ?? 'general',
      isActive: data['isActive'] as bool? ?? true,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toFirestore() => {
    'name': name,
    'category': category,
    'isActive': isActive,
    'createdAt': Timestamp.fromDate(createdAt),
  };

  Habit copyWith({bool? isActive}) => Habit(
    id: id,
    name: name,
    category: category,
    isActive: isActive ?? this.isActive,
    createdAt: createdAt,
  );
}
