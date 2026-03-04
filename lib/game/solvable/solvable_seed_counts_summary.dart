import '../persistence/solvable_seed_usage_model.dart';
import 'solvable_seeds.dart';

class SolvableSeedCountsSummary {
  const SolvableSeedCountsSummary({
    required this.daily1SuitUsed,
    required this.daily1SuitTotal,
    required this.random1SuitUsed,
    required this.random1SuitTotal,
  });

  final int daily1SuitUsed;
  final int daily1SuitTotal;
  final int random1SuitUsed;
  final int random1SuitTotal;
}

SolvableSeedCountsSummary buildSolvableSeedCountsSummary(
  SolvableSeedUsageModel usage,
) {
  // Daily usage is tracked by unique seed values (not date keys) so it remains
  // stable if completion records are replayed; counts are filtered to current pools.
  final dailyPool = dailySolvableSeeds1Suit.toSet();
  final randomPool = randomSolvableSeeds1Suit.toSet();

  final dailyUsed = usage.dailyUsedSeeds1Suit
      .where((seed) => dailyPool.contains(seed))
      .length;
  final randomUsed = usage.randomUsedSeeds1Suit
      .where((seed) => randomPool.contains(seed))
      .length;

  return SolvableSeedCountsSummary(
    daily1SuitUsed: dailyUsed,
    daily1SuitTotal: dailySolvableSeeds1Suit.length,
    random1SuitUsed: randomUsed,
    random1SuitTotal: randomSolvableSeeds1Suit.length,
  );
}
