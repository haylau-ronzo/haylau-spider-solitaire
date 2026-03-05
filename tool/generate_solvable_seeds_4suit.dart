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
  final solver = _FourSuitSeedSolver(
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

  while (_canEvaluateCandidate(
        config: config,
        attempts: attempts,
        seed: candidate,
      ) &&
      dailySeeds.length < config.dailyCount) {
    attempts++;
    final currentSeed = candidate;
    final outcome = solver.solveSeed(currentSeed);
    final result = outcome.result;
    int? foundProofLength;

    if (result == _SolveResult.solvable) {
      final verifiedProof = List<SolutionStepDto>.unmodifiable(
        outcome.solutionSteps,
      );
      final replayError = _replayValidationError(
        seed: currentSeed,
        difficulty: Difficulty.fourSuit,
        steps: verifiedProof,
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
        foundProofLength = verifiedProof.length;
        final full = verifiedProof;
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

    _logAttempt(
      seed: currentSeed,
      outcome: outcome,
      foundProofLength: foundProofLength,
    );

    _logProgress(
      progressEvery: config.progressEvery,
      attempts: attempts,
      dailyFound: dailySeeds.length,
      randomFound: randomSeeds.length,
      timedOut: timedOut,
      currentSeed: currentSeed,
    );
    candidate++;
  }

  while (_canEvaluateCandidate(
        config: config,
        attempts: attempts,
        seed: candidate,
      ) &&
      randomSeeds.length < config.randomCount) {
    attempts++;
    final currentSeed = candidate;
    final outcome = solver.solveSeed(currentSeed);
    final result = outcome.result;
    int? foundProofLength;

    if (result == _SolveResult.solvable) {
      final verifiedProof = List<SolutionStepDto>.unmodifiable(
        outcome.solutionSteps,
      );
      final replayError = _replayValidationError(
        seed: currentSeed,
        difficulty: Difficulty.fourSuit,
        steps: verifiedProof,
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
        foundProofLength = verifiedProof.length;
        final full = verifiedProof;
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

    _logAttempt(
      seed: currentSeed,
      outcome: outcome,
      foundProofLength: foundProofLength,
    );

    _logProgress(
      progressEvery: config.progressEvery,
      attempts: attempts,
      dailyFound: dailySeeds.length,
      randomFound: randomSeeds.length,
      timedOut: timedOut,
      currentSeed: currentSeed,
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
  _logLimitStopIfNeeded(
    config: config,
    attempts: attempts,
    nextSeed: candidate,
    dailyFound: dailySeeds.length,
    randomFound: randomSeeds.length,
  );
}

bool _canEvaluateCandidate({
  required _GeneratorConfig config,
  required int attempts,
  required int seed,
}) {
  if (config.maxAttempts != null && attempts >= config.maxAttempts!) {
    return false;
  }
  if (config.seedEnd != null && seed > config.seedEnd!) {
    return false;
  }
  return true;
}

void _logAttempt({
  required int seed,
  required _SolveOutcome outcome,
  required int? foundProofLength,
}) {
  if (foundProofLength != null) {
    stdout.writeln(
      'FOUND (seed=$seed, proofLength=$foundProofLength, elapsedMs=${outcome.elapsedMs})',
    );
    return;
  }

  switch (outcome.result) {
    case _SolveResult.timeout:
      stdout.writeln('TIMEOUT (seed=$seed, elapsedMs=${outcome.elapsedMs})');
      return;
    case _SolveResult.nodeCap:
      stdout.writeln('NODE_CAP (seed=$seed, nodesUsed=${outcome.nodesUsed})');
      return;
    case _SolveResult.depthCap:
      stdout.writeln(
        'DEPTH_CAP (seed=$seed, depthReached=${outcome.depthReached})',
      );
      return;
    case _SolveResult.unsolved:
      stdout.writeln('UNSOLVED (seed=$seed)');
      return;
    case _SolveResult.solvable:
      stdout.writeln('UNSOLVED (seed=$seed)');
      return;
  }
}

void _logProgress({
  required int progressEvery,
  required int attempts,
  required int dailyFound,
  required int randomFound,
  required int timedOut,
  required int currentSeed,
}) {
  if (progressEvery > 0 && attempts % progressEvery == 0) {
    stdout.writeln(
      'Progress attempts=$attempts, dailyFound=$dailyFound, randomFound=$randomFound, currentSeed=$currentSeed',
    );
  }
  if (attempts % 50 == 0) {
    stdout.writeln(
      'Heartbeat attempts=$attempts, dailyFound=$dailyFound, '
      'randomFound=$randomFound, timedOut=$timedOut, currentSeed=$currentSeed',
    );
  }
}

void _logLimitStopIfNeeded({
  required _GeneratorConfig config,
  required int attempts,
  required int nextSeed,
  required int dailyFound,
  required int randomFound,
}) {
  final targetReached =
      dailyFound >= config.dailyCount && randomFound >= config.randomCount;
  if (targetReached) {
    return;
  }
  if (config.maxAttempts != null && attempts >= config.maxAttempts!) {
    stdout.writeln(
      'Stopped by max-attempts=${config.maxAttempts} after $attempts seeds evaluated.',
    );
  }
  if (config.seedEnd != null && nextSeed > config.seedEnd!) {
    stdout.writeln('Stopped by seed-end=${config.seedEnd}.');
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
// Generated by: tool/generate_solvable_seeds_4suit.dart

const List<int> dailySolvableSeeds4Suit = ${renderList(dailySeeds)};

const List<int> randomSolvableSeeds4Suit = ${renderList(randomSeeds)};
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
// Generated by: tool/generate_solvable_seeds_4suit.dart

import 'solvable_solution_step.dart';

const Map<int, List<SolutionStepDto>> solutionFirst30_4Suit = ${renderMap(prefixBySeed)};

const Map<int, List<SolutionStepDto>> solutionFull_4Suit = ${renderMap(fullBySeed)};
''';
}

class _GeneratorConfig {
  const _GeneratorConfig({
    required this.dailyCount,
    required this.randomCount,
    required this.outPath,
    required this.solutionsOutPath,
    required this.seedStart,
    required this.seedEnd,
    required this.maxAttempts,
    required this.perSeedMs,
    required this.nodeCap,
    required this.maxDepth,
    required this.randomWalkTrials,
    required this.randomWalkSteps,
    required this.solutionPrefixSteps,
    required this.emitFullSolution,
    required this.progressEvery,
  });

  final int dailyCount;
  final int randomCount;
  final String outPath;
  final String solutionsOutPath;
  final int seedStart;
  final int? seedEnd;
  final int? maxAttempts;
  final int perSeedMs;
  final int nodeCap;
  final int maxDepth;
  final int randomWalkTrials;
  final int randomWalkSteps;
  final int solutionPrefixSteps;
  final bool emitFullSolution;
  final int progressEvery;

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

    int? nullableIntArg(String name) {
      final prefix = '--$name=';
      final raw = args.cast<String?>().firstWhere(
        (arg) => arg != null && arg.startsWith(prefix),
        orElse: () => null,
      );
      if (raw == null) {
        return null;
      }
      return int.tryParse(raw.substring(prefix.length));
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
      outPath: stringArg('out', 'tool/tmp_generated_seeds_4suit.dart'),
      solutionsOutPath: stringArg(
        'solutions-out',
        'tool/tmp_generated_solutions_4suit.dart',
      ),
      seedStart: intArg('seed-start', 1),
      seedEnd: nullableIntArg('seed-end'),
      maxAttempts: nullableIntArg('max-attempts'),
      perSeedMs: intArg('per-seed-ms', 2000),
      nodeCap: intArg('node-cap', 120000),
      maxDepth: intArg('max-depth', 280),
      randomWalkTrials: intArg('random-walk-trials', 120),
      randomWalkSteps: intArg('random-walk-steps', 700),
      solutionPrefixSteps: intArg('solution-prefix-steps', 30),
      emitFullSolution: boolArg('emit-full-solution', false),
      progressEvery: max(1, intArg('progress-every', 1)),
    );
  }

  static String usage() => '''Usage:
  dart run tool/generate_solvable_seeds_4suit.dart [options]

Options:
  --daily-count=<int>            Daily seeds to find (default: 10)
  --random-count=<int>           Random seeds to find (default: 20)
  --out=<path>                   Seeds output (default: tool/tmp_generated_seeds_4suit.dart)
  --solutions-out=<path>         Solutions output (default: tool/tmp_generated_solutions_4suit.dart)
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
  --progress-every=<int>         Print progress every N attempts (default: 1)
''';
}

enum _SolveResult { solvable, unsolved, timeout, nodeCap, depthCap }

class _SolveOutcome {
  const _SolveOutcome({
    required this.result,
    required this.solutionSteps,
    required this.elapsedMs,
    required this.nodesUsed,
    required this.depthReached,
  });

  final _SolveResult result;
  final List<SolutionStepDto> solutionSteps;
  final int elapsedMs;
  final int nodesUsed;
  final int depthReached;
}

class _Transition {
  const _Transition({required this.state, required this.step});

  final GameState state;
  final SolutionStepDto step;
}

class _FourSuitSeedSolver {
  _FourSuitSeedSolver({
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
        elapsedMs: watch.elapsedMilliseconds,
        nodesUsed: 0,
        depthReached: greedy.length,
      );
    }

    final randomWalk = _tryRandomWalkWithPath(initial, seed, watch);
    if (randomWalk != null) {
      return _SolveOutcome(
        result: _SolveResult.solvable,
        solutionSteps: randomWalk,
        elapsedMs: watch.elapsedMilliseconds,
        nodesUsed: 0,
        depthReached: randomWalk.length,
      );
    }

    if (watch.elapsedMilliseconds >= perSeedMs) {
      return _SolveOutcome(
        result: _SolveResult.timeout,
        solutionSteps: const <SolutionStepDto>[],
        elapsedMs: watch.elapsedMilliseconds,
        nodesUsed: 0,
        depthReached: 0,
      );
    }

    return _searchWithPath(initial, watch);
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

  _SolveOutcome _searchWithPath(GameState start, Stopwatch watch) {
    final nodes = <_Node>[
      _Node(state: start, depth: 0, parentIndex: null, stepFromParent: null),
    ];
    final stack = <int>[0];
    final bestSeen = <String, int>{};

    var explored = 0;
    var maxDepthReached = 0;
    var hitDepthCap = false;
    while (stack.isNotEmpty) {
      if (watch.elapsedMilliseconds >= perSeedMs) {
        return _SolveOutcome(
          result: _SolveResult.timeout,
          solutionSteps: const <SolutionStepDto>[],
          elapsedMs: watch.elapsedMilliseconds,
          nodesUsed: explored,
          depthReached: maxDepthReached,
        );
      }
      if (explored >= nodeCap) {
        return _SolveOutcome(
          result: _SolveResult.nodeCap,
          solutionSteps: const <SolutionStepDto>[],
          elapsedMs: watch.elapsedMilliseconds,
          nodesUsed: explored,
          depthReached: maxDepthReached,
        );
      }

      final nodeIndex = stack.removeLast();
      final node = nodes[nodeIndex];
      explored++;
      maxDepthReached = max(maxDepthReached, node.depth);

      if (_isWon(node.state)) {
        return _SolveOutcome(
          result: _SolveResult.solvable,
          solutionSteps: _reconstructSteps(nodes, nodeIndex),
          elapsedMs: watch.elapsedMilliseconds,
          nodesUsed: explored,
          depthReached: maxDepthReached,
        );
      }
      if (node.depth >= maxDepth) {
        hitDepthCap = true;
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

    return _SolveOutcome(
      result: hitDepthCap ? _SolveResult.depthCap : _SolveResult.unsolved,
      solutionSteps: const <SolutionStepDto>[],
      elapsedMs: watch.elapsedMilliseconds,
      nodesUsed: explored,
      depthReached: maxDepthReached,
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
      difficulty: Difficulty.fourSuit,
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
