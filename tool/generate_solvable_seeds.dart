import 'dart:io';
import 'dart:math';

import 'package:haylau_spider_solitaire/game/actions/auto_complete_run_action.dart';
import 'package:haylau_spider_solitaire/game/actions/deal_from_stock_action.dart';
import 'package:haylau_spider_solitaire/game/actions/move_stack_action.dart';
import 'package:haylau_spider_solitaire/game/engine/move_validator.dart';
import 'package:haylau_spider_solitaire/game/model/card.dart';
import 'package:haylau_spider_solitaire/game/model/deal_source.dart';
import 'package:haylau_spider_solitaire/game/model/difficulty.dart';
import 'package:haylau_spider_solitaire/game/model/game_state.dart';
import 'package:haylau_spider_solitaire/game/model/piles.dart';

void main(List<String> args) {
  if (args.contains('--help') || args.contains('-h')) {
    stdout.write(_usage());
    return;
  }

  final config = _GeneratorConfig.fromArgs(args);
  final selected = config.selectedDifficulties;
  final budgets = config.resolveBudgetsInteractively();

  final allDaily = <Difficulty, List<int>>{
    Difficulty.oneSuit: <int>[],
    Difficulty.twoSuit: <int>[],
    Difficulty.fourSuit: <int>[],
  };
  final allRandom = <Difficulty, List<int>>{
    Difficulty.oneSuit: <int>[],
    Difficulty.twoSuit: <int>[],
    Difficulty.fourSuit: <int>[],
  };

  final allStats = <Difficulty, _DifficultyRunStats>{};

  for (final difficulty in selected) {
    final solver = _DifficultySeedSolver(
      difficulty: difficulty,
      perSeedMs: config.perSeedMs,
      nodeCap: config.nodeCap,
      maxDepth: config.maxDepth,
      randomWalkTrials: config.randomWalkTrials,
      randomWalkSteps: config.randomWalkSteps,
    );

    final run = _runDifficulty(
      difficulty: difficulty,
      solver: solver,
      dailyTarget: config.dailyCountFor(difficulty),
      randomTarget: config.randomCountFor(difficulty),
      seedStart: config.seedStartFor(difficulty),
      budgetMs: budgets[difficulty] ?? 0,
    );

    allDaily[difficulty] = run.dailySeeds;
    allRandom[difficulty] = run.randomSeeds;
    allStats[difficulty] = run.stats;
  }

  final output = _renderOutput(
    daily1: allDaily[Difficulty.oneSuit]!,
    random1: allRandom[Difficulty.oneSuit]!,
    daily2: allDaily[Difficulty.twoSuit]!,
    random2: allRandom[Difficulty.twoSuit]!,
    daily4: allDaily[Difficulty.fourSuit]!,
    random4: allRandom[Difficulty.fourSuit]!,
  );

  final outFile = File(config.outPath);
  outFile.parent.createSync(recursive: true);
  outFile.writeAsStringSync(output);

  stdout.writeln('');
  stdout.writeln('Wrote generated pools to ${config.outPath}');

  for (final difficulty in selected) {
    final stats = allStats[difficulty]!;
    stdout.writeln(
      '${_label(difficulty)}: daily ${stats.dailyFound}/${stats.dailyTarget}, '
      'random ${stats.randomFound}/${stats.randomTarget}, attempts=${stats.attempts}, '
      'solved=${stats.solved}, unsolved=${stats.unsolved}, timeouts=${stats.timedOut}',
    );
  }
}

class _DifficultyRunResult {
  const _DifficultyRunResult({
    required this.dailySeeds,
    required this.randomSeeds,
    required this.stats,
  });

  final List<int> dailySeeds;
  final List<int> randomSeeds;
  final _DifficultyRunStats stats;
}

class _DifficultyRunStats {
  const _DifficultyRunStats({
    required this.dailyFound,
    required this.dailyTarget,
    required this.randomFound,
    required this.randomTarget,
    required this.attempts,
    required this.solved,
    required this.unsolved,
    required this.timedOut,
  });

  final int dailyFound;
  final int dailyTarget;
  final int randomFound;
  final int randomTarget;
  final int attempts;
  final int solved;
  final int unsolved;
  final int timedOut;
}

_DifficultyRunResult _runDifficulty({
  required Difficulty difficulty,
  required _DifficultySeedSolver solver,
  required int dailyTarget,
  required int randomTarget,
  required int seedStart,
  required int budgetMs,
}) {
  final daily = <int>[];
  final random = <int>[];
  final used = <int>{};

  var attempts = 0;
  var solved = 0;
  var unsolved = 0;
  var timedOut = 0;
  var seed = seedStart;

  final watch = Stopwatch()..start();

  bool budgetRemaining() => watch.elapsedMilliseconds < budgetMs;

  while (daily.length < dailyTarget && budgetRemaining()) {
    attempts++;
    final result = solver.isSeedSolvable(seed).result;
    if (result == _SolveResult.solvable && used.add(seed)) {
      daily.add(seed);
      solved++;
      stdout.writeln(
        '${_label(difficulty)} daily ${daily.length}/$dailyTarget <- $seed',
      );
    } else if (result == _SolveResult.timeout) {
      timedOut++;
    } else {
      unsolved++;
    }
    if (attempts % 25 == 0) {
      stdout.writeln(
        '${_label(difficulty)} seed $seed -> ${result.name} '
        '(daily=${daily.length}/$dailyTarget random=${random.length}/$randomTarget)',
      );
    }
    seed++;
  }

  while (random.length < randomTarget && budgetRemaining()) {
    attempts++;
    final result = solver.isSeedSolvable(seed).result;
    if (result == _SolveResult.solvable && used.add(seed)) {
      random.add(seed);
      solved++;
      stdout.writeln(
        '${_label(difficulty)} random ${random.length}/$randomTarget <- $seed',
      );
    } else if (result == _SolveResult.timeout) {
      timedOut++;
    } else {
      unsolved++;
    }
    if (attempts % 25 == 0) {
      stdout.writeln(
        '${_label(difficulty)} seed $seed -> ${result.name} '
        '(daily=${daily.length}/$dailyTarget random=${random.length}/$randomTarget)',
      );
    }
    seed++;
  }

  if (!budgetRemaining()) {
    stdout.writeln(
      '${_label(difficulty)} budget exhausted after ${watch.elapsed.inSeconds}s.',
    );
  }

  return _DifficultyRunResult(
    dailySeeds: daily,
    randomSeeds: random,
    stats: _DifficultyRunStats(
      dailyFound: daily.length,
      dailyTarget: dailyTarget,
      randomFound: random.length,
      randomTarget: randomTarget,
      attempts: attempts,
      solved: solved,
      unsolved: unsolved,
      timedOut: timedOut,
    ),
  );
}

String _renderOutput({
  required List<int> daily1,
  required List<int> random1,
  required List<int> daily2,
  required List<int> random2,
  required List<int> daily4,
  required List<int> random4,
}) {
  String renderList(List<int> values) {
    final lines = values.map((value) => '  $value,').join('\n');
    return '<int>[\n$lines\n]';
  }

  return '''// GENERATED CODE - DO NOT EDIT BY HAND.
// Generated by: tool/generate_solvable_seeds.dart

const List<int> dailySolvableSeeds1Suit = ${renderList(daily1)};
const List<int> randomSolvableSeeds1Suit = ${renderList(random1)};

const List<int> dailySolvableSeeds2Suit = ${renderList(daily2)};
const List<int> randomSolvableSeeds2Suit = ${renderList(random2)};

const List<int> dailySolvableSeeds4Suit = ${renderList(daily4)};
const List<int> randomSolvableSeeds4Suit = ${renderList(random4)};
''';
}

class _GeneratorConfig {
  const _GeneratorConfig({
    required this.difficultyArg,
    required this.dailyCount1,
    required this.randomCount1,
    required this.dailyCount2,
    required this.randomCount2,
    required this.dailyCount4,
    required this.randomCount4,
    required this.seedStart1,
    required this.seedStart2,
    required this.seedStart4,
    required this.budget1Arg,
    required this.budget2Arg,
    required this.budget4Arg,
    required this.outPath,
    required this.perSeedMs,
    required this.nodeCap,
    required this.maxDepth,
    required this.randomWalkTrials,
    required this.randomWalkSteps,
  });

  final String difficultyArg;
  final int dailyCount1;
  final int randomCount1;
  final int dailyCount2;
  final int randomCount2;
  final int dailyCount4;
  final int randomCount4;
  final int seedStart1;
  final int seedStart2;
  final int seedStart4;
  final String? budget1Arg;
  final String? budget2Arg;
  final String? budget4Arg;
  final String outPath;
  final int perSeedMs;
  final int nodeCap;
  final int maxDepth;
  final int randomWalkTrials;
  final int randomWalkSteps;

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

    String? optionalStringArg(String name) {
      final prefix = '--$name=';
      final raw = args.cast<String?>().firstWhere(
        (arg) => arg != null && arg.startsWith(prefix),
        orElse: () => null,
      );
      if (raw == null) {
        return null;
      }
      return raw.substring(prefix.length);
    }

    String stringArg(String name, String fallback) {
      final value = optionalStringArg(name);
      return value ?? fallback;
    }

    return _GeneratorConfig(
      difficultyArg: stringArg('difficulty', 'all'),
      dailyCount1: intArg('daily-count-1', 10),
      randomCount1: intArg('random-count-1', 20),
      dailyCount2: intArg('daily-count-2', 0),
      randomCount2: intArg('random-count-2', 0),
      dailyCount4: intArg('daily-count-4', 0),
      randomCount4: intArg('random-count-4', 0),
      seedStart1: intArg('seed-start-1', 1),
      seedStart2: intArg('seed-start-2', 1),
      seedStart4: intArg('seed-start-4', 1),
      budget1Arg: optionalStringArg('budget-1'),
      budget2Arg: optionalStringArg('budget-2'),
      budget4Arg: optionalStringArg('budget-4'),
      outPath: stringArg('out', 'tool/tmp_generated_seeds.dart'),
      perSeedMs: intArg('per-seed-ms', 2000),
      nodeCap: intArg('node-cap', 120000),
      maxDepth: intArg('max-depth', 280),
      randomWalkTrials: intArg('random-walk-trials', 120),
      randomWalkSteps: intArg('random-walk-steps', 700),
    );
  }

  List<Difficulty> get selectedDifficulties {
    return switch (difficultyArg) {
      'one' => <Difficulty>[Difficulty.oneSuit],
      'two' => <Difficulty>[Difficulty.twoSuit],
      'four' => <Difficulty>[Difficulty.fourSuit],
      _ => <Difficulty>[
        Difficulty.oneSuit,
        Difficulty.twoSuit,
        Difficulty.fourSuit,
      ],
    };
  }

  int dailyCountFor(Difficulty difficulty) => switch (difficulty) {
    Difficulty.oneSuit => dailyCount1,
    Difficulty.twoSuit => dailyCount2,
    Difficulty.fourSuit => dailyCount4,
  };

  int randomCountFor(Difficulty difficulty) => switch (difficulty) {
    Difficulty.oneSuit => randomCount1,
    Difficulty.twoSuit => randomCount2,
    Difficulty.fourSuit => randomCount4,
  };

  int seedStartFor(Difficulty difficulty) => switch (difficulty) {
    Difficulty.oneSuit => seedStart1,
    Difficulty.twoSuit => seedStart2,
    Difficulty.fourSuit => seedStart4,
  };

  Map<Difficulty, int> resolveBudgetsInteractively() {
    final result = <Difficulty, int>{};

    int parseBudget(String raw, int fallbackMinutes) {
      final trimmed = raw.trim().toLowerCase();
      if (trimmed.isEmpty) {
        return fallbackMinutes * 60 * 1000;
      }
      if (trimmed.endsWith('ms')) {
        return int.tryParse(trimmed.substring(0, trimmed.length - 2)) ??
            (fallbackMinutes * 60 * 1000);
      }
      if (trimmed.endsWith('s')) {
        final seconds = int.tryParse(trimmed.substring(0, trimmed.length - 1));
        return (seconds ?? fallbackMinutes * 60) * 1000;
      }
      if (trimmed.endsWith('m')) {
        final minutes = int.tryParse(trimmed.substring(0, trimmed.length - 1));
        return (minutes ?? fallbackMinutes) * 60 * 1000;
      }
      final minutes = int.tryParse(trimmed);
      return (minutes ?? fallbackMinutes) * 60 * 1000;
    }

    int resolveBudgetFor(
      Difficulty difficulty,
      String? arg,
      int fallbackMinutes,
    ) {
      if (arg != null) {
        return parseBudget(arg, fallbackMinutes);
      }
      if (!stdin.hasTerminal) {
        return fallbackMinutes * 60 * 1000;
      }

      stdout.write(
        'Enter budget for ${_label(difficulty)} in minutes '
        '(default: $fallbackMinutes): ',
      );
      final input = stdin.readLineSync();
      if (input == null || input.trim().isEmpty) {
        return fallbackMinutes * 60 * 1000;
      }
      final minutes = int.tryParse(input.trim()) ?? fallbackMinutes;
      return minutes * 60 * 1000;
    }

    for (final difficulty in selectedDifficulties) {
      final minutes = switch (difficulty) {
        Difficulty.oneSuit => 10,
        Difficulty.twoSuit => 10,
        Difficulty.fourSuit => 30,
      };
      final arg = switch (difficulty) {
        Difficulty.oneSuit => budget1Arg,
        Difficulty.twoSuit => budget2Arg,
        Difficulty.fourSuit => budget4Arg,
      };
      result[difficulty] = resolveBudgetFor(difficulty, arg, minutes);
    }

    return result;
  }
}

enum _SolveResult { solvable, unsolved, timeout }

enum _TimeoutCause { nodeCapHit, timeBudgetHit }

class _SolveOutcome {
  const _SolveOutcome({
    required this.result,
    required this.elapsedMs,
    this.dfsNodesExplored = 0,
    this.randomWalkTrialsAttempted = 0,
  });

  final _SolveResult result;
  final int elapsedMs;
  final int dfsNodesExplored;
  final int randomWalkTrialsAttempted;
}

class _RandomWalkOutcome {
  const _RandomWalkOutcome({
    required this.solved,
    required this.trialsAttempted,
    required this.bestState,
    required this.bestScore,
  });

  final bool solved;
  final int trialsAttempted;
  final GameState bestState;
  final int bestScore;
}

class _DfsOutcome {
  const _DfsOutcome({
    required this.result,
    required this.nodesExplored,
    this.timeoutCause,
  });

  final _SolveResult result;
  final int nodesExplored;
  final _TimeoutCause? timeoutCause;
}

class _DifficultySeedSolver {
  _DifficultySeedSolver({
    required this.difficulty,
    required this.perSeedMs,
    required this.nodeCap,
    required this.maxDepth,
    required this.randomWalkTrials,
    required this.randomWalkSteps,
  });

  static const int _randomWalkBudgetPercent = 40;
  static const int _minDfsReserveMs = 100;

  final Difficulty difficulty;
  final int perSeedMs;
  final int nodeCap;
  final int maxDepth;
  final int randomWalkTrials;
  final int randomWalkSteps;

  final MoveValidator _validator = const MoveValidator();

  _SolveOutcome isSeedSolvable(int seed) {
    final watch = Stopwatch()..start();
    final initial = _initialStateForSeed(seed);

    if (_tryGreedy(initial, maxSteps: 500)) {
      return _SolveOutcome(
        result: _SolveResult.solvable,
        elapsedMs: watch.elapsedMilliseconds,
      );
    }

    final rwBudgetCap = max(0, perSeedMs - _minDfsReserveMs);
    final rwBudgetMs = min(
      (perSeedMs * _randomWalkBudgetPercent) ~/ 100,
      rwBudgetCap,
    );

    final randomWalk = _tryRandomWalk(
      initial,
      seed: seed,
      overallWatch: watch,
      timeBudgetMs: rwBudgetMs,
    );

    if (randomWalk.solved) {
      return _SolveOutcome(
        result: _SolveResult.solvable,
        elapsedMs: watch.elapsedMilliseconds,
        randomWalkTrialsAttempted: randomWalk.trialsAttempted,
      );
    }

    final remainingMs = perSeedMs - watch.elapsedMilliseconds;
    if (remainingMs <= 0) {
      return _SolveOutcome(
        result: _SolveResult.unsolved,
        elapsedMs: watch.elapsedMilliseconds,
        randomWalkTrialsAttempted: randomWalk.trialsAttempted,
      );
    }

    final startFromRw =
        _stateScore(randomWalk.bestState) > _stateScore(initial);
    final dfsStart = startFromRw ? randomWalk.bestState : initial;

    final dfs = _searchWithCap(<GameState>[
      dfsStart,
    ], timeBudgetMs: remainingMs);

    return _SolveOutcome(
      result: dfs.result,
      elapsedMs: watch.elapsedMilliseconds,
      dfsNodesExplored: dfs.nodesExplored,
      randomWalkTrialsAttempted: randomWalk.trialsAttempted,
    );
  }

  GameState _initialStateForSeed(int seed) {
    final deck = _buildDeckForDifficulty();
    final shuffled = _shuffleDeterministic(deck, seed);

    final columns = List<List<PlayingCard>>.generate(
      10,
      (_) => <PlayingCard>[],
    );
    var cursor = 0;

    for (var col = 0; col < 10; col++) {
      final count = col < 4 ? 6 : 5;
      for (var i = 0; i < count; i++) {
        final isTop = i == count - 1;
        columns[col].add(shuffled[cursor++].copyWith(faceUp: isTop));
      }
    }

    final stock = shuffled
        .sublist(cursor)
        .map((card) => card.copyWith(faceUp: false))
        .toList();

    return GameState(
      tableau: TableauPiles(columns),
      stock: StockPile(stock),
      foundations: const Foundations(completedRuns: 0),
      difficulty: difficulty,
      dealSource: RandomDealSource(seed),
      seed: seed,
      startedAt: DateTime.fromMillisecondsSinceEpoch(0),
      moves: 0,
      hintsUsed: 0,
      undosUsed: 0,
      redosUsed: 0,
      restartsUsed: 0,
    );
  }

  List<PlayingCard> _buildDeckForDifficulty() {
    final ranks = CardRank.values;
    final deck = <PlayingCard>[];
    var id = 0;

    void addSuitCopies(CardSuit suit, int copies) {
      for (var c = 0; c < copies; c++) {
        for (final rank in ranks) {
          deck.add(
            PlayingCard(id: id++, rank: rank, suit: suit, faceUp: false),
          );
        }
      }
    }

    switch (difficulty) {
      case Difficulty.oneSuit:
        addSuitCopies(CardSuit.spades, 8);
      case Difficulty.twoSuit:
        addSuitCopies(CardSuit.spades, 4);
        addSuitCopies(CardSuit.hearts, 4);
      case Difficulty.fourSuit:
        addSuitCopies(CardSuit.spades, 2);
        addSuitCopies(CardSuit.hearts, 2);
        addSuitCopies(CardSuit.diamonds, 2);
        addSuitCopies(CardSuit.clubs, 2);
    }

    return deck;
  }

  List<PlayingCard> _shuffleDeterministic(List<PlayingCard> deck, int seed) {
    final result = List<PlayingCard>.of(deck);
    var state = seed & 0x7fffffff;

    int nextInt(int maxExclusive) {
      state = (1103515245 * state + 12345) & 0x7fffffff;
      return state % maxExclusive;
    }

    for (var i = result.length - 1; i > 0; i--) {
      final j = nextInt(i + 1);
      final temp = result[i];
      result[i] = result[j];
      result[j] = temp;
    }

    return result;
  }

  bool _tryGreedy(GameState start, {required int maxSteps}) {
    var state = start;

    for (var step = 0; step < maxSteps; step++) {
      if (_isWon(state)) {
        return true;
      }

      final moves = _expandMoves(state);
      if (moves.isNotEmpty) {
        moves.sort((a, b) => _stateScore(b).compareTo(_stateScore(a)));
        state = moves.first;
        continue;
      }

      if (_canDealFromStockClassic(state)) {
        state = _normalizeAfterAction(const DealFromStockAction().apply(state));
        continue;
      }

      return false;
    }

    return _isWon(state);
  }

  _DfsOutcome _searchWithCap(
    List<GameState> startStates, {
    required int timeBudgetMs,
  }) {
    if (timeBudgetMs <= 0) {
      return const _DfsOutcome(
        result: _SolveResult.timeout,
        nodesExplored: 0,
        timeoutCause: _TimeoutCause.timeBudgetHit,
      );
    }

    final watch = Stopwatch()..start();
    final stack = <_Node>[];
    for (final state in startStates) {
      stack.add(_Node(state: state, depth: 0));
    }

    final bestSeen = <String, int>{};

    var explored = 0;
    while (stack.isNotEmpty) {
      if (watch.elapsedMilliseconds >= timeBudgetMs) {
        return _DfsOutcome(
          result: _SolveResult.timeout,
          nodesExplored: explored,
          timeoutCause: _TimeoutCause.timeBudgetHit,
        );
      }
      if (explored >= nodeCap) {
        return _DfsOutcome(
          result: _SolveResult.timeout,
          nodesExplored: explored,
          timeoutCause: _TimeoutCause.nodeCapHit,
        );
      }

      final node = stack.removeLast();
      explored++;

      if (_isWon(node.state)) {
        return _DfsOutcome(
          result: _SolveResult.solvable,
          nodesExplored: explored,
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

      final nextStates = _expandAll(node.state);
      nextStates.sort((a, b) => _stateScore(a).compareTo(_stateScore(b)));
      for (final next in nextStates) {
        stack.add(_Node(state: next, depth: node.depth + 1));
      }
    }

    return _DfsOutcome(result: _SolveResult.unsolved, nodesExplored: explored);
  }

  _RandomWalkOutcome _tryRandomWalk(
    GameState initial, {
    required int seed,
    required Stopwatch overallWatch,
    required int timeBudgetMs,
  }) {
    var trialsAttempted = 0;
    var bestState = initial;
    var bestScore = _stateScore(initial);

    void considerBest(GameState state) {
      final score = _stateScore(state);
      if (score > bestScore) {
        bestState = state;
        bestScore = score;
      }
    }

    final deadlineMs = overallWatch.elapsedMilliseconds + timeBudgetMs;

    for (var trial = 0; trial < randomWalkTrials; trial++) {
      if (overallWatch.elapsedMilliseconds >= deadlineMs) {
        break;
      }

      trialsAttempted++;
      final random = Random(_randomSeed(seed, trial));
      var state = initial;

      for (var step = 0; step < randomWalkSteps; step++) {
        if (_isWon(state)) {
          return _RandomWalkOutcome(
            solved: true,
            trialsAttempted: trialsAttempted,
            bestState: state,
            bestScore: _stateScore(state),
          );
        }

        if (overallWatch.elapsedMilliseconds >= deadlineMs) {
          return _RandomWalkOutcome(
            solved: false,
            trialsAttempted: trialsAttempted,
            bestState: bestState,
            bestScore: bestScore,
          );
        }

        final options = _enumerateMoveOptions(state);
        if (options.isNotEmpty) {
          final selected = _pickWeightedMove(options, random);
          final moved = selected.action.apply(state);
          if (identical(moved, state)) {
            break;
          }
          state = _normalizeAfterAction(moved);
          considerBest(state);
          continue;
        }

        if (_canDealFromStockClassic(state)) {
          final dealt = const DealFromStockAction().apply(state);
          if (identical(dealt, state)) {
            break;
          }
          state = _normalizeAfterAction(dealt);
          considerBest(state);
          continue;
        }

        break;
      }
    }

    return _RandomWalkOutcome(
      solved: false,
      trialsAttempted: trialsAttempted,
      bestState: bestState,
      bestScore: bestScore,
    );
  }

  int _randomSeed(int seed, int trial) {
    final mixed = ((seed * 1103515245) ^ (trial * 12345)) & 0x7fffffff;
    return mixed == 0 ? 1 : mixed;
  }

  List<GameState> _expandAll(GameState state) {
    final results = <GameState>[];
    results.addAll(_expandMoves(state));

    if (_canDealFromStockClassic(state)) {
      final dealt = const DealFromStockAction().apply(state);
      if (!identical(dealt, state)) {
        results.add(_normalizeAfterAction(dealt));
      }
    }

    return results;
  }

  List<GameState> _expandMoves(GameState state) {
    final results = <GameState>[];
    final options = _enumerateMoveOptions(state);

    for (final option in options) {
      final next = option.action.apply(state);
      if (identical(next, state)) {
        continue;
      }
      results.add(_normalizeAfterAction(next));
    }

    return results;
  }

  _MoveOption _pickWeightedMove(List<_MoveOption> options, Random random) {
    var totalWeight = 0;
    for (final option in options) {
      totalWeight += option.revealsFaceDownCard ? 6 : 1;
    }

    var pick = random.nextInt(totalWeight);
    for (final option in options) {
      pick -= option.revealsFaceDownCard ? 6 : 1;
      if (pick < 0) {
        return option;
      }
    }

    return options.last;
  }

  List<_MoveOption> _enumerateMoveOptions(GameState state) {
    final options = <_MoveOption>[];

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

        final movedCards = source.sublist(startIndex, startIndex + run.length);
        final exposesFaceDownTop =
            startIndex > 0 &&
            source[startIndex - 1].faceUp == false &&
            startIndex + run.length == source.length;

        for (
          var toColumn = 0;
          toColumn < state.tableau.columns.length;
          toColumn++
        ) {
          if (toColumn == fromColumn) {
            continue;
          }

          if (!_validator
              .canDropRun(state, toColumn, movedCards.first)
              .isValid) {
            continue;
          }

          options.add(
            _MoveOption(
              action: MoveStackAction(
                fromColumn: fromColumn,
                toColumn: toColumn,
                startIndex: startIndex,
                movedCards: movedCards,
                flippedSourceCardOnApply: exposesFaceDownTop,
              ),
              revealsFaceDownCard: exposesFaceDownTop,
            ),
          );
        }
      }
    }

    return options;
  }

  GameState _normalizeAfterAction(GameState state) {
    var current = state;
    var changed = true;

    while (changed) {
      changed = false;
      for (var column = 0; column < current.tableau.columns.length; column++) {
        final startIndex = _validator.detectCompleteRunAtEnd(current, column);
        if (startIndex == null) {
          continue;
        }

        final removedCards = current.tableau.columns[column].sublist(
          startIndex,
        );
        final source = current.tableau.columns[column];
        final flipsExposedCard =
            startIndex > 0 &&
            source[startIndex - 1].faceUp == false &&
            startIndex + removedCards.length == source.length;

        final action = AutoCompleteRunAction(
          columnIndex: column,
          startIndex: startIndex,
          removedCards: removedCards,
          flippedExposedCardOnApply: flipsExposedCard,
        );

        final next = action.apply(current);
        if (!identical(next, current)) {
          current = next;
          changed = true;
        }
      }
    }

    return current;
  }

  bool _canDealFromStockClassic(GameState state) {
    if (state.stock.cards.length < 10) {
      return false;
    }
    return state.tableau.columns.every((column) => column.isNotEmpty);
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
        ..write(card.suit.index)
        ..write(':')
        ..write(card.rank.index)
        ..write(',');
    }
    sb.write('|');

    final columnKeys = <String>[];
    for (final column in state.tableau.columns) {
      final col = StringBuffer();
      for (final card in column) {
        col
          ..write(card.suit.index)
          ..write(':')
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
  const _Node({required this.state, required this.depth});

  final GameState state;
  final int depth;
}

class _MoveOption {
  const _MoveOption({required this.action, required this.revealsFaceDownCard});

  final MoveStackAction action;
  final bool revealsFaceDownCard;
}

String _label(Difficulty difficulty) => switch (difficulty) {
  Difficulty.oneSuit => '1-suit',
  Difficulty.twoSuit => '2-suit',
  Difficulty.fourSuit => '4-suit',
};

String _usage() => '''Usage:
  dart run tool/generate_solvable_seeds.dart [options]

Options:
  --difficulty=one|two|four|all   Target difficulty set. Default: all
  --daily-count-1=<int>           Daily targets for 1-suit (default: 10)
  --random-count-1=<int>          Random targets for 1-suit (default: 20)
  --daily-count-2=<int>           Daily targets for 2-suit (default: 0)
  --random-count-2=<int>          Random targets for 2-suit (default: 0)
  --daily-count-4=<int>           Daily targets for 4-suit (default: 0)
  --random-count-4=<int>          Random targets for 4-suit (default: 0)
  --seed-start-1=<int>            Start seed for 1-suit (default: 1)
  --seed-start-2=<int>            Start seed for 2-suit (default: 1)
  --seed-start-4=<int>            Start seed for 4-suit (default: 1)
  --budget-1=<duration>           Budget for 1-suit (e.g. 10m)
  --budget-2=<duration>           Budget for 2-suit (e.g. 10m)
  --budget-4=<duration>           Budget for 4-suit (e.g. 30m)
  --out=<path>                    Output file (default: tool/tmp_generated_seeds.dart)
  --per-seed-ms=<int>             Per-seed solve budget (default: 2000)
  --node-cap=<int>                DFS node cap (default: 120000)
  --max-depth=<int>               DFS depth cap (default: 280)
  --random-walk-trials=<int>      Random-walk trials (default: 120)
  --random-walk-steps=<int>       Random-walk steps (default: 700)

Budget behavior:
  If a selected difficulty omits budget and stdin is interactive, the tool asks
  for minutes in terminal; otherwise defaults are used (1/2: 10m, 4: 30m).
''';
