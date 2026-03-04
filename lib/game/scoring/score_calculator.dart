import '../model/difficulty.dart';

class ScoreTuning {
  // Calibration baseline:
  // 1-suit, 240s, 160 moves, 0 undos/hints => ~70,000.
  static const int baseOneSuit = 90000;
  static const int baseTwoSuit = 110000;
  static const int baseFourSuit = 130000;

  static const int timePenaltyPerSecond = 10;
  static const int movePenalty = 110;
  static const int undoPenalty = 600;
  static const int hintPenalty = 3000;
}

int baseScoreForDifficulty(Difficulty difficulty) {
  switch (difficulty) {
    case Difficulty.oneSuit:
      return ScoreTuning.baseOneSuit;
    case Difficulty.twoSuit:
      return ScoreTuning.baseTwoSuit;
    case Difficulty.fourSuit:
      return ScoreTuning.baseFourSuit;
  }
}

int calculateScore({
  required Difficulty difficulty,
  required int timeSeconds,
  required int moves,
  required int undos,
  required int hints,
}) {
  final base = baseScoreForDifficulty(difficulty);
  final penalties =
      (timeSeconds * ScoreTuning.timePenaltyPerSecond) +
      (moves * ScoreTuning.movePenalty) +
      (undos * ScoreTuning.undoPenalty) +
      (hints * ScoreTuning.hintPenalty);
  final score = base - penalties;
  return score < 0 ? 0 : score;
}
