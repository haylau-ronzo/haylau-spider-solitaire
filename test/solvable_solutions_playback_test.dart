import 'package:flutter_test/flutter_test.dart';
import 'package:haylau_spider_solitaire/game/engine/game_engine.dart';
import 'package:haylau_spider_solitaire/game/model/deal_source.dart';
import 'package:haylau_spider_solitaire/game/model/difficulty.dart';
import 'package:haylau_spider_solitaire/game/solvable/solvable_solution_step.dart';
import 'package:haylau_spider_solitaire/game/solvable/solvable_solutions_1suit_verified.dart';
import 'package:haylau_spider_solitaire/game/solvable/verified_solvable_data_override.dart';

void main() {
  bool applyStep(GameEngine engine, SolutionStepDto step) {
    if (step.isDeal) {
      return engine.dealFromStock();
    }
    if (!step.isMove ||
        step.fromColumn == null ||
        step.toColumn == null ||
        step.startIndex == null) {
      return false;
    }
    return engine.moveStack(step.fromColumn!, step.startIndex!, step.toColumn!);
  }

  test('ignore-verified override hides solution maps at read API', () {
    setIgnoreVerifiedSolvableData(true);
    addTearDown(() => setIgnoreVerifiedSolvableData(false));

    expect(verifiedSolutionPrefixForSeed1Suit(9), isNull);
    expect(verifiedFullSolutionForSeed1Suit(9), isNull);
  });

  test('seed 9 prefix steps apply cleanly from initial state when present', () {
    final steps = solutionFirst30_1Suit[9];
    if (steps == null || steps.isEmpty) {
      expect(true, isTrue);
      return;
    }

    final engine = GameEngine();
    engine.newGame(
      difficulty: Difficulty.oneSuit,
      dealSource: const RandomDealSource(9),
    );

    for (final step in steps) {
      expect(applyStep(engine, step), isTrue);
    }

    expect(engine.state.tableau.columns.length, 10);
    expect(engine.state.foundations.completedRuns, greaterThanOrEqualTo(0));
  });

  test(
    'every 30-step prefix has at most five deal steps and includes a move',
    () {
      for (final entry in solutionFirst30_1Suit.entries) {
        final steps = entry.value;
        if (steps.isEmpty) {
          continue;
        }

        final dealCount = steps.where((s) => s.isDeal).length;
        final moveCount = steps.where((s) => s.isMove).length;

        expect(
          dealCount,
          lessThanOrEqualTo(5),
          reason: 'seed ${entry.key} has too many deal steps in 30-step prefix',
        );
        expect(
          moveCount,
          greaterThan(0),
          reason: 'seed ${entry.key} prefix has no move steps',
        );
      }
    },
  );

  test('seed 9 full solution reaches win when fixture is present', () {
    final steps = solutionFull_1Suit[9];
    if (steps == null || steps.isEmpty) {
      expect(true, isTrue);
      return;
    }

    final engine = GameEngine();
    engine.newGame(
      difficulty: Difficulty.oneSuit,
      dealSource: const RandomDealSource(9),
    );

    for (final step in steps) {
      expect(applyStep(engine, step), isTrue);
    }

    expect(engine.isWon, isTrue);
  });

  String snapshot(GameEngine engine) {
    final s = engine.state;
    final tableau = s.tableau.columns
        .map(
          (col) =>
              col.map((card) => '${card.id}:${card.faceUp ? 1 : 0}').join(','),
        )
        .join('|');
    final stock = s.stock.cards
        .map((card) => '${card.id}:${card.faceUp ? 1 : 0}')
        .join(',');
    return '${s.moves};${s.foundations.completedRuns};$tableau;$stock';
  }

  test(
    'preview simulation mutates preview engine and leaves real engine unchanged when fixture is present',
    () {
      final steps = solutionFirst30_1Suit[9];
      if (steps == null || steps.isEmpty) {
        expect(true, isTrue);
        return;
      }

      final realEngine = GameEngine();
      realEngine.newGame(
        difficulty: Difficulty.oneSuit,
        dealSource: const RandomDealSource(9),
      );

      final beforeSnapshot = snapshot(realEngine);

      final previewEngine = GameEngine();
      previewEngine.restoreState(realEngine.state);

      expect(applyStep(previewEngine, steps.first), isTrue);
      final previewSnapshotAfterStep = snapshot(previewEngine);
      expect(previewSnapshotAfterStep, isNot(beforeSnapshot));

      final afterSnapshot = snapshot(realEngine);
      expect(afterSnapshot, beforeSnapshot);
    },
  );

  test('known verified prefix has both deal and move steps', () {
    final steps = solutionFirst30_1Suit[2] ?? solutionFirst30_1Suit[29];
    if (steps == null || steps.isEmpty) {
      expect(true, isTrue);
      return;
    }

    final hasDeal = steps.any((s) => s.isDeal);
    final hasMove = steps.any((s) => s.isMove);

    expect(hasDeal, isTrue);
    expect(hasMove, isTrue);
  });

  test('seed 2 step 6 is MOVE (not DEAL)', () {
    final steps = solutionFirst30_1Suit[2];
    if (steps == null || steps.length <= 5) {
      expect(true, isTrue);
      return;
    }

    expect(steps[5].kind, SolutionStepKind.move);
    expect(steps[5].isMove, isTrue);
    expect(steps[5].isDeal, isFalse);
  });

  test('seed 2 first six steps replay with legal move at step 6', () {
    final steps = solutionFirst30_1Suit[2];
    if (steps == null || steps.length < 6) {
      expect(true, isTrue);
      return;
    }

    final engine = GameEngine();
    engine.newGame(
      difficulty: Difficulty.oneSuit,
      dealSource: const RandomDealSource(2),
    );

    for (var i = 0; i < 5; i++) {
      expect(steps[i].isDeal, isTrue, reason: 'step ${i + 1} should be DEAL');
      expect(engine.dealFromStock(), isTrue);
    }

    final move = steps[5];
    expect(move.kind, SolutionStepKind.move);
    expect(move.fromColumn, isNotNull);
    expect(move.toColumn, isNotNull);
    expect(move.startIndex, isNotNull);

    final run = engine.getEffectiveMoveRun(move.fromColumn!, move.startIndex!);
    expect(run, isNotNull);

    if (move.movedLength != null) {
      expect(run!.length, move.movedLength);
    }

    final firstCard = engine
        .state
        .tableau
        .columns[move.fromColumn!][run!.effectiveStartIndex];
    final drop = engine.canDropRun(move.toColumn!, firstCard);
    expect(
      drop.isValid,
      isTrue,
      reason: 'expected legal drop for step 6, got: ${drop.reason}',
    );

    expect(
      engine.moveStack(move.fromColumn!, move.startIndex!, move.toColumn!),
      isTrue,
    );
  });
}
