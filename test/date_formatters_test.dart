import 'package:flutter_test/flutter_test.dart';
import 'package:haylau_spider_solitaire/utils/date_formatters.dart';

void main() {
  test('UK date formatters produce expected strings', () {
    final dt = DateTime(2026, 3, 1, 9, 5);

    expect(formatUkDate(dt), '01/03/2026');
    expect(formatUkDateTime(dt), '01/03/2026 09:05');
    expect(formatUkMonthYear(dt), 'March 2026');
  });
}
