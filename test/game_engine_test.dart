import 'package:flutter_test/flutter_test.dart';
import 'package:haylau_spider_solitaire/game/engine/game_engine.dart';
import 'package:haylau_spider_solitaire/game/model/card.dart';
import 'package:haylau_spider_solitaire/game/model/deal_source.dart';
import 'package:haylau_spider_solitaire/game/model/difficulty.dart';
import 'package:haylau_spider_solitaire/game/model/game_state.dart';
import 'package:haylau_spider_solitaire/game/model/piles.dart';
import 'package:haylau_spider_solitaire/game/persistence/stats_repo.dart';

void main() {
  test('deterministic shuffle with same seed', () {
    final deck = GameEngine.buildDeckForTest(Difficulty.fourSuit);
    final a = GameEngine.shuffleForTest(deck, 4242).map((c) => c.id).toList();
    final b = GameEngine.shuffleForTest(deck, 4242).map((c) => c.id).toList();
    final c = GameEngine.shuffleForTest(deck, 99).map((c) => c.id).toList();

    expect(a, b);
    expect(a, isNot(c));
  });

  test('debugForceWin marks game as won', () {
    final engine = GameEngine();
    engine.newGame(
      difficulty: Difficulty.fourSuit,
      dealSource: const RandomDealSource(20260227),
    );

    expect(engine.isGameWon, isFalse);

    engine.debugForceWin();

    expect(engine.isGameWon, isTrue);
    expect(engine.state.foundations.completedRuns, 8);
  });

  test('debug dev metrics are plausible and deterministic per deal', () {
    final engineA = GameEngine();
    engineA.newGame(
      difficulty: Difficulty.twoSuit,
      dealSource: const RandomDealSource(12345),
    );
    engineA.debugSetDevResultMetrics();

    final engineB = GameEngine();
    engineB.newGame(
      difficulty: Difficulty.twoSuit,
      dealSource: const RandomDealSource(12345),
    );
    engineB.debugSetDevResultMetrics();

    final aElapsed = engineA.elapsedSeconds();
    final bElapsed = engineB.elapsedSeconds();

    expect(aElapsed, inInclusiveRange(600, 1200));
    expect(engineA.state.moves, inInclusiveRange(200, 350));
    expect(engineA.state.undosUsed, inInclusiveRange(2, 10));
    expect(engineA.state.hintsUsed, inInclusiveRange(0, 3));
    expect(
      engineA.state.redosUsed,
      inInclusiveRange(0, engineA.state.undosUsed),
    );

    expect(bElapsed, aElapsed);
    expect(engineB.state.moves, engineA.state.moves);
    expect(engineB.state.undosUsed, engineA.state.undosUsed);
    expect(engineB.state.redosUsed, engineA.state.redosUsed);
    expect(engineB.state.hintsUsed, engineA.state.hintsUsed);
  });
  test('newGame increments started stats; resume does not', () {
    final statsRepo = InMemoryStatsRepo();
    final engine = GameEngine(statsRepo: statsRepo);

    expect(statsRepo.current().totalGamesStarted, 0);

    engine.newGame(
      difficulty: Difficulty.oneSuit,
      dealSource: const RandomDealSource(1),
    );
    expect(statsRepo.current().totalGamesStarted, 1);

    final savedState = engine.state;
    engine.restoreState(savedState);
    expect(statsRepo.current().totalGamesStarted, 1);

    engine.newGame(
      difficulty: Difficulty.fourSuit,
      dealSource: const RandomDealSource(2),
    );
    expect(statsRepo.current().totalGamesStarted, 2);
  });

  test('hasAnyValidMoves detects stuck state and stock-rule availability', () {
    final engine = GameEngine();
    final stuckColumns = List<List<PlayingCard>>.generate(
      10,
      (i) => <PlayingCard>[
        PlayingCard(
          id: i,
          rank: CardRank.ace,
          suit: CardSuit.spades,
          faceUp: true,
        ),
      ],
    );

    final stuckState = GameState(
      tableau: TableauPiles(stuckColumns),
      stock: StockPile(const <PlayingCard>[]),
      foundations: const Foundations(completedRuns: 0),
      difficulty: Difficulty.fourSuit,
      dealSource: const RandomDealSource(7),
      seed: 7,
      startedAt: DateTime(2026, 3, 1),
      moves: 0,
      hintsUsed: 0,
    );

    engine.restoreState(stuckState);
    expect(engine.hasAnyValidMoves(unrestrictedDealRule: false), isFalse);
    expect(engine.hasAnyValidMoves(unrestrictedDealRule: true), isFalse);

    final stockCards = List<PlayingCard>.generate(
      10,
      (i) => PlayingCard(
        id: 100 + i,
        rank: CardRank.king,
        suit: CardSuit.hearts,
        faceUp: false,
      ),
    );
    engine.restoreState(stuckState.copyWith(stock: StockPile(stockCards)));
    expect(engine.hasAnyValidMoves(unrestrictedDealRule: true), isTrue);
    expect(engine.hasAnyValidMoves(unrestrictedDealRule: false), isTrue);

    final classicBlocked = stuckState.copyWith(
      stock: StockPile(stockCards),
      tableau: TableauPiles(
        List<List<PlayingCard>>.generate(10, (_) => <PlayingCard>[]),
      ),
    );
    engine.restoreState(classicBlocked);
    expect(engine.hasAnyValidMoves(unrestrictedDealRule: false), isFalse);
    expect(engine.hasAnyValidMoves(unrestrictedDealRule: true), isTrue);
  });

  test('findHintMove returns a legal best-ranked move', () {
    final engine = GameEngine();
    engine.newGame(
      difficulty: Difficulty.fourSuit,
      dealSource: const RandomDealSource(10),
    );

    final state = GameState(
      tableau: TableauPiles([
        [
          PlayingCard(
            id: 1,
            rank: CardRank.king,
            suit: CardSuit.spades,
            faceUp: false,
          ),
          PlayingCard(
            id: 2,
            rank: CardRank.queen,
            suit: CardSuit.spades,
            faceUp: true,
          ),
          PlayingCard(
            id: 3,
            rank: CardRank.jack,
            suit: CardSuit.spades,
            faceUp: true,
          ),
        ],
        [
          PlayingCard(
            id: 4,
            rank: CardRank.king,
            suit: CardSuit.hearts,
            faceUp: true,
          ),
          PlayingCard(
            id: 5,
            rank: CardRank.queen,
            suit: CardSuit.hearts,
            faceUp: true,
          ),
        ],
        [
          PlayingCard(
            id: 6,
            rank: CardRank.king,
            suit: CardSuit.spades,
            faceUp: true,
          ),
        ],
        [],
        [],
        [],
        [],
        [],
        [],
        [],
      ]),
      stock: StockPile(const <PlayingCard>[]),
      foundations: const Foundations(completedRuns: 0),
      difficulty: Difficulty.fourSuit,
      dealSource: const RandomDealSource(10),
      seed: 10,
      startedAt: DateTime(2026, 3, 1),
      moves: 0,
      hintsUsed: 0,
    );

    engine.restoreState(state);
    final hint = engine.findHintMove();

    expect(hint, isNotNull);
    expect(hint!.fromColumn, 0);
    expect(hint.startIndex, 1);
    expect(hint.toColumn, 2);
  });

  test('findHintMove returns null when no tableau move exists', () {
    final engine = GameEngine();
    engine.newGame(
      difficulty: Difficulty.fourSuit,
      dealSource: const RandomDealSource(11),
    );

    final stuckColumns = List<List<PlayingCard>>.generate(
      10,
      (i) => <PlayingCard>[
        PlayingCard(
          id: i,
          rank: CardRank.ace,
          suit: CardSuit.spades,
          faceUp: true,
        ),
      ],
    );

    engine.restoreState(
      GameState(
        tableau: TableauPiles(stuckColumns),
        stock: StockPile(const <PlayingCard>[]),
        foundations: const Foundations(completedRuns: 0),
        difficulty: Difficulty.fourSuit,
        dealSource: const RandomDealSource(11),
        seed: 11,
        startedAt: DateTime(2026, 3, 1),
        moves: 0,
        hintsUsed: 0,
      ),
    );

    expect(engine.findHintMove(), isNull);
  });

  test('hasAnyProgressMoves false when only reversible shuffle exists', () {
    final engine = GameEngine();
    engine.newGame(
      difficulty: Difficulty.fourSuit,
      dealSource: const RandomDealSource(99),
    );

    final columns = <List<PlayingCard>>[
      [
        PlayingCard(
          id: 1,
          rank: CardRank.seven,
          suit: CardSuit.spades,
          faceUp: true,
        ),
      ],
      [
        PlayingCard(
          id: 2,
          rank: CardRank.eight,
          suit: CardSuit.hearts,
          faceUp: true,
        ),
      ],
      [
        PlayingCard(
          id: 3,
          rank: CardRank.ace,
          suit: CardSuit.clubs,
          faceUp: true,
        ),
      ],
      [
        PlayingCard(
          id: 4,
          rank: CardRank.ace,
          suit: CardSuit.diamonds,
          faceUp: true,
        ),
      ],
      [
        PlayingCard(
          id: 5,
          rank: CardRank.ace,
          suit: CardSuit.hearts,
          faceUp: true,
        ),
      ],
      [
        PlayingCard(
          id: 6,
          rank: CardRank.ace,
          suit: CardSuit.spades,
          faceUp: true,
        ),
      ],
      [
        PlayingCard(
          id: 7,
          rank: CardRank.king,
          suit: CardSuit.clubs,
          faceUp: true,
        ),
      ],
      [
        PlayingCard(
          id: 8,
          rank: CardRank.king,
          suit: CardSuit.diamonds,
          faceUp: true,
        ),
      ],
      [
        PlayingCard(
          id: 9,
          rank: CardRank.king,
          suit: CardSuit.hearts,
          faceUp: true,
        ),
      ],
      [
        PlayingCard(
          id: 10,
          rank: CardRank.king,
          suit: CardSuit.spades,
          faceUp: true,
        ),
      ],
    ];

    engine.restoreState(
      GameState(
        tableau: TableauPiles(columns),
        stock: StockPile(const <PlayingCard>[]),
        foundations: const Foundations(completedRuns: 0),
        difficulty: Difficulty.fourSuit,
        dealSource: const RandomDealSource(99),
        seed: 99,
        startedAt: DateTime(2026, 3, 1),
        moves: 0,
        hintsUsed: 0,
      ),
    );

    expect(engine.hasAnyValidMoves(unrestrictedDealRule: false), isTrue);
    expect(engine.hasAnyProgressMoves(unrestrictedDealRule: false), isFalse);
  });

  test('getUsefulMovableRuns is empty for reversible-only shuffles', () {
    final engine = GameEngine();
    engine.newGame(
      difficulty: Difficulty.fourSuit,
      dealSource: const RandomDealSource(100),
    );

    final columns = <List<PlayingCard>>[
      [
        PlayingCard(
          id: 1,
          rank: CardRank.seven,
          suit: CardSuit.spades,
          faceUp: true,
        ),
      ],
      [
        PlayingCard(
          id: 2,
          rank: CardRank.eight,
          suit: CardSuit.hearts,
          faceUp: true,
        ),
      ],
      [
        PlayingCard(
          id: 3,
          rank: CardRank.ace,
          suit: CardSuit.clubs,
          faceUp: true,
        ),
      ],
      [
        PlayingCard(
          id: 4,
          rank: CardRank.ace,
          suit: CardSuit.diamonds,
          faceUp: true,
        ),
      ],
      [
        PlayingCard(
          id: 5,
          rank: CardRank.ace,
          suit: CardSuit.hearts,
          faceUp: true,
        ),
      ],
      [
        PlayingCard(
          id: 6,
          rank: CardRank.ace,
          suit: CardSuit.spades,
          faceUp: true,
        ),
      ],
      [
        PlayingCard(
          id: 7,
          rank: CardRank.king,
          suit: CardSuit.clubs,
          faceUp: true,
        ),
      ],
      [
        PlayingCard(
          id: 8,
          rank: CardRank.king,
          suit: CardSuit.diamonds,
          faceUp: true,
        ),
      ],
      [
        PlayingCard(
          id: 9,
          rank: CardRank.king,
          suit: CardSuit.hearts,
          faceUp: true,
        ),
      ],
      [
        PlayingCard(
          id: 10,
          rank: CardRank.king,
          suit: CardSuit.spades,
          faceUp: true,
        ),
      ],
    ];

    engine.restoreState(
      GameState(
        tableau: TableauPiles(columns),
        stock: StockPile(const <PlayingCard>[]),
        foundations: const Foundations(completedRuns: 0),
        difficulty: Difficulty.fourSuit,
        dealSource: const RandomDealSource(100),
        seed: 100,
        startedAt: DateTime(2026, 3, 1),
        moves: 0,
        hintsUsed: 0,
      ),
    );

    expect(engine.getUsefulMovableRuns(), isEmpty);
  });

  test('lateral same-rank shuffle has zero progress score', () {
    final engine = GameEngine();
    engine.newGame(
      difficulty: Difficulty.fourSuit,
      dealSource: const RandomDealSource(102),
    );

    engine.restoreState(
      GameState(
        tableau: TableauPiles([
          [
            const PlayingCard(
              id: 1,
              rank: CardRank.nine,
              suit: CardSuit.spades,
              faceUp: true,
            ),
            const PlayingCard(
              id: 2,
              rank: CardRank.eight,
              suit: CardSuit.spades,
              faceUp: true,
            ),
            const PlayingCard(
              id: 3,
              rank: CardRank.seven,
              suit: CardSuit.spades,
              faceUp: true,
            ),
          ],
          [
            const PlayingCard(
              id: 4,
              rank: CardRank.ten,
              suit: CardSuit.spades,
              faceUp: true,
            ),
          ],
          [
            const PlayingCard(
              id: 5,
              rank: CardRank.ten,
              suit: CardSuit.spades,
              faceUp: true,
            ),
          ],
          [
            const PlayingCard(
              id: 6,
              rank: CardRank.king,
              suit: CardSuit.hearts,
              faceUp: true,
            ),
          ],
          [
            const PlayingCard(
              id: 7,
              rank: CardRank.king,
              suit: CardSuit.clubs,
              faceUp: true,
            ),
          ],
          [
            const PlayingCard(
              id: 8,
              rank: CardRank.king,
              suit: CardSuit.diamonds,
              faceUp: true,
            ),
          ],
          [
            const PlayingCard(
              id: 9,
              rank: CardRank.ace,
              suit: CardSuit.hearts,
              faceUp: true,
            ),
          ],
          [
            const PlayingCard(
              id: 10,
              rank: CardRank.ace,
              suit: CardSuit.clubs,
              faceUp: true,
            ),
          ],
          [
            const PlayingCard(
              id: 11,
              rank: CardRank.ace,
              suit: CardSuit.diamonds,
              faceUp: true,
            ),
          ],
          [
            const PlayingCard(
              id: 12,
              rank: CardRank.ace,
              suit: CardSuit.spades,
              faceUp: true,
            ),
          ],
        ]),
        stock: StockPile(const <PlayingCard>[]),
        foundations: const Foundations(completedRuns: 0),
        difficulty: Difficulty.fourSuit,
        dealSource: const RandomDealSource(102),
        seed: 102,
        startedAt: DateTime(2026, 3, 1),
        moves: 0,
        hintsUsed: 0,
      ),
    );

    expect(engine.hasAnyValidMoves(unrestrictedDealRule: false), isTrue);
    expect(engine.bestProgressScore(), 0);
    expect(engine.getBestProgressMove(), isNull);
    expect(engine.hasAnyProgressMoves(unrestrictedDealRule: false), isFalse);
  });

  test('getUsefulMovableRuns includes reveal-facedown run', () {
    final engine = GameEngine();
    engine.newGame(
      difficulty: Difficulty.fourSuit,
      dealSource: const RandomDealSource(101),
    );

    engine.restoreState(
      GameState(
        tableau: TableauPiles([
          [
            PlayingCard(
              id: 1,
              rank: CardRank.king,
              suit: CardSuit.spades,
              faceUp: false,
            ),
            PlayingCard(
              id: 2,
              rank: CardRank.queen,
              suit: CardSuit.spades,
              faceUp: true,
            ),
          ],
          [
            PlayingCard(
              id: 3,
              rank: CardRank.king,
              suit: CardSuit.hearts,
              faceUp: true,
            ),
          ],
          [],
          [],
          [],
          [],
          [],
          [],
          [],
          [],
        ]),
        stock: StockPile(const <PlayingCard>[]),
        foundations: const Foundations(completedRuns: 0),
        difficulty: Difficulty.fourSuit,
        dealSource: const RandomDealSource(101),
        seed: 101,
        startedAt: DateTime(2026, 3, 1),
        moves: 0,
        hintsUsed: 0,
      ),
    );

    final runs = engine.getUsefulMovableRuns();
    expect(runs, isNotEmpty);
    expect(runs.first.fromColumn, 0);
    expect(runs.first.startIndex, 1);
    expect(runs.first.length, 1);
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
