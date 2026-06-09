/// Returns the ISO 8601 week key for [date], e.g. "2026-W24".
/// Week 1 is the week containing the first Thursday of the year.
String isoWeekKey(DateTime date) {
  final monday = date.subtract(Duration(days: date.weekday - 1));
  final thursday = monday.add(const Duration(days: 3));
  final year = thursday.year;
  final jan4 = DateTime(year, 1, 4);
  final week1Monday = jan4.subtract(Duration(days: jan4.weekday - 1));
  final weekNum = monday.difference(week1Monday).inDays ~/ 7 + 1;
  return '$year-W${weekNum.toString().padLeft(2, '0')}';
}

/// Returns the day-of-week name for [date], e.g. "Monday".
String dayName(DateTime date) {
  const names = [
    'Monday', 'Tuesday', 'Wednesday', 'Thursday',
    'Friday', 'Saturday', 'Sunday'
  ];
  return names[date.weekday - 1];
}

/// Returns all ISO week keys whose Monday falls within [year]/[month].
List<String> weekKeysForMonth(int year, int month) {
  final keys = <String>{};
  final isLeap = (year % 4 == 0 && year % 100 != 0) || year % 400 == 0;
  const daysPerMonth = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
  final daysInMonth =
      month == 2 && isLeap ? 29 : daysPerMonth[month - 1];
  for (int d = 1; d <= daysInMonth; d++) {
    keys.add(isoWeekKey(DateTime(year, month, d)));
  }
  return keys.toList();
}
