import 'package:flutter_test/flutter_test.dart';
import 'package:haylau_spider_solitaire/game/engine/game_engine.dart';
import 'package:haylau_spider_solitaire/game/model/deal_source.dart';
import 'package:haylau_spider_solitaire/game/model/difficulty.dart';

void main() {
  test('deterministic shuffle with same seed', () {
    final deck = GameEngine.buildDeckForTest(Difficulty.fourSuit);
    final a = GameEngine.shuffleForTest(deck, 4242).map((c) => c.id).toList();
    final b = GameEngine.shuffleForTest(deck, 4242).map((c) => c.id).toList();
    final c = GameEngine.shuffleForTest(deck, 99).map((c) => c.id).toList();

    expect(a, b);
    expect(a, isNot(c));
  });

  test('initial deal has correct tableau and stock counts', () {
    final engine = GameEngine();
    engine.newGame(
      difficulty: Difficulty.fourSuit,
      dealSource: const RandomDealSource(20260227),
    );

    final state = engine.state;
    expect(state.tableau.columns.length, 10);
    expect(state.tableau.columns.take(4).every((c) => c.length == 6), isTrue);
    expect(state.tableau.columns.skip(4).every((c) => c.length == 5), isTrue);
    expect(state.stock.cards.length, 50);
    expect(state.tableau.columns.every((c) => c.last.faceUp), isTrue);
  });
}
