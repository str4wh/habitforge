import 'package:intl/intl.dart';

class SavingsVelocity {
  final double monthSaved;
  final double dailyAverage;
  final double projected;
  final double target;
  final double shortfall; // target - projected; positive = behind, negative = surplus
  final double dailyRequired; // (target - monthSaved) / daysRemaining; infinity if last day
  final bool isOnTrack; // projected >= target
  final int dayOfMonth;
  final int daysInMonth;
  final int daysRemaining;

  const SavingsVelocity({
    required this.monthSaved,
    required this.dailyAverage,
    required this.projected,
    required this.target,
    required this.shortfall,
    required this.dailyRequired,
    required this.isOnTrack,
    required this.dayOfMonth,
    required this.daysInMonth,
    required this.daysRemaining,
  });
}

SavingsVelocity computeVelocity({
  required double monthSaved,
  required double target,
  required DateTime now,
}) {
  final dayOfMonth = now.day;
  final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
  final daysRemaining = daysInMonth - dayOfMonth;
  final dailyAverage = monthSaved / dayOfMonth; // dayOfMonth is always >= 1
  final projected = dailyAverage * daysInMonth;
  final shortfall = target - projected;
  final dailyRequired = daysRemaining > 0
      ? (target - monthSaved) / daysRemaining
      : double.infinity;
  return SavingsVelocity(
    monthSaved: monthSaved,
    dailyAverage: dailyAverage,
    projected: projected,
    target: target,
    shortfall: shortfall,
    dailyRequired: dailyRequired.clamp(0, double.infinity),
    isOnTrack: projected >= target,
    dayOfMonth: dayOfMonth,
    daysInMonth: daysInMonth,
    daysRemaining: daysRemaining,
  );
}

/// Returns the notification body for a below-target velocity.
/// Caller must confirm isOnTrack == false before calling.
String buildVelocityNotificationBody(SavingsVelocity v) {
  final fmt = NumberFormat('#,###');
  if (v.dayOfMonth < 15) {
    return "You're behind on savings. At this rate you finish the month at "
        "KES ${fmt.format(v.projected.round())}, not "
        "KES ${fmt.format(v.target.round())}. You need "
        "KES ${fmt.format(v.dailyRequired.round())}/day for the rest of the month.";
  } else {
    return "Past the halfway point and still behind on savings. "
        "KES ${fmt.format(v.shortfall.round())} short of your target. "
        "That's KES ${fmt.format(v.dailyRequired.round())}/day for the remaining "
        "${v.daysRemaining} days. Stop spending.";
  }
}
