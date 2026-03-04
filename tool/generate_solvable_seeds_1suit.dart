import 'dart:io';
import 'dart:math';

import 'package:haylau_spider_solitaire/game/engine/move_validator.dart';
import 'package:haylau_spider_solitaire/game/engine_core/spider_engine_core.dart';
import 'package:haylau_spider_solitaire/game/model/difficulty.dart';
import 'package:haylau_spider_solitaire/game/model/game_state.dart';
import 'package:haylau_spider_solitaire/game/solvable/solvable_solution_step.dart';
import 'package:haylau_spider_solitaire/game/solvable/solution_step_replayer.dart';

void main(List<String> args) {
  if (_GeneratorConfig.wantsHelp(args)) {
    stdout.write(_GeneratorConfig.usage());
    return;
  }

  final config = _GeneratorConfig.fromArgs(args);
  final solver = _OneSuitSeedSolver(
    perSeedMs: config.perSeedMs,
    nodeCap: config.nodeCap,
    maxDepth: config.maxDepth,
    randomWalkTrials: config.randomWalkTrials,
    randomWalkSteps: config.randomWalkSteps,
  );

  final dailySeeds = <int>[];
  final randomSeeds = <int>[];
  final used = <int>{};

  final prefixBySeed = <int, List<SolutionStepDto>>{};
  final fullBySeed = <int, List<SolutionStepDto>>{};

  var candidate = config.seedStart;
  var attempts = 0;
  var solved = 0;
  var unsolved = 0;
  var timedOut = 0;
  var rejectedInvalidSolutions = 0;

  while (dailySeeds.length < config.dailyCount) {
    attempts++;
    final currentSeed = candidate;
    final outcome = solver.solveSeed(currentSeed);
    final result = outcome.result;

    if (result == _SolveResult.solvable) {
      final replayError = _replayValidationError(
        seed: currentSeed,
        difficulty: Difficulty.oneSuit,
        steps: outcome.solutionSteps,
      );
      if (replayError != null) {
        rejectedInvalidSolutions++;
        unsolved++;
        stdout.writeln(
          'REJECT seed $currentSeed invalid solution: $replayError',
        );
      } else if (used.add(currentSeed)) {
        dailySeeds.add(currentSeed);
        solved++;
        final full = outcome.solutionSteps;
        prefixBySeed[currentSeed] = full
            .take(config.solutionPrefixSteps)
            .toList();
        if (config.emitFullSolution) {
          fullBySeed[currentSeed] = full;
        }
        stdout.writeln(
          'Daily ${dailySeeds.length}/${config.dailyCount} <- $currentSeed',
        );
      }
    } else if (result == _SolveResult.timeout) {
      timedOut++;
    } else {
      unsolved++;
    }

    _logProgress(
      attempts: attempts,
      dailyFound: dailySeeds.length,
      randomFound: randomSeeds.length,
      timedOut: timedOut,
      currentSeed: currentSeed,
      result: result,
    );
    candidate++;
  }

  while (randomSeeds.length < config.randomCount) {
    attempts++;
    final currentSeed = candidate;
    final outcome = solver.solveSeed(currentSeed);
    final result = outcome.result;

    if (result == _SolveResult.solvable) {
      final replayError = _replayValidationError(
        seed: currentSeed,
        difficulty: Difficulty.oneSuit,
        steps: outcome.solutionSteps,
      );
      if (replayError != null) {
        rejectedInvalidSolutions++;
        unsolved++;
        stdout.writeln(
          'REJECT seed $currentSeed invalid solution: $replayError',
        );
      } else if (used.add(currentSeed)) {
        randomSeeds.add(currentSeed);
        solved++;
        final full = outcome.solutionSteps;
        prefixBySeed[currentSeed] = full
            .take(config.solutionPrefixSteps)
            .toList();
        if (config.emitFullSolution) {
          fullBySeed[currentSeed] = full;
        }
        stdout.writeln(
          'Random ${randomSeeds.length}/${config.randomCount} <- $currentSeed',
        );
      }
    } else if (result == _SolveResult.timeout) {
      timedOut++;
    } else {
      unsolved++;
    }

    _logProgress(
      attempts: attempts,
      dailyFound: dailySeeds.length,
      randomFound: randomSeeds.length,
      timedOut: timedOut,
      currentSeed: currentSeed,
      result: result,
    );
    candidate++;
  }

  final seedsOutput = _renderSeedsOutput(
    dailySeeds: dailySeeds,
    randomSeeds: randomSeeds,
  );
  final outSeedsFile = File(config.outPath);
  outSeedsFile.parent.createSync(recursive: true);
  outSeedsFile.writeAsStringSync(seedsOutput);

  final solutionsOutput = _renderSolutionsOutput(
    prefixBySeed: prefixBySeed,
    fullBySeed: fullBySeed,
  );
  final outSolutionsFile = File(config.solutionsOutPath);
  outSolutionsFile.parent.createSync(recursive: true);
  outSolutionsFile.writeAsStringSync(solutionsOutput);

  stdout.writeln('');
  stdout.writeln(
    'Wrote ${dailySeeds.length + randomSeeds.length} seeds to ${config.outPath}',
  );
  stdout.writeln('Wrote solutions to ${config.solutionsOutPath}');
  stdout.writeln(
    'Attempts: $attempts, solved: $solved, unsolved: $unsolved, timed out: $timedOut, rejectedInvalidSolutions: $rejectedInvalidSolutions',
  );
}

void _logProgress({
  required int attempts,
  required int dailyFound,
  required int randomFound,
  required int timedOut,
  required int currentSeed,
  required _SolveResult result,
}) {
  if (attempts % 25 == 0) {
    stdout.writeln('Seed $currentSeed -> ${result.name}');
  }
  if (attempts % 50 == 0) {
    stdout.writeln(
      'Heartbeat attempts=$attempts, dailyFound=$dailyFound, '
      'randomFound=$randomFound, timedOut=$timedOut, currentSeed=$currentSeed',
    );
  }
}

String _renderSeedsOutput({
  required List<int> dailySeeds,
  required List<int> randomSeeds,
}) {
  String renderList(List<int> values) {
    final lines = values.map((value) => '  $value,').join('\n');
    return '<int>[\n$lines\n]';
  }

  return '''// GENERATED CODE - DO NOT EDIT BY HAND.
// Generated by: tool/generate_solvable_seeds_1suit.dart

const List<int> dailySolvableSeeds1Suit = ${renderList(dailySeeds)};

const List<int> randomSolvableSeeds1Suit = ${renderList(randomSeeds)};
''';
}

String _renderSolutionsOutput({
  required Map<int, List<SolutionStepDto>> prefixBySeed,
  required Map<int, List<SolutionStepDto>> fullBySeed,
}) {
  String renderStep(SolutionStepDto step) {
    if (step.isDeal) {
      return 'const SolutionStepDto.deal()';
    }

    final moved = step.movedLength == null
        ? ''
        : ', movedLength: ${step.movedLength}';
    return 'const SolutionStepDto.move('
        'fromColumn: ${step.fromColumn}, '
        'toColumn: ${step.toColumn}, '
        'startIndex: ${step.startIndex}$moved)';
  }

  String renderMap(Map<int, List<SolutionStepDto>> values) {
    final seeds = values.keys.toList()..sort();
    final lines = <String>[];
    for (final seed in seeds) {
      final steps = values[seed]!;
      lines.add('  $seed: <SolutionStepDto>[');
      for (final step in steps) {
        lines.add('    ${renderStep(step)},');
      }
      lines.add('  ],');
    }

    return '<int, List<SolutionStepDto>>{\n${lines.join('\n')}\n}';
  }

  return '''// GENERATED CODE - DO NOT EDIT BY HAND.
// Generated by: tool/generate_solvable_seeds_1suit.dart

import 'solvable_solution_step.dart';

const Map<int, List<SolutionStepDto>> solutionFirst30_1Suit = ${renderMap(prefixBySeed)};

const Map<int, List<SolutionStepDto>> solutionFull_1Suit = ${renderMap(fullBySeed)};
''';
}

class _GeneratorConfig {
  const _GeneratorConfig({
    required this.dailyCount,
    required this.randomCount,
    required this.outPath,
    required this.solutionsOutPath,
    required this.seedStart,
    required this.perSeedMs,
    required this.nodeCap,
    required this.maxDepth,
    required this.randomWalkTrials,
    required this.randomWalkSteps,
    required this.solutionPrefixSteps,
    required this.emitFullSolution,
  });

  final int dailyCount;
  final int randomCount;
  final String outPath;
  final String solutionsOutPath;
  final int seedStart;
  final int perSeedMs;
  final int nodeCap;
  final int maxDepth;
  final int randomWalkTrials;
  final int randomWalkSteps;
  final int solutionPrefixSteps;
  final bool emitFullSolution;

  static bool wantsHelp(List<String> args) =>
      args.contains('--help') || args.contains('-h');

  static _GeneratorConfig fromArgs(List<String> args) {
    int intArg(String name, int fallback) {
      final prefix = '--$name=';
      final raw = args.cast<String?>().firstWhere(
        (arg) => arg != null && arg.startsWith(prefix),
        orElse: () => null,
      );
      if (raw == null) {
        return fallback;
      }
      return int.tryParse(raw.substring(prefix.length)) ?? fallback;
    }

    bool boolArg(String name, bool fallback) {
      final prefix = '--$name=';
      final raw = args.cast<String?>().firstWhere(
        (arg) => arg != null && arg.startsWith(prefix),
        orElse: () => null,
      );
      if (raw == null) {
        return fallback;
      }
      final value = raw.substring(prefix.length).toLowerCase();
      if (value == 'true') {
        return true;
      }
      if (value == 'false') {
        return false;
      }
      return fallback;
    }

    String stringArg(String name, String fallback) {
      final prefix = '--$name=';
      final raw = args.cast<String?>().firstWhere(
        (arg) => arg != null && arg.startsWith(prefix),
        orElse: () => null,
      );
      if (raw == null) {
        return fallback;
      }
      return raw.substring(prefix.length);
    }

    return _GeneratorConfig(
      dailyCount: intArg('daily-count', 10),
      randomCount: intArg('random-count', 20),
      outPath: stringArg('out', 'tool/tmp_generated_seeds_1suit.dart'),
      solutionsOutPath: stringArg(
        'solutions-out',
        'tool/tmp_generated_solutions_1suit.dart',
      ),
      seedStart: intArg('seed-start', 1),
      perSeedMs: intArg('per-seed-ms', 2000),
      nodeCap: intArg('node-cap', 120000),
      maxDepth: intArg('max-depth', 280),
      randomWalkTrials: intArg('random-walk-trials', 120),
      randomWalkSteps: intArg('random-walk-steps', 700),
      solutionPrefixSteps: intArg('solution-prefix-steps', 30),
      emitFullSolution: boolArg('emit-full-solution', false),
    );
  }

  static String usage() => '''Usage:
  dart run tool/generate_solvable_seeds_1suit.dart [options]

Options:
  --daily-count=<int>            Daily seeds to find (default: 10)
  --random-count=<int>           Random seeds to find (default: 20)
  --out=<path>                   Seeds output (default: tool/tmp_generated_seeds_1suit.dart)
  --solutions-out=<path>         Solutions output (default: tool/tmp_generated_solutions_1suit.dart)
  --seed-start=<int>             Start seed (default: 1)
  --seed-end=<int>               Inclusive end seed (default: unlimited)
  --max-attempts=<int>           Max candidate seeds to evaluate (default: unlimited)
  --per-seed-ms=<int>            Solve budget per seed in ms (default: 2000)
  --node-cap=<int>               DFS node cap (default: 120000)
  --max-depth=<int>              DFS max depth (default: 280)
  --random-walk-trials=<int>     RW trials (default: 120)
  --random-walk-steps=<int>      RW steps (default: 700)
  --solution-prefix-steps=<int>  Prefix length to emit (default: 30)
  --emit-full-solution=<bool>    Emit full map too (default: false)
''';
}

enum _SolveResult { solvable, unsolved, timeout }

class _SolveOutcome {
  const _SolveOutcome({required this.result, required this.solutionSteps});

  final _SolveResult result;
  final List<SolutionStepDto> solutionSteps;
}

class _Transition {
  const _Transition({required this.state, required this.step});

  final GameState state;
  final SolutionStepDto step;
}

class _OneSuitSeedSolver {
  _OneSuitSeedSolver({
    required this.perSeedMs,
    required this.nodeCap,
    required this.maxDepth,
    required this.randomWalkTrials,
    required this.randomWalkSteps,
  });

  final int perSeedMs;
  final int nodeCap;
  final int maxDepth;
  final int randomWalkTrials;
  final int randomWalkSteps;

  final MoveValidator _validator = const MoveValidator();

  _SolveOutcome solveSeed(int seed) {
    final watch = Stopwatch()..start();
    final initial = _initialStateForSeed(seed);

    final greedy = _tryGreedyWithPath(initial, maxSteps: 500);
    if (greedy != null) {
      return _SolveOutcome(
        result: _SolveResult.solvable,
        solutionSteps: greedy,
      );
    }

    final randomWalk = _tryRandomWalkWithPath(initial, seed, watch);
    if (randomWalk != null) {
      return _SolveOutcome(
        result: _SolveResult.solvable,
        solutionSteps: randomWalk,
      );
    }

    final remaining = perSeedMs - watch.elapsedMilliseconds;
    if (remaining <= 0) {
      return const _SolveOutcome(
        result: _SolveResult.unsolved,
        solutionSteps: <SolutionStepDto>[],
      );
    }

    final dfs = _searchWithPath(initial, remaining);
    return dfs;
  }

  List<SolutionStepDto>? _tryGreedyWithPath(
    GameState start, {
    required int maxSteps,
  }) {
    var state = start;
    final path = <SolutionStepDto>[];

    for (var step = 0; step < maxSteps; step++) {
      if (_isWon(state)) {
        return path;
      }

      final transitions = _expandMovesWithSteps(state);
      if (transitions.isNotEmpty) {
        transitions.sort(
          (a, b) => _stateScore(b.state).compareTo(_stateScore(a.state)),
        );
        final chosen = transitions.first;
        state = chosen.state;
        path.add(chosen.step);
        continue;
      }

      if (_canDealFromStockClassic(state)) {
        final dealt = SpiderEngineCore.tryDealFromStock(
          state,
          unrestrictedDealRule: false,
          validator: _validator,
        );
        if (dealt == null) {
          break;
        }
        state = dealt;
        path.add(const SolutionStepDto.deal());
        continue;
      }

      return null;
    }

    return _isWon(state) ? path : null;
  }

  List<SolutionStepDto>? _tryRandomWalkWithPath(
    GameState initial,
    int seed,
    Stopwatch watch,
  ) {
    final deadline = watch.elapsedMilliseconds + (perSeedMs * 40 ~/ 100);

    for (var trial = 0; trial < randomWalkTrials; trial++) {
      if (watch.elapsedMilliseconds >= deadline) {
        return null;
      }

      final random = Random(
        ((seed * 1103515245) ^ (trial * 12345)) & 0x7fffffff,
      );
      var state = initial;
      final path = <SolutionStepDto>[];

      for (var step = 0; step < randomWalkSteps; step++) {
        if (_isWon(state)) {
          return path;
        }
        if (watch.elapsedMilliseconds >= deadline) {
          return null;
        }

        final transitions = _expandMovesWithSteps(state);
        if (transitions.isNotEmpty) {
          final selected = _pickWeightedTransition(transitions, random);
          state = selected.state;
          path.add(selected.step);
          continue;
        }

        if (_canDealFromStockClassic(state)) {
          final dealt = SpiderEngineCore.tryDealFromStock(
            state,
            unrestrictedDealRule: false,
            validator: _validator,
          );
          if (dealt == null) {
            break;
          }
          state = dealt;
          path.add(const SolutionStepDto.deal());
          continue;
        }

        break;
      }

      if (_isWon(state)) {
        return path;
      }
    }

    return null;
  }

  _SolveOutcome _searchWithPath(GameState start, int budgetMs) {
    final watch = Stopwatch()..start();
    final nodes = <_Node>[
      _Node(state: start, depth: 0, parentIndex: null, stepFromParent: null),
    ];
    final stack = <int>[0];
    final bestSeen = <String, int>{};

    var explored = 0;
    while (stack.isNotEmpty) {
      if (watch.elapsedMilliseconds >= budgetMs) {
        return const _SolveOutcome(
          result: _SolveResult.timeout,
          solutionSteps: <SolutionStepDto>[],
        );
      }
      if (explored >= nodeCap) {
        return const _SolveOutcome(
          result: _SolveResult.timeout,
          solutionSteps: <SolutionStepDto>[],
        );
      }

      final nodeIndex = stack.removeLast();
      final node = nodes[nodeIndex];
      explored++;

      if (_isWon(node.state)) {
        return _SolveOutcome(
          result: _SolveResult.solvable,
          solutionSteps: _reconstructSteps(nodes, nodeIndex),
        );
      }
      if (node.depth >= maxDepth) {
        continue;
      }

      final key = _stateKey(node.state);
      final score = _stateScore(node.state);
      final prev = bestSeen[key];
      if (prev != null && prev >= score) {
        continue;
      }
      bestSeen[key] = score;

      final next = _expandAllWithSteps(node.state);
      next.sort((a, b) => _stateScore(a.state).compareTo(_stateScore(b.state)));
      for (final transition in next) {
        nodes.add(
          _Node(
            state: transition.state,
            depth: node.depth + 1,
            parentIndex: nodeIndex,
            stepFromParent: transition.step,
          ),
        );
        stack.add(nodes.length - 1);
      }
    }

    return const _SolveOutcome(
      result: _SolveResult.unsolved,
      solutionSteps: <SolutionStepDto>[],
    );
  }

  List<SolutionStepDto> _reconstructSteps(List<_Node> nodes, int winNodeIndex) {
    final reversed = <SolutionStepDto>[];
    var cursor = winNodeIndex;
    while (true) {
      final node = nodes[cursor];
      final step = node.stepFromParent;
      if (step != null) {
        reversed.add(step);
      }
      final parentIndex = node.parentIndex;
      if (parentIndex == null) {
        break;
      }
      cursor = parentIndex;
    }

    return reversed.reversed.toList(growable: false);
  }

  _Transition _pickWeightedTransition(
    List<_Transition> options,
    Random random,
  ) {
    var total = 0;
    for (final option in options) {
      total += option.step.isMove ? 2 : 1;
    }

    var pick = random.nextInt(total);
    for (final option in options) {
      pick -= option.step.isMove ? 2 : 1;
      if (pick < 0) {
        return option;
      }
    }

    return options.last;
  }

  GameState _initialStateForSeed(int seed) {
    return SpiderEngineCore.buildInitialState(
      seed: seed,
      difficulty: Difficulty.oneSuit,
      startedAt: DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  List<_Transition> _expandAllWithSteps(GameState state) {
    final results = <_Transition>[];
    results.addAll(_expandMovesWithSteps(state));

    if (_canDealFromStockClassic(state)) {
      final dealt = SpiderEngineCore.tryDealFromStock(
        state,
        unrestrictedDealRule: false,
        validator: _validator,
      );
      if (dealt != null) {
        results.add(
          _Transition(state: dealt, step: const SolutionStepDto.deal()),
        );
      }
    }

    return results;
  }

  List<_Transition> _expandMovesWithSteps(GameState state) {
    final results = <_Transition>[];

    for (
      var fromColumn = 0;
      fromColumn < state.tableau.columns.length;
      fromColumn++
    ) {
      final source = state.tableau.columns[fromColumn];

      for (var startIndex = 0; startIndex < source.length; startIndex++) {
        final run = _validator.getEffectiveMoveRun(
          state,
          fromColumn,
          startIndex,
        );
        if (run == null || run.effectiveStartIndex != startIndex) {
          continue;
        }

        for (
          var toColumn = 0;
          toColumn < state.tableau.columns.length;
          toColumn++
        ) {
          if (toColumn == fromColumn) {
            continue;
          }

          final move = SpiderEngineCore.tryMoveStack(
            state,
            fromColumn: fromColumn,
            startIndex: startIndex,
            toColumn: toColumn,
            validator: _validator,
          );
          if (!move.didMove) {
            continue;
          }

          results.add(
            _Transition(
              state: move.state,
              step: SolutionStepDto.move(
                fromColumn: fromColumn,
                toColumn: toColumn,
                startIndex: startIndex,
                movedLength: move.movedLength,
              ),
            ),
          );
        }
      }
    }

    return results;
  }

  bool _canDealFromStockClassic(GameState state) {
    return SpiderEngineCore.canDealFromStock(
      state,
      unrestrictedDealRule: false,
    );
  }

  bool _isWon(GameState state) => state.foundations.completedRuns >= 8;

  int _stateScore(GameState state) {
    final faceUpCount = state.tableau.columns
        .expand((column) => column)
        .where((card) => card.faceUp)
        .length;
    return (state.foundations.completedRuns * 10000) +
        ((104 - state.stock.cards.length) * 20) +
        faceUpCount;
  }

  String _stateKey(GameState state) {
    final sb = StringBuffer()
      ..write(state.foundations.completedRuns)
      ..write('|');

    for (final card in state.stock.cards) {
      sb
        ..write(card.rank.index)
        ..write(',');
    }
    sb.write('|');

    final columnKeys = <String>[];
    for (final column in state.tableau.columns) {
      final col = StringBuffer();
      for (final card in column) {
        col
          ..write(card.rank.index)
          ..write(card.faceUp ? 'u' : 'd')
          ..write(',');
      }
      columnKeys.add(col.toString());
    }

    columnKeys.sort();
    for (final key in columnKeys) {
      sb
        ..write(key)
        ..write(';');
    }

    return sb.toString();
  }
}

class _Node {
  const _Node({
    required this.state,
    required this.depth,
    required this.parentIndex,
    required this.stepFromParent,
  });

  final GameState state;
  final int depth;
  final int? parentIndex;
  final SolutionStepDto? stepFromParent;
}

String? _replayValidationError({
  required int seed,
  required Difficulty difficulty,
  required List<SolutionStepDto> steps,
}) {
  return strictReplayValidationError(
    seed: seed,
    difficulty: difficulty,
    steps: steps,
  );
}
