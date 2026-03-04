import 'package:flutter_test/flutter_test.dart';
import 'package:haylau_spider_solitaire/game/engine/game_engine.dart';
import 'package:haylau_spider_solitaire/game/model/card.dart';
import 'package:haylau_spider_solitaire/game/model/deal_source.dart';
import 'package:haylau_spider_solitaire/game/model/difficulty.dart';
import 'package:haylau_spider_solitaire/game/model/game_state.dart';
import 'package:haylau_spider_solitaire/game/model/piles.dart';
import 'package:haylau_spider_solitaire/game/persistence/stats_repo.dart';
import 'package:haylau_spider_solitaire/utils/clock.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test(
    'completion updates lifetime totals and persists across reload',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});

      final startedAt = DateTime(2026, 1, 1, 0, 0, 0);
      final clock = _FixedClock(DateTime(2026, 1, 1, 0, 5, 0));

      final statsRepo = LocalStatsRepo();
      await statsRepo.loadStats();

      final engine = GameEngine(clock: clock, statsRepo: statsRepo);
      engine.newGame(
        difficulty: Difficulty.fourSuit,
        dealSource: const RandomDealSource(1),
      );

      engine.restoreState(
        _state(
          startedAt: startedAt,
          columns: [
            _completeRun(CardSuit.spades, startId: 1),
            _completeRun(CardSuit.spades, startId: 20),
            _completeRun(CardSuit.spades, startId: 40),
            _completeRun(CardSuit.spades, startId: 60),
            _completeRun(CardSuit.spades, startId: 80),
            _completeRun(CardSuit.spades, startId: 100),
            _completeRun(CardSuit.spades, startId: 120),
            _completeRun(CardSuit.spades, startId: 140),
            [_card(500, CardRank.five, CardSuit.hearts)],
            [],
          ],
        ),
      );

      expect(engine.moveStack(8, 0, 9), isTrue);
      await Future<void>.delayed(const Duration(milliseconds: 10));

      final stats = statsRepo.current();
      expect(stats.totalGamesStarted, 1);
      expect(stats.totalGamesCompleted, 1);
      expect(stats.winsByDifficulty[Difficulty.fourSuit], 1);
      expect(stats.bestTimeByDifficulty[Difficulty.fourSuit], 300);
      expect(stats.bestScoreByDifficulty[Difficulty.fourSuit], 126890);
      expect(stats.lifetimeTotalScore, 126890);

      final reloadedRepo = LocalStatsRepo();
      final reloaded = await reloadedRepo.loadStats();
      expect(reloaded.totalGamesCompleted, 1);
      expect(reloaded.lifetimeTotalScore, 126890);
      expect(reloaded.bestScoreByDifficulty[Difficulty.fourSuit], 126890);
    },
  );
}

class _FixedClock implements Clock {
  _FixedClock(this._now);

  final DateTime _now;

  @override
  DateTime now() => _now;
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
  required DateTime startedAt,
  required List<List<PlayingCard>> columns,
}) {
  return GameState(
    tableau: TableauPiles(columns),
    stock: StockPile(const []),
    foundations: const Foundations(completedRuns: 0),
    difficulty: Difficulty.fourSuit,
    dealSource: const RandomDealSource(1),
    seed: 1,
    startedAt: startedAt,
    moves: 0,
    hintsUsed: 0,
  );
}
