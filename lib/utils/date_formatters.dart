String _twoDigits(int value) => value.toString().padLeft(2, '0');

String formatUkDate(DateTime dt) {
  final local = dt.toLocal();
  return '${_twoDigits(local.day)}/${_twoDigits(local.month)}/${local.year.toString().padLeft(4, '0')}';
}

String formatUkDateTime(DateTime dt) {
  final local = dt.toLocal();
  return '${formatUkDate(local)} ${_twoDigits(local.hour)}:${_twoDigits(local.minute)}';
}

String formatUkMonthYear(DateTime dt) {
  const months = <String>[
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  final local = dt.toLocal();
  return '${months[local.month - 1]} ${local.year}';
}
