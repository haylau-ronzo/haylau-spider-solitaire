import 'package:flutter_test/flutter_test.dart';
import 'package:haylau_spider_solitaire/game/model/difficulty.dart';
import 'package:haylau_spider_solitaire/game/solvable/solvable_seeds.dart';
import 'package:haylau_spider_solitaire/game/solvable/solvable_seeds_verified.dart'
    as verified;
import 'package:haylau_spider_solitaire/game/solvable/solvable_solutions_1suit_verified.dart';
import 'package:haylau_spider_solitaire/game/solvable/verified_solvable_data_override.dart';

void main() {
  test('verified pools have no duplicates and no daily/random overlap', () {
    void expectValid(List<int> daily, List<int> random) {
      expect(daily.toSet().length, daily.length);
      expect(random.toSet().length, random.length);
      expect(daily.toSet().intersection(random.toSet()), isEmpty);
    }

    expectValid(
      verified.dailySolvableSeeds1Suit,
      verified.randomSolvableSeeds1Suit,
    );
    expectValid(
      verified.dailySolvableSeeds2Suit,
      verified.randomSolvableSeeds2Suit,
    );
    expectValid(
      verified.dailySolvableSeeds4Suit,
      verified.randomSolvableSeeds4Suit,
    );
  });

  test('ignore-verified override makes availability behave as empty', () {
    setIgnoreVerifiedSolvableData(true);
    addTearDown(() => setIgnoreVerifiedSolvableData(false));

    expect(hasDailySolvableSeeds(Difficulty.oneSuit), isFalse);
    expect(hasRandomSolvableSeeds(Difficulty.oneSuit), isFalse);
    expect(verifiedSolutionPrefixForSeed1Suit(9), isNull);
    expect(verifiedFullSolutionForSeed1Suit(9), isNull);
  });

  test('daily mapping stays stable for past days when new pool is added', () {
    final basePools = <verified.DailySolvableSeedPool>[
      const verified.DailySolvableSeedPool(
        startDateKey: '2026-01-01',
        seeds: <int>[10, 11, 12, 13],
      ),
    ];

    final expandedPools = <verified.DailySolvableSeedPool>[
      ...basePools,
      const verified.DailySolvableSeedPool(
        startDateKey: '2026-03-01',
        seeds: <int>[20, 21, 22, 23],
      ),
    ];

    final beforeDate = '2026-02-20';
    final beforeBase = pickDailySolvableSeedFromPools(
      dateKey: beforeDate,
      pools: basePools,
    );
    final beforeExpanded = pickDailySolvableSeedFromPools(
      dateKey: beforeDate,
      pools: expandedPools,
    );

    expect(beforeExpanded, beforeBase);

    final afterDate = '2026-03-05';
    final afterExpanded = pickDailySolvableSeedFromPools(
      dateKey: afterDate,
      pools: expandedPools,
    );
    expect(<int>[20, 21, 22, 23], contains(afterExpanded));
  });

  test('guaranteed-winnable availability helper reports empty pools', () {
    final available = hasRandomSolvableSeeds(
      Difficulty.oneSuit,
      randomPoolsOverride: <Difficulty, List<int>>{
        Difficulty.oneSuit: const <int>[],
      },
    );

    expect(available, isFalse);
  });

  test('every 1-suit guaranteed seed has a solution prefix', () {
    final prefixKeys = solutionFirst30_1Suit.keys.toSet();

    final missingDaily = verified.dailySolvableSeeds1Suit
        .where((seed) => !prefixKeys.contains(seed))
        .toList();
    final missingRandom = verified.randomSolvableSeeds1Suit
        .where((seed) => !prefixKeys.contains(seed))
        .toList();

    expect(
      missingDaily,
      isEmpty,
      reason: 'daily 1-suit seeds missing prefix solutions: $missingDaily',
    );
    expect(
      missingRandom,
      isEmpty,
      reason: 'random 1-suit seeds missing prefix solutions: $missingRandom',
    );
  });
}
