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
    searchMode: config.searchMode,
    beamWidth: config.beamWidth,
    dealPolicy: config.dealPolicy,
    instrumentationEveryNodes: config.instrumentationEveryNodes,
    instrumentationEveryMs: config.instrumentationEveryMs,
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
  final stopReasonCounts = <String, int>{};

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
    var replayRejected = false;

    if (result == _SolveResult.solvable) {
      final verifiedProof = List<SolutionStepDto>.unmodifiable(
        outcome.solutionSteps,
      );
      final replayError = _replayValidationError(
        seed: currentSeed,
        difficulty: Difficulty.oneSuit,
        steps: verifiedProof,
      );
      if (replayError != null) {
        replayRejected = true;
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

    final stopReason = _stopReasonLabel(
      outcome: outcome,
      foundProof: foundProofLength != null,
      replayRejected: replayRejected,
    );
    stopReasonCounts[stopReason] = (stopReasonCounts[stopReason] ?? 0) + 1;

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
      stopReasonCounts: stopReasonCounts,
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
    var replayRejected = false;

    if (result == _SolveResult.solvable) {
      final verifiedProof = List<SolutionStepDto>.unmodifiable(
        outcome.solutionSteps,
      );
      final replayError = _replayValidationError(
        seed: currentSeed,
        difficulty: Difficulty.oneSuit,
        steps: verifiedProof,
      );
      if (replayError != null) {
        replayRejected = true;
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

    final stopReason = _stopReasonLabel(
      outcome: outcome,
      foundProof: foundProofLength != null,
      replayRejected: replayRejected,
    );
    stopReasonCounts[stopReason] = (stopReasonCounts[stopReason] ?? 0) + 1;

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
      stopReasonCounts: stopReasonCounts,
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
      'FOUND (seed=$seed, proofLength=$foundProofLength, elapsedMs=${outcome.elapsedMs}, stopReason=win)',
    );
    return;
  }

  switch (outcome.result) {
    case _SolveResult.timeout:
      stdout.writeln(
        'TIMEOUT (seed=$seed, elapsedMs=${outcome.elapsedMs}, stopReason=timeout)',
      );
      return;
    case _SolveResult.nodeCap:
      stdout.writeln(
        'NODE_CAP (seed=$seed, nodesUsed=${outcome.nodesUsed}, stopReason=nodeCap)',
      );
      return;
    case _SolveResult.depthCap:
      stdout.writeln(
        'DEPTH_CAP (seed=$seed, depthReached=${outcome.depthReached}, stopReason=depthCap)',
      );
      return;
    case _SolveResult.unsolved:
      stdout.writeln('UNSOLVED (seed=$seed, stopReason=unsolved)');
      return;
    case _SolveResult.solvable:
      stdout.writeln('UNSOLVED (seed=$seed, stopReason=unsolved)');
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
  required Map<String, int> stopReasonCounts,
}) {
  if (progressEvery > 0 && attempts % progressEvery == 0) {
    stdout.writeln(
      'Progress attempts=$attempts, dailyFound=$dailyFound, randomFound=$randomFound, currentSeed=$currentSeed',
    );
  }
  if (attempts % 50 == 0) {
    final topStopReasons = stopReasonCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topSummary = topStopReasons
        .take(3)
        .map((entry) => '${entry.key}=${entry.value}')
        .join(', ');
    stdout.writeln(
      'Heartbeat attempts=$attempts, dailyFound=$dailyFound, '
      'randomFound=$randomFound, timedOut=$timedOut, currentSeed=$currentSeed, '
      'topStopReasons=[$topSummary]',
    );
  }
}

String _stopReasonLabel({
  required _SolveOutcome outcome,
  required bool foundProof,
  required bool replayRejected,
}) {
  if (foundProof) {
    return 'found';
  }
  if (replayRejected) {
    return 'replayReject';
  }
  return switch (outcome.result) {
    _SolveResult.timeout => 'timeout',
    _SolveResult.nodeCap => 'nodeCap',
    _SolveResult.depthCap => 'depthCap',
    _SolveResult.unsolved => 'unsolved',
    _SolveResult.solvable => 'unsolved',
  };
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
    required this.searchMode,
    required this.beamWidth,
    required this.dealPolicy,
    required this.instrumentationEveryNodes,
    required this.instrumentationEveryMs,
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
  final _SearchMode searchMode;
  final int beamWidth;
  final _DealPolicy dealPolicy;
  final int instrumentationEveryNodes;
  final int instrumentationEveryMs;

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

    _SearchMode searchModeArg() {
      final raw = stringArg('search', 'dfs').toLowerCase();
      return raw == 'beam' ? _SearchMode.beam : _SearchMode.dfs;
    }

    _DealPolicy dealPolicyArg() {
      final raw = stringArg('deal-policy', 'smart').toLowerCase();
      return raw == 'always' ? _DealPolicy.always : _DealPolicy.smart;
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
      searchMode: searchModeArg(),
      beamWidth: max(20, intArg('beam-width', 200)),
      dealPolicy: dealPolicyArg(),
      instrumentationEveryNodes: max(
        0,
        intArg('instrumentation-every-nodes', 5000),
      ),
      instrumentationEveryMs: max(0, intArg('instrumentation-every-ms', 2000)),
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
  --progress-every=<int>         Print progress every N attempts (default: 1)
  --search=dfs|beam              Search mode (default: dfs)
  --beam-width=<int>             Beam width for --search=beam (default: 200)
  --deal-policy=smart|always     Deal heuristic policy (default: smart)
  --instrumentation-every-nodes=<int>  Search metrics print interval by nodes (default: 5000)
  --instrumentation-every-ms=<int>     Search metrics print interval by ms (default: 2000)
''';
}

enum _SolveResult { solvable, unsolved, timeout, nodeCap, depthCap }

enum _SearchMode { dfs, beam }

enum _DealPolicy { smart, always }

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

class _OneSuitSeedSolver {
  _OneSuitSeedSolver({
    required this.perSeedMs,
    required this.nodeCap,
    required this.maxDepth,
    required this.randomWalkTrials,
    required this.randomWalkSteps,
    required this.searchMode,
    required this.beamWidth,
    required this.dealPolicy,
    required this.instrumentationEveryNodes,
    required this.instrumentationEveryMs,
  });

  final int perSeedMs;
  final int nodeCap;
  final int maxDepth;
  final int randomWalkTrials;
  final int randomWalkSteps;
  final _SearchMode searchMode;
  final int beamWidth;
  final _DealPolicy dealPolicy;
  final int instrumentationEveryNodes;
  final int instrumentationEveryMs;

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

    return searchMode == _SearchMode.beam
        ? _searchWithBeam(initial, watch)
        : _searchWithPath(initial, watch);
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
    final bestSeen = <int, _SeenState>{};

    var explored = 0;
    var maxDepthReached = 0;
    var hitDepthCap = false;
    var bestScoreSoFar = _stateScore(start);
    var lowestFaceDownSeen = _faceDownCount(start);
    var lastLogMs = 0;
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
      final score = _stateScore(node.state);
      bestScoreSoFar = max(bestScoreSoFar, score);
      lowestFaceDownSeen = min(lowestFaceDownSeen, _faceDownCount(node.state));

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

      final key = _stateHash(node.state);
      final prev = bestSeen[key];
      if (prev != null && prev.depth <= node.depth && prev.score >= score) {
        continue;
      }
      bestSeen[key] = _SeenState(depth: node.depth, score: score);

      final next = _expandAllWithSteps(
        node.state,
        lastMove: node.stepFromParent,
      );
      next.sort(
        (a, b) => _transitionScore(
          node.state,
          b,
          node.stepFromParent,
        ).compareTo(_transitionScore(node.state, a, node.stepFromParent)),
      );
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

      final nowMs = watch.elapsedMilliseconds;
      final shouldLogByNodes =
          instrumentationEveryNodes > 0 &&
          explored % instrumentationEveryNodes == 0;
      final shouldLogByMs =
          instrumentationEveryMs > 0 &&
          nowMs - lastLogMs >= instrumentationEveryMs;
      if (shouldLogByNodes || shouldLogByMs) {
        final nps = nowMs > 0 ? (explored * 1000 ~/ nowMs) : 0;
        stdout.writeln(
          'SEARCH_METRICS mode=dfs nodesExpanded=$explored nodesPerSec=$nps '
          'bestScoreSoFar=$bestScoreSoFar lowestFaceDownSeen=$lowestFaceDownSeen '
          'deepestDepthReached=$maxDepthReached',
        );
        lastLogMs = nowMs;
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

  _SolveOutcome _searchWithBeam(GameState start, Stopwatch watch) {
    final nodes = <_Node>[
      _Node(state: start, depth: 0, parentIndex: null, stepFromParent: null),
    ];
    var frontier = <int>[0];
    final bestSeen = <int, _SeenState>{};

    var explored = 0;
    var maxDepthReached = 0;
    var hitDepthCap = false;
    var bestScoreSoFar = _stateScore(start);
    var lowestFaceDownSeen = _faceDownCount(start);
    var lastLogMs = 0;

    while (frontier.isNotEmpty) {
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

      final nextFrontier = <int>[];
      for (final nodeIndex in frontier) {
        final node = nodes[nodeIndex];
        explored++;
        maxDepthReached = max(maxDepthReached, node.depth);
        final score = _stateScore(node.state);
        bestScoreSoFar = max(bestScoreSoFar, score);
        lowestFaceDownSeen = min(
          lowestFaceDownSeen,
          _faceDownCount(node.state),
        );

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

        final key = _stateHash(node.state);
        final prev = bestSeen[key];
        if (prev != null && prev.depth <= node.depth && prev.score >= score) {
          continue;
        }
        bestSeen[key] = _SeenState(depth: node.depth, score: score);

        final next = _expandAllWithSteps(
          node.state,
          lastMove: node.stepFromParent,
        );
        next.sort(
          (a, b) => _transitionScore(
            node.state,
            b,
            node.stepFromParent,
          ).compareTo(_transitionScore(node.state, a, node.stepFromParent)),
        );
        for (final transition in next) {
          nodes.add(
            _Node(
              state: transition.state,
              depth: node.depth + 1,
              parentIndex: nodeIndex,
              stepFromParent: transition.step,
            ),
          );
          nextFrontier.add(nodes.length - 1);
        }

        if (explored >= nodeCap) {
          break;
        }
      }

      nextFrontier.sort(
        (a, b) =>
            _stateScore(nodes[b].state).compareTo(_stateScore(nodes[a].state)),
      );
      if (nextFrontier.length > beamWidth) {
        frontier = nextFrontier.sublist(0, beamWidth);
      } else {
        frontier = nextFrontier;
      }

      final nowMs = watch.elapsedMilliseconds;
      final shouldLogByNodes =
          instrumentationEveryNodes > 0 &&
          explored % instrumentationEveryNodes == 0;
      final shouldLogByMs =
          instrumentationEveryMs > 0 &&
          nowMs - lastLogMs >= instrumentationEveryMs;
      if (shouldLogByNodes || shouldLogByMs) {
        final nps = nowMs > 0 ? (explored * 1000 ~/ nowMs) : 0;
        stdout.writeln(
          'SEARCH_METRICS mode=beam nodesExpanded=$explored nodesPerSec=$nps '
          'bestScoreSoFar=$bestScoreSoFar lowestFaceDownSeen=$lowestFaceDownSeen '
          'deepestDepthReached=$maxDepthReached',
        );
        lastLogMs = nowMs;
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
      difficulty: Difficulty.oneSuit,
      startedAt: DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  List<_Transition> _expandAllWithSteps(
    GameState state, {
    SolutionStepDto? lastMove,
  }) {
    final moveResults = _expandMovesWithSteps(state, lastMove: lastMove);
    final hasProgressMove = moveResults.any(
      (transition) => _isProgressTransition(state, transition.state),
    );

    final results = <_Transition>[...moveResults];
    final allowDeal = dealPolicy == _DealPolicy.always || !hasProgressMove;
    if (allowDeal && _canDealFromStockClassic(state)) {
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

  List<_Transition> _expandMovesWithSteps(
    GameState state, {
    SolutionStepDto? lastMove,
  }) {
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

          final moveStep = SolutionStepDto.move(
            fromColumn: fromColumn,
            toColumn: toColumn,
            startIndex: startIndex,
          );
          final immediatelyBacktracks = _isImmediateBacktrack(
            lastMove,
            moveStep,
          );

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

          final transitionStep = SolutionStepDto.move(
            fromColumn: fromColumn,
            toColumn: toColumn,
            startIndex: startIndex,
            movedLength: move.movedLength,
          );
          final progressMove = _isProgressTransition(state, move.state);
          if (immediatelyBacktracks && !progressMove) {
            continue;
          }

          results.add(_Transition(state: move.state, step: transitionStep));
        }
      }
    }

    results.sort(
      (a, b) => _transitionScore(
        state,
        b,
        lastMove,
      ).compareTo(_transitionScore(state, a, lastMove)),
    );
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
    final faceDown = _faceDownCount(state);
    final runCards = _sameSuitRunCards(state);
    final breaks = _sameSuitBreaks(state);
    final emptyColumns = state.tableau.columns.where((c) => c.isEmpty).length;
    return (state.foundations.completedRuns * 2000000) +
        (runCards * 35) +
        (emptyColumns * 250) -
        (faceDown * 600) -
        (breaks * 80) -
        (state.stock.cards.length * 6);
  }

  int _stateHash(GameState state) {
    var hash = 1469598103934665603;
    void mix(int value) {
      hash ^= value & 0xffffffff;
      hash = (hash * 1099511628211) & 0x7fffffffffffffff;
    }

    mix(state.foundations.completedRuns);
    mix(state.stock.cards.length);
    for (final card in state.stock.cards) {
      mix(card.id);
      mix(card.faceUp ? 1 : 0);
    }
    for (final column in state.tableau.columns) {
      mix(column.length);
      for (final card in column) {
        mix(card.id);
        mix(card.faceUp ? 1 : 0);
      }
    }

    return hash;
  }

  int _faceDownCount(GameState state) {
    return state.tableau.columns
        .expand((column) => column)
        .where((card) => !card.faceUp)
        .length;
  }

  int _sameSuitRunCards(GameState state) {
    var total = 0;
    for (final column in state.tableau.columns) {
      for (var i = 0; i + 1 < column.length; i++) {
        final a = column[i];
        final b = column[i + 1];
        if (!a.faceUp || !b.faceUp) {
          continue;
        }
        if (a.suit == b.suit && a.rank.index == b.rank.index + 1) {
          total++;
        }
      }
    }
    return total;
  }

  int _sameSuitBreaks(GameState state) {
    var breaks = 0;
    for (final column in state.tableau.columns) {
      for (var i = 0; i + 1 < column.length; i++) {
        final a = column[i];
        final b = column[i + 1];
        if (!a.faceUp || !b.faceUp) {
          continue;
        }
        final sameSuitDescending =
            a.suit == b.suit && a.rank.index == b.rank.index + 1;
        if (!sameSuitDescending) {
          breaks++;
        }
      }
    }
    return breaks;
  }

  bool _isImmediateBacktrack(SolutionStepDto? last, SolutionStepDto next) {
    if (last == null || !last.isMove || !next.isMove) {
      return false;
    }
    return last.fromColumn == next.toColumn && last.toColumn == next.fromColumn;
  }

  bool _isProgressTransition(GameState before, GameState after) {
    return after.foundations.completedRuns > before.foundations.completedRuns ||
        _faceDownCount(after) < _faceDownCount(before) ||
        _sameSuitRunCards(after) > _sameSuitRunCards(before);
  }

  int _transitionScore(
    GameState before,
    _Transition transition,
    SolutionStepDto? lastMove,
  ) {
    final after = transition.state;
    var score = _stateScore(after) - _stateScore(before);
    if (_isProgressTransition(before, after)) {
      score += 12000;
    }
    if (_isImmediateBacktrack(lastMove, transition.step)) {
      score -= 5000;
    }
    return score;
  }
}

class _SeenState {
  const _SeenState({required this.depth, required this.score});

  final int depth;
  final int score;
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
