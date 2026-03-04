import 'package:flutter_test/flutter_test.dart';
import 'package:haylau_spider_solitaire/game/engine/game_engine.dart';
import 'package:haylau_spider_solitaire/game/model/card.dart';
import 'package:haylau_spider_solitaire/game/model/deal_source.dart';
import 'package:haylau_spider_solitaire/game/model/difficulty.dart';
import 'package:haylau_spider_solitaire/game/model/game_state.dart';
import 'package:haylau_spider_solitaire/game/model/piles.dart';

void main() {
  test('move flips exposed facedown card and supports undo/redo', () {
    final engine = GameEngine();
    engine.newGame(
      difficulty: Difficulty.fourSuit,
      dealSource: const RandomDealSource(1),
    );
    engine.restoreState(
      _state(
        difficulty: Difficulty.fourSuit,
        columns: [
          [
            _card(1, CardRank.king, CardSuit.spades, faceUp: false),
            _card(2, CardRank.queen, CardSuit.spades),
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
      ),
    );

    expect(engine.moveStack(0, 1, 1), isTrue);
    expect(engine.state.tableau.columns[0].single.faceUp, isTrue);
    expect(engine.state.moves, 1);

    expect(engine.undo(), isTrue);
    expect(engine.state.tableau.columns[0][0].faceUp, isFalse);
    expect(engine.state.tableau.columns[0][1].faceUp, isTrue);
    expect(engine.state.tableau.columns[1], isEmpty);
    expect(engine.state.moves, 0);

    expect(engine.redo(), isTrue);
    expect(engine.state.tableau.columns[0].single.faceUp, isTrue);
    expect(engine.state.tableau.columns[1].single.rank, CardRank.queen);
    expect(engine.state.moves, 1);
  });

  test('auto-complete run is removed and undoable', () {
    final engine = GameEngine();
    engine.newGame(
      difficulty: Difficulty.fourSuit,
      dealSource: const RandomDealSource(1),
    );
    engine.restoreState(
      _state(
        difficulty: Difficulty.fourSuit,
        columns: [
          _completeRun(CardSuit.spades, startId: 100),
          [_card(1, CardRank.five, CardSuit.hearts)],
          [],
          [],
          [],
          [],
          [],
          [],
          [],
          [],
        ],
      ),
    );

    expect(engine.moveStack(1, 0, 2), isTrue);
    expect(engine.state.foundations.completedRuns, 1);
    expect(engine.state.tableau.columns[0], isEmpty);
    expect(engine.state.moves, 1);

    expect(engine.undo(), isTrue);
    expect(engine.state.foundations.completedRuns, 0);
    expect(engine.state.tableau.columns[0].length, 13);
    expect(engine.state.tableau.columns[1], isEmpty);
    expect(engine.state.tableau.columns[2].single.rank, CardRank.five);
    expect(engine.state.moves, 1);

    expect(engine.undo(), isTrue);
    expect(engine.state.tableau.columns[1].single.rank, CardRank.five);
    expect(engine.state.tableau.columns[2], isEmpty);
    expect(engine.state.moves, 0);

    expect(engine.redo(), isTrue);
    expect(engine.redo(), isTrue);
    expect(engine.state.foundations.completedRuns, 1);
    expect(engine.state.tableau.columns[0], isEmpty);
    expect(engine.state.moves, 1);
  });

  test(
    'auto-complete flips newly exposed facedown card and undo reverts it',
    () {
      final engine = GameEngine();
      engine.newGame(
        difficulty: Difficulty.fourSuit,
        dealSource: const RandomDealSource(1),
      );
      engine.restoreState(
        _state(
          difficulty: Difficulty.fourSuit,
          columns: [
            [
              _card(1, CardRank.nine, CardSuit.hearts, faceUp: false),
              ..._completeRun(CardSuit.spades, startId: 100),
            ],
            [_card(2, CardRank.five, CardSuit.hearts)],
            [],
            [],
            [],
            [],
            [],
            [],
            [],
            [],
          ],
        ),
      );

      expect(engine.moveStack(1, 0, 2), isTrue);
      expect(engine.state.foundations.completedRuns, 1);
      expect(engine.state.tableau.columns[0].length, 1);
      expect(engine.state.tableau.columns[0].single.faceUp, isTrue);

      expect(engine.undo(), isTrue);
      expect(engine.state.foundations.completedRuns, 0);
      expect(engine.state.tableau.columns[0].length, 14);
      expect(engine.state.tableau.columns[0].first.faceUp, isFalse);
    },
  );

  test(
    'auto destination selection is deterministic with multiple legal targets',
    () {
      final engine = GameEngine();
      engine.newGame(
        difficulty: Difficulty.fourSuit,
        dealSource: const RandomDealSource(7),
      );
      engine.restoreState(
        _state(
          difficulty: Difficulty.fourSuit,
          columns: [
            [_card(1, CardRank.nine, CardSuit.hearts)],
            [_card(2, CardRank.ten, CardSuit.clubs)],
            [_card(3, CardRank.ten, CardSuit.hearts)],
            [
              _card(4, CardRank.jack, CardSuit.hearts),
              _card(5, CardRank.ten, CardSuit.hearts),
            ],
            [],
            [],
            [],
            [],
            [],
            [],
          ],
        ),
      );

      final moving = <PlayingCard>[_card(1, CardRank.nine, CardSuit.hearts)];
      final legal = engine
          .getLegalDropTargets(moving.first)
          .where((c) => c != 0)
          .toList();

      final selected = engine.chooseAutoDestination(
        fromColumn: 0,
        movedCards: moving,
        legalTargets: legal,
      );

      expect(selected, 3);
    },
  );
}

List<PlayingCard> _completeRun(CardSuit suit, {required int startId}) {
  final cards = <PlayingCard>[];
  var id = startId;
  for (final rank in const [
    CardRank.king,
    CardRank.queen,
    CardRank.jack,
    CardRank.ten,
    CardRank.nine,
    CardRank.eight,
    CardRank.seven,
    CardRank.six,
    CardRank.five,
    CardRank.four,
    CardRank.three,
    CardRank.two,
    CardRank.ace,
  ]) {
    cards.add(_card(id++, rank, suit));
  }
  return cards;
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
