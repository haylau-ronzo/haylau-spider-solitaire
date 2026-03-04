import 'package:flutter_test/flutter_test.dart';
import 'package:haylau_spider_solitaire/game/model/deal_source.dart';
import 'package:haylau_spider_solitaire/game/model/difficulty.dart';
import 'package:haylau_spider_solitaire/game/solvable/solvable_seeds.dart';

void main() {
  test('all solvable seed pools have unique values', () {
    expect(
      dailySolvableSeeds1Suit.toSet().length,
      dailySolvableSeeds1Suit.length,
    );
    expect(
      randomSolvableSeeds1Suit.toSet().length,
      randomSolvableSeeds1Suit.length,
    );
    expect(solvableSeeds2Suit.toSet().length, solvableSeeds2Suit.length);
    expect(solvableSeeds4Suit.toSet().length, solvableSeeds4Suit.length);
  });

  test('daily and random 1-suit pools do not overlap', () {
    final overlap = dailySolvableSeeds1Suit.toSet().intersection(
      randomSolvableSeeds1Suit.toSet(),
    );

    expect(overlap, isEmpty);
  });

  test(
    'pickRandomSolvableSeed1Suit is deterministic even when pool is empty',
    () {
      final first = pickRandomSolvableSeed1Suit(0);
      final again = pickRandomSolvableSeed1Suit(0);
      expect(again, first);
    },
  );

  test('DailySolvableDealSource remains deterministic for one-suit', () {
    const source = DailySolvableDealSource('2026-03-01');

    final seedA = source.toSeed(difficulty: Difficulty.oneSuit);
    final seedB = source.toSeed(difficulty: Difficulty.oneSuit);

    expect(seedA, seedB);
  });

  test('RandomSolvableDealSource remains deterministic for one-suit', () {
    const source = RandomSolvableDealSource(123456);

    final seedA = source.toSeed(difficulty: Difficulty.oneSuit);
    final seedB = source.toSeed(difficulty: Difficulty.oneSuit);

    expect(seedA, seedB);
  });

  test('DailySolvableDealSource remains deterministic for two-suit', () {
    const source = DailySolvableDealSource('2026-03-01');

    final seedA = source.toSeed(difficulty: Difficulty.twoSuit);
    final seedB = source.toSeed(difficulty: Difficulty.twoSuit);

    expect(seedA, seedB);
  });

  test('RandomSolvableDealSource remains deterministic for four-suit', () {
    const source = RandomSolvableDealSource(123456);

    final seedA = source.toSeed(difficulty: Difficulty.fourSuit);
    final seedB = source.toSeed(difficulty: Difficulty.fourSuit);

    expect(seedA, seedB);
  });

  test('RandomDealSource remains explicit random seed', () {
    const source = RandomDealSource(987654321);
    expect(source.toSeed(difficulty: Difficulty.oneSuit), 987654321);
  });
}
