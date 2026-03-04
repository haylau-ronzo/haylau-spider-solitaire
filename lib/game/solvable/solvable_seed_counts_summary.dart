import '../model/difficulty.dart';
import '../persistence/solvable_seed_usage_model.dart';
import 'solvable_seeds.dart';

class DifficultySeedCounts {
  const DifficultySeedCounts({required this.used, required this.total});

  final int used;
  final int total;
}

class SolvableSeedCountsSummary {
  const SolvableSeedCountsSummary({
    required this.oneSuit,
    required this.twoSuit,
    required this.fourSuit,
  });

  final DifficultySeedCounts oneSuit;
  final DifficultySeedCounts twoSuit;
  final DifficultySeedCounts fourSuit;

  DifficultySeedCounts forDifficulty(Difficulty difficulty) {
    return switch (difficulty) {
      Difficulty.oneSuit => oneSuit,
      Difficulty.twoSuit => twoSuit,
      Difficulty.fourSuit => fourSuit,
    };
  }
}

SolvableSeedCountsSummary buildSolvableSeedCountsSummary(
  SolvableSeedUsageModel usage,
) {
  DifficultySeedCounts countsForDifficulty(Difficulty difficulty) {
    final pool = winnableSeedsForDifficulty(difficulty).toSet();
    if (pool.isEmpty) {
      return const DifficultySeedCounts(used: 0, total: 0);
    }

    final used = switch (difficulty) {
      Difficulty.oneSuit => <int>{
        ...usage.dailyUsedSeeds1Suit,
        ...usage.randomUsedSeeds1Suit,
      },
      Difficulty.twoSuit => <int>{},
      Difficulty.fourSuit => <int>{},
    };

    final usedInPool = used.where(pool.contains).length;
    return DifficultySeedCounts(used: usedInPool, total: pool.length);
  }

  return SolvableSeedCountsSummary(
    oneSuit: countsForDifficulty(Difficulty.oneSuit),
    twoSuit: countsForDifficulty(Difficulty.twoSuit),
    fourSuit: countsForDifficulty(Difficulty.fourSuit),
  );
}
