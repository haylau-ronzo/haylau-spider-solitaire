import 'package:flutter_test/flutter_test.dart';
import 'package:haylau_spider_solitaire/features/home/home_screen.dart';
import 'package:haylau_spider_solitaire/game/model/difficulty.dart';

void main() {
  test('daily deal is unavailable when verified daily pool is empty', () {
    final available = isDailyDealAvailable(
      difficulty: Difficulty.oneSuit,
      dailyPoolOverride: (_) => false,
      ignoreVerifiedOverride: false,
    );
    expect(available, isFalse);
  });

  test('daily deal is unavailable when ignore-verified is enabled', () {
    final available = isDailyDealAvailable(
      difficulty: Difficulty.oneSuit,
      dailyPoolOverride: (_) => true,
      ignoreVerifiedOverride: true,
    );
    expect(available, isFalse);
  });
}
