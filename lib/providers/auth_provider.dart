import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/firestore_service.dart';
import '../services/notification_service.dart';

final authProvider = FutureProvider<User?>((ref) async {
  final auth = FirebaseAuth.instance;
  if (auth.currentUser == null) {
    await auth.signInAnonymously();
  }
  final user = auth.currentUser!;
  await FirestoreService.seedIfNeeded(user.uid);

  // Request web push permission + save FCM token (fire and forget)
  if (kIsWeb) {
    NotificationService.initWeb(user.uid);
  }

  return user;
});
