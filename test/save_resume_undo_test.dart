import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:haylau_spider_solitaire/game/engine/game_engine.dart';
import 'package:haylau_spider_solitaire/game/model/card.dart';
import 'package:haylau_spider_solitaire/game/model/deal_source.dart';
import 'package:haylau_spider_solitaire/game/model/difficulty.dart';
import 'package:haylau_spider_solitaire/game/model/game_state.dart';
import 'package:haylau_spider_solitaire/game/model/piles.dart';
import 'package:haylau_spider_solitaire/game/persistence/save_model.dart';

void main() {
  test('save/resume restores undo stack so undo reverts last move', () {
    final engine = GameEngine();
    engine.newGame(
      difficulty: Difficulty.fourSuit,
      dealSource: const RandomDealSource(11),
    );

    final stockDealRow = <PlayingCard>[
      _card(100, CardRank.queen, CardSuit.spades, faceUp: false),
      _card(101, CardRank.king, CardSuit.hearts, faceUp: false),
      _card(102, CardRank.two, CardSuit.clubs, faceUp: false),
      _card(103, CardRank.three, CardSuit.clubs, faceUp: false),
      _card(104, CardRank.four, CardSuit.clubs, faceUp: false),
      _card(105, CardRank.five, CardSuit.clubs, faceUp: false),
      _card(106, CardRank.six, CardSuit.clubs, faceUp: false),
      _card(107, CardRank.seven, CardSuit.clubs, faceUp: false),
      _card(108, CardRank.eight, CardSuit.clubs, faceUp: false),
      _card(109, CardRank.nine, CardSuit.clubs, faceUp: false),
    ];

    engine.restoreState(
      _state(
        difficulty: Difficulty.fourSuit,
        columns: [[], [], [], [], [], [], [], [], [], []],
        stock: stockDealRow,
      ),
    );

    expect(engine.dealFromStock(), isTrue);
    final afterDeal = engine.state;

    expect(engine.moveStack(0, 0, 1), isTrue);
    expect(engine.state.tableau.columns[0], isEmpty);
    expect(engine.state.tableau.columns[1].length, 2);

    final save = SaveModel(
      slotId: 'random',
      gameState: engine.state,
      undoStack: engine.undoStackSnapshot,
      redoStack: engine.redoStackSnapshot,
      savedAt: DateTime(2026, 2, 28),
    );

    final encoded = jsonEncode(save.toJson());
    final decoded = SaveModel.fromJson(
      jsonDecode(encoded) as Map<String, dynamic>,
    );

    final resumed = GameEngine();
    resumed.newGame(
      difficulty: Difficulty.oneSuit,
      dealSource: const RandomDealSource(999),
    );
    resumed.restoreState(
      decoded.gameState,
      undoStack: decoded.undoStack,
      redoStack: decoded.redoStack,
    );

    expect(resumed.canUndo, isTrue);
    expect(resumed.undo(), isTrue);

    expect(resumed.state.tableau.columns[0].single.rank, CardRank.queen);
    expect(resumed.state.tableau.columns[1].single.rank, CardRank.king);
    expect(resumed.state.tableau.columns[0].single.suit, CardSuit.spades);
    expect(resumed.state.tableau.columns[1].single.suit, CardSuit.hearts);
    expect(resumed.state.moves, afterDeal.moves);
    expect(resumed.canRedo, isTrue);
  });
}

PlayingCard _card(int id, CardRank rank, CardSuit suit, {bool faceUp = true}) {
  return PlayingCard(id: id, rank: rank, suit: suit, faceUp: faceUp);
}

GameState _state({
  required Difficulty difficulty,
  required List<List<PlayingCard>> columns,
  required List<PlayingCard> stock,
}) {
  return GameState(
    tableau: TableauPiles(columns),
    stock: StockPile(stock),
    foundations: const Foundations(completedRuns: 0),
    difficulty: difficulty,
    dealSource: const RandomDealSource(1),
    seed: 1,
    startedAt: DateTime(2026, 1, 1),
    moves: 0,
    hintsUsed: 0,
  );
}
