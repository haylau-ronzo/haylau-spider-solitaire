import '../model/difficulty.dart';
import 'verified_solvable_data_override.dart';

class DailySolvableSeedPool {
  const DailySolvableSeedPool({
    required this.startDateKey,
    required this.seeds,
  });

  final String startDateKey;
  final List<int> seeds;
}

// BEGIN GENERATED VERIFIED DATA
const List<int> dailySolvableSeeds1Suit = <int>[2, 29];

const List<int> randomSolvableSeeds1Suit = <int>[33, 38];

const List<int> dailySolvableSeeds2Suit = <int>[];

const List<int> randomSolvableSeeds2Suit = <int>[];

const List<int> dailySolvableSeeds4Suit = <int>[];

const List<int> randomSolvableSeeds4Suit = <int>[];
// END GENERATED VERIFIED DATA

// TODO(release): Once daily mapping is frozen, do not alter existing pool contents.
// Add a new pool with a future startDateKey instead.
const List<DailySolvableSeedPool> dailyPools1Suit = <DailySolvableSeedPool>[];

const List<DailySolvableSeedPool> dailyPools2Suit = <DailySolvableSeedPool>[];

const List<DailySolvableSeedPool> dailyPools4Suit = <DailySolvableSeedPool>[];

List<int> verifiedDailySeedsForDifficulty(Difficulty difficulty) {
  if (ignoreVerifiedSolvableData) {
    return const <int>[];
  }
  return switch (difficulty) {
    Difficulty.oneSuit => dailySolvableSeeds1Suit,
    Difficulty.twoSuit => dailySolvableSeeds2Suit,
    Difficulty.fourSuit => dailySolvableSeeds4Suit,
  };
}

List<int> verifiedRandomSeedsForDifficulty(Difficulty difficulty) {
  if (ignoreVerifiedSolvableData) {
    return const <int>[];
  }
  return switch (difficulty) {
    Difficulty.oneSuit => randomSolvableSeeds1Suit,
    Difficulty.twoSuit => randomSolvableSeeds2Suit,
    Difficulty.fourSuit => randomSolvableSeeds4Suit,
  };
}

List<int> verifiedWinnablePoolForDifficulty(Difficulty difficulty) {
  if (ignoreVerifiedSolvableData) {
    return const <int>[];
  }

  final merged = <int>{
    ...verifiedDailySeedsForDifficulty(difficulty),
    ...verifiedRandomSeedsForDifficulty(difficulty),
  };
  return List<int>.unmodifiable(merged);
}

List<DailySolvableSeedPool> verifiedDailyPoolsForDifficulty(
  Difficulty difficulty,
) {
  if (ignoreVerifiedSolvableData) {
    return const <DailySolvableSeedPool>[];
  }
  return switch (difficulty) {
    Difficulty.oneSuit => dailyPools1Suit,
    Difficulty.twoSuit => dailyPools2Suit,
    Difficulty.fourSuit => dailyPools4Suit,
  };
}
