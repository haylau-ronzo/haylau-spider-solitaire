import 'package:flutter_test/flutter_test.dart';
import 'package:haylau_spider_solitaire/game/engine/move_validator.dart';
import 'package:haylau_spider_solitaire/game/model/card.dart';
import 'package:haylau_spider_solitaire/game/model/deal_source.dart';
import 'package:haylau_spider_solitaire/game/model/difficulty.dart';
import 'package:haylau_spider_solitaire/game/model/game_state.dart';
import 'package:haylau_spider_solitaire/game/model/piles.dart';

void main() {
  group('MoveValidator', () {
    test(
      '4-suit pickup rejects broken tail unless it is bottom single card',
      () {
        final validator = MoveValidator();
        final cards = [
          _card(1, CardRank.nine, CardSuit.spades),
          _card(2, CardRank.eight, CardSuit.hearts),
          _card(3, CardRank.seven, CardSuit.hearts),
        ];
        final state = _state(
          difficulty: Difficulty.fourSuit,
          columns: [cards, [], [], [], [], [], [], [], [], []],
        );

        expect(validator.getEffectiveMoveRun(state, 0, 0), isNull);

        final runFromOne = validator.getEffectiveMoveRun(state, 0, 1);
        expect(runFromOne, isNotNull);
        expect(runFromOne!.effectiveStartIndex, 1);
        expect(runFromOne.length, 2);

        final runFromBottom = validator.getEffectiveMoveRun(state, 0, 2);
        expect(runFromBottom, isNotNull);
        expect(runFromBottom!.effectiveStartIndex, 2);
        expect(runFromBottom.length, 1);
      },
    );

    test(
      'pickup start must be a valid tail run for the selected start index',
      () {
        final validator = MoveValidator();
        final state = _state(
          difficulty: Difficulty.fourSuit,
          columns: [
            [
              _card(1, CardRank.three, CardSuit.spades),
              _card(2, CardRank.seven, CardSuit.spades),
              _card(3, CardRank.six, CardSuit.spades),
              _card(4, CardRank.five, CardSuit.spades),
              _card(5, CardRank.four, CardSuit.spades),
            ],
            [],
            [],
            [],
            [],
            [],
            [],
            [],
            [],
            [],
          ],
        );

        expect(validator.getEffectiveMoveRun(state, 0, 0), isNull);

        final runAtSeven = validator.getEffectiveMoveRun(state, 0, 1);
        expect(runAtSeven, isNotNull);
        expect(runAtSeven!.length, 4);

        final runAtSix = validator.getEffectiveMoveRun(state, 0, 2);
        expect(runAtSix, isNotNull);
        expect(runAtSix!.length, 3);

        final runAtFive = validator.getEffectiveMoveRun(state, 0, 3);
        expect(runAtFive, isNotNull);
        expect(runAtFive!.length, 2);

        final runAtFour = validator.getEffectiveMoveRun(state, 0, 4);
        expect(runAtFour, isNotNull);
        expect(runAtFour!.length, 1);
      },
    );

    test('drop rules: empty allowed, rank+1 required otherwise', () {
      final validator = MoveValidator();
      final state = _state(
        difficulty: Difficulty.fourSuit,
        columns: [
          [_card(1, CardRank.nine, CardSuit.spades)],
          [_card(2, CardRank.ten, CardSuit.hearts)],
          [_card(3, CardRank.jack, CardSuit.hearts)],
          [],
          [],
          [],
          [],
          [],
          [],
          [],
        ],
      );

      expect(
        validator
            .canDropRun(state, 3, _card(4, CardRank.nine, CardSuit.clubs))
            .isValid,
        isTrue,
      );
      expect(
        validator
            .canDropRun(state, 1, _card(4, CardRank.nine, CardSuit.clubs))
            .isValid,
        isTrue,
      );
      expect(
        validator
            .canDropRun(state, 2, _card(4, CardRank.nine, CardSuit.clubs))
            .isValid,
        isFalse,
      );
    });

    test('getLegalDropTargets returns legal destination indices', () {
      final validator = MoveValidator();
      final state = _state(
        difficulty: Difficulty.fourSuit,
        columns: [
          [_card(1, CardRank.nine, CardSuit.spades)],
          [_card(2, CardRank.ten, CardSuit.hearts)],
          [_card(3, CardRank.jack, CardSuit.hearts)],
          [],
          [],
          [],
          [],
          [],
          [],
          [],
        ],
      );

      final targets = validator.getLegalDropTargets(
        state,
        _card(99, CardRank.nine, CardSuit.clubs),
      );

      expect(targets.contains(1), isTrue);
      expect(targets.contains(3), isTrue);
      expect(targets.contains(2), isFalse);
    });

    test('detects complete K..A run at column end', () {
      final validator = MoveValidator();
      final completeRun = [
        _card(10, CardRank.king, CardSuit.spades),
        _card(11, CardRank.queen, CardSuit.spades),
        _card(12, CardRank.jack, CardSuit.spades),
        _card(13, CardRank.ten, CardSuit.spades),
        _card(14, CardRank.nine, CardSuit.spades),
        _card(15, CardRank.eight, CardSuit.spades),
        _card(16, CardRank.seven, CardSuit.spades),
        _card(17, CardRank.six, CardSuit.spades),
        _card(18, CardRank.five, CardSuit.spades),
        _card(19, CardRank.four, CardSuit.spades),
        _card(20, CardRank.three, CardSuit.spades),
        _card(21, CardRank.two, CardSuit.spades),
        _card(22, CardRank.ace, CardSuit.spades),
      ];
      final state = _state(
        difficulty: Difficulty.fourSuit,
        columns: [completeRun, [], [], [], [], [], [], [], [], []],
      );

      expect(validator.detectCompleteRunAtEnd(state, 0), 0);
    });
  });
}

PlayingCard _card(int id, CardRank rank, CardSuit suit, {bool faceUp = true}) {
  return PlayingCard(id: id, rank: rank, suit: suit, faceUp: faceUp);
}

GameState _state({
  required Difficulty difficulty,
  required List<List<PlayingCard>> columns,
}) {
  return GameState(
    tableau: TableauPiles(columns),
    stock: StockPile(const []),
    foundations: const Foundations(completedRuns: 0),
    difficulty: difficulty,
    dealSource: const RandomDealSource(1),
    seed: 1,
    startedAt: DateTime(2026, 1, 1),
    moves: 0,
    hintsUsed: 0,
  );
}
