import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/habit.dart';
import '../services/firestore_service.dart';
import 'auth_provider.dart';

final habitsProvider = StreamProvider<List<Habit>>((ref) {
  final auth = ref.watch(authProvider);
  return auth.when(
    data: (user) {
      if (user == null) return const Stream.empty();
      return FirestoreService.habitsStream(user.uid);
    },
    loading: () => const Stream.empty(),
    error: (e, _) => const Stream.empty(),
  );
});

final activeHabitsProvider = Provider<List<Habit>>((ref) {
  return ref.watch(habitsProvider).maybeWhen(
        data: (habits) => habits.where((h) => h.isActive).toList(),
        orElse: () => [],
      );
});
