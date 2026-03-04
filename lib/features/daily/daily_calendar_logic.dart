DateTime stripLocalDate(DateTime value) {
  return DateTime(value.year, value.month, value.day);
}

String toDateKeyLocal(DateTime value) {
  final local = value.toLocal();
  return '${local.year.toString().padLeft(4, '0')}-'
      '${local.month.toString().padLeft(2, '0')}-'
      '${local.day.toString().padLeft(2, '0')}';
}

DateTime? parseDateKeyLocal(String dateKey) {
  final parts = dateKey.split('-');
  if (parts.length != 3) {
    return null;
  }

  final year = int.tryParse(parts[0]);
  final month = int.tryParse(parts[1]);
  final day = int.tryParse(parts[2]);
  if (year == null || month == null || day == null) {
    return null;
  }

  return DateTime(year, month, day);
}

bool isFutureDateKey(String dateKey, DateTime todayLocal) {
  final date = parseDateKeyLocal(dateKey);
  if (date == null) {
    return true;
  }
  return stripLocalDate(date).isAfter(stripLocalDate(todayLocal));
}

bool isCompletedOnDay({
  required String dateKeyLocal,
  required DateTime completedAt,
}) {
  final date = parseDateKeyLocal(dateKeyLocal);
  if (date == null) {
    return false;
  }
  return stripLocalDate(completedAt.toLocal()) == stripLocalDate(date);
}
