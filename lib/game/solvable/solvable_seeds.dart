import '../model/difficulty.dart';
import 'solvable_seeds_verified.dart';
import 'verified_solvable_data_override.dart';

List<int> get dailySolvableSeeds1Suit =>
    verifiedDailySeedsForDifficulty(Difficulty.oneSuit);
List<int> get randomSolvableSeeds1Suit =>
    verifiedRandomSeedsForDifficulty(Difficulty.oneSuit);
List<int> get solvableSeeds2Suit =>
    verifiedRandomSeedsForDifficulty(Difficulty.twoSuit);
List<int> get solvableSeeds4Suit =>
    verifiedRandomSeedsForDifficulty(Difficulty.fourSuit);

List<int> randomSolvableSeedsForDifficulty(Difficulty difficulty) =>
    verifiedRandomSeedsForDifficulty(difficulty);

List<int> dailySolvableSeedsForDifficulty(Difficulty difficulty) =>
    verifiedDailySeedsForDifficulty(difficulty);

bool hasRandomSolvableSeeds(
  Difficulty difficulty, {
  Map<Difficulty, List<int>>? randomPoolsOverride,
}) {
  if (ignoreVerifiedSolvableData) {
    return false;
  }

  final pools =
      randomPoolsOverride ??
      <Difficulty, List<int>>{
        Difficulty.oneSuit: verifiedRandomSeedsForDifficulty(
          Difficulty.oneSuit,
        ),
        Difficulty.twoSuit: verifiedRandomSeedsForDifficulty(
          Difficulty.twoSuit,
        ),
        Difficulty.fourSuit: verifiedRandomSeedsForDifficulty(
          Difficulty.fourSuit,
        ),
      };
  return (pools[difficulty] ?? const <int>[]).isNotEmpty;
}

bool hasDailySolvableSeeds(Difficulty difficulty) {
  if (ignoreVerifiedSolvableData) {
    return false;
  }

  return verifiedDailySeedsForDifficulty(difficulty).isNotEmpty;
}

int pickDailySolvableSeed1Suit(String dateKey) {
  return pickDailySolvableSeed(
    difficulty: Difficulty.oneSuit,
    dateKey: dateKey,
  );
}

int pickRandomSolvableSeed1Suit(int index) {
  return pickRandomSolvableSeed(difficulty: Difficulty.oneSuit, index: index);
}

int pickDailySolvableSeed({
  required Difficulty difficulty,
  required String dateKey,
}) {
  final pools = verifiedDailyPoolsForDifficulty(
    difficulty,
  ).where((pool) => pool.seeds.isNotEmpty).toList(growable: false);

  if (pools.isNotEmpty) {
    return pickDailySolvableSeedFromPools(dateKey: dateKey, pools: pools);
  }

  final dailySeeds = verifiedDailySeedsForDifficulty(difficulty);
  if (dailySeeds.isNotEmpty) {
    final index = _hashDateKey(dateKey) % dailySeeds.length;
    return dailySeeds[index];
  }

  final fallbackIndex = _hashDateKey(dateKey);
  return pickRandomSolvableSeed(difficulty: difficulty, index: fallbackIndex);
}

int pickDailySolvableSeedFromPools({
  required String dateKey,
  required List<DailySolvableSeedPool> pools,
}) {
  final selectedPool = _pickPoolForDate(dateKey: dateKey, pools: pools);
  if (selectedPool == null || selectedPool.seeds.isEmpty) {
    final fallbackIndex = _hashDateKey(dateKey);
    return fallbackIndex;
  }

  final start = _parseDateKey(selectedPool.startDateKey);
  final date = _parseDateKey(dateKey);
  final dayIndex = date.difference(start).inDays;
  final index = dayIndex < 0 ? 0 : dayIndex;
  return selectedPool.seeds[index % selectedPool.seeds.length];
}

int pickRandomSolvableSeed({
  required Difficulty difficulty,
  required int index,
}) {
  final seeds = verifiedRandomSeedsForDifficulty(difficulty);
  if (seeds.isEmpty) {
    // Safe fallback: non-guaranteed deterministic seed.
    return index & 0x7fffffff;
  }
  return seeds[index % seeds.length];
}

int pickSolvableSeed({required Difficulty difficulty, required int index}) {
  return pickRandomSolvableSeed(difficulty: difficulty, index: index);
}

DailySolvableSeedPool? _pickPoolForDate({
  required String dateKey,
  required List<DailySolvableSeedPool> pools,
}) {
  if (pools.isEmpty) {
    return null;
  }
  final date = _parseDateKey(dateKey);

  DailySolvableSeedPool? best;
  DateTime? bestStart;
  for (final pool in pools) {
    final start = _parseDateKey(pool.startDateKey);
    if (start.isAfter(date)) {
      continue;
    }
    if (bestStart == null || start.isAfter(bestStart)) {
      best = pool;
      bestStart = start;
    }
  }

  return best ?? pools.first;
}

DateTime _parseDateKey(String dateKeyLocal) {
  final parts = dateKeyLocal.split('-');
  if (parts.length != 3) {
    return DateTime(1970, 1, 1);
  }
  final year = int.tryParse(parts[0]) ?? 1970;
  final month = int.tryParse(parts[1]) ?? 1;
  final day = int.tryParse(parts[2]) ?? 1;
  return DateTime(year, month, day);
}

int _hashDateKey(String dateKeyLocal) {
  var hash = 0;
  for (final unit in dateKeyLocal.codeUnits) {
    hash = ((hash * 31) + unit) & 0x7fffffff;
  }
  return hash;
}
