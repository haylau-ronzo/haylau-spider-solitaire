import 'package:flutter_test/flutter_test.dart';
import 'package:haylau_spider_solitaire/game/model/difficulty.dart';
import 'package:haylau_spider_solitaire/game/scoring/score_calculator.dart';

void main() {
  test('score calibration: 1-suit 240s/160 moves is around 70k', () {
    final score = calculateScore(
      difficulty: Difficulty.oneSuit,
      timeSeconds: 240,
      moves: 160,
      undos: 0,
      hints: 0,
    );

    expect(score, 70000);
  });

  test('score calculation uses base minus penalties', () {
    final score = calculateScore(
      difficulty: Difficulty.fourSuit,
      timeSeconds: 120,
      moves: 50,
      undos: 3,
      hints: 1,
    );

    // 130000 - (1200 + 5500 + 1800 + 3000)
    expect(score, 118500);
  });

  test('score never goes below zero', () {
    final score = calculateScore(
      difficulty: Difficulty.oneSuit,
      timeSeconds: 999999,
      moves: 999999,
      undos: 999999,
      hints: 999999,
    );

    expect(score, 0);
  });
}
