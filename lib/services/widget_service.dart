import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firestore_service.dart';

class WidgetService {
  static const _androidProvider = 'HabitForgeWidgetProvider';

  /// Push current WHY + progress data to the Android home screen widget.
  /// Rotates to the next habit's WHY statement each call.
  /// Safe to call from any isolate after Firebase has been initialised.
  static Future<void> updateWidget(String uid) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      final habits = await FirestoreService.fetchActiveHabits(uid);
      final total = habits.length;

      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final log = await FirestoreService.fetchLog(uid, today);
      final done = log?.completedHabits.length ?? 0;

      // Collect habits that have a WHY statement
      final statements = <String>[];
      for (final habit in habits) {
        final why = await FirestoreService.getWhyData(uid, habit.id);
        if (why != null && why.statement.isNotEmpty) {
          statements.add(why.statement);
        }
      }

      // Rotate cursor through available statements
      String displayStatement;
      if (statements.isEmpty) {
        displayStatement = '';
      } else {
        final prefs = await SharedPreferences.getInstance();
        final cursor = prefs.getInt('widget_cursor') ?? 0;
        displayStatement = statements[cursor % statements.length];
        await prefs.setInt('widget_cursor', (cursor + 1) % statements.length);
      }

      final progressText = '$done / $total HABITS DONE TODAY';

      await HomeWidget.saveWidgetData<String>(
          'widget_why_statement', displayStatement.toUpperCase());
      await HomeWidget.saveWidgetData<String>('widget_progress', progressText);
      await HomeWidget.updateWidget(androidName: _androidProvider);
    } catch (e) {
      debugPrint('[WidgetService] update failed: $e');
    }
  }
}
