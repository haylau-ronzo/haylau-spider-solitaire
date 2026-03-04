import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../app/app_services.dart';
import '../../app/routes.dart';
import '../../game/engine/game_engine.dart';
import '../../game/model/deal_source.dart';
import '../../game/model/difficulty.dart';
import '../../game/model/game_state.dart';
import '../../game/solvable/solvable_seed_usage_tracker.dart';
import '../../game/solvable/solvable_solution_step.dart';
import '../../game/solvable/solvable_solutions_1suit_verified.dart';
import 'widgets/tableau_column_view.dart';

class PlayScreenArgs {
  const PlayScreenArgs({required this.difficulty, required this.dealSource});

  final Difficulty difficulty;
  final DealSource dealSource;
}

class PlayScreen extends StatefulWidget {
  const PlayScreen({super.key, required this.args});

  final PlayScreenArgs args;

  @override
  State<PlayScreen> createState() => _PlayScreenState();
}

class _PlayScreenState extends State<PlayScreen> {
  late final GameEngine _engine;
  Timer? _ticker;
  int? _selectedColumn;
  bool _solvableUsageRecorded = false;

  bool _solutionPreviewActive = false;
  bool _solutionPreviewPaused = false;
  bool _solutionPreviewCancelRequested = false;
  int _solutionPreviewStepIndex = 0;
  int _solutionPreviewTotalSteps = 0;
  int _solutionPreviewPendingSingleSteps = 0;
  String _solutionPreviewStepDescription = '';
  GameEngine? _solutionPreviewEngine;
  Completer<void>? _solutionPreviewWaiter;

  static const Duration _solutionPreviewStepDelay = Duration(seconds: 2);

  GameState get _displayState => _solutionPreviewEngine?.state ?? _engine.state;

  @override
  void initState() {
    super.initState();
    _engine = GameEngine();
    _engine.newGame(
      difficulty: widget.args.difficulty,
      dealSource: widget.args.dealSource,
    );
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _solutionPreviewWaiter?.complete();
    super.dispose();
  }

  String _format(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    final hours = d.inHours.toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }

  String _playInfoLabel(GameState state) {
    final mode = switch (state.dealSource) {
      DailyDealSource _ => 'Daily',
      DailySolvableDealSource _ => 'Daily',
      RandomDealSource _ => 'Random',
      RandomSolvableDealSource _ => 'Random',
    };
    final kind = switch (state.dealSource) {
      DailySolvableDealSource _ => 'Guaranteed',
      RandomSolvableDealSource _ => 'Guaranteed',
      _ => 'TotallyRandom',
    };
    return '$mode $kind | ${state.difficulty.label} | Seed ${state.seed}';
  }

  Future<void> _recordCompletedSolvableSeedIfNeeded() async {
    if (_solvableUsageRecorded || !_engine.isWon) {
      return;
    }
    _solvableUsageRecorded = true;
    await recordCompletedSolvableSeedUsage(
      dealSource: _engine.state.dealSource,
      difficulty: _engine.state.difficulty,
      seed: _engine.state.seed,
      repo: AppServices.solvableSeedUsageRepo,
    );
  }

  void _signalPreviewLoop() {
    final waiter = _solutionPreviewWaiter;
    if (waiter != null && !waiter.isCompleted) {
      waiter.complete();
    }
    _solutionPreviewWaiter = null;
  }

  Future<void> _waitForPreviewSignal() async {
    final existing = _solutionPreviewWaiter;
    if (existing != null) {
      await existing.future;
      return;
    }

    final waiter = Completer<void>();
    _solutionPreviewWaiter = waiter;
    await waiter.future;
  }

  Future<void> _waitStepDelayOrCancel(Duration delay) async {
    var remaining = delay;
    const tick = Duration(milliseconds: 25);
    while (mounted &&
        !_solutionPreviewCancelRequested &&
        remaining > Duration.zero) {
      final next = remaining > tick ? tick : remaining;
      await Future<void>.delayed(next);
      remaining -= next;
    }
  }

  String _describeSolutionStep(SolutionStepDto step) {
    if (step.isDeal) {
      return 'Deal';
    }

    if (!step.isMove ||
        step.fromColumn == null ||
        step.toColumn == null ||
        step.startIndex == null) {
      return 'Invalid step';
    }

    final lengthLabel = step.movedLength == null
        ? ''
        : ' len ${step.movedLength}';
    return 'Move ${step.fromColumn}->${step.toColumn}$lengthLabel';
  }

  String _stateFingerprint(GameState state) {
    final tableau = state.tableau.columns
        .map(
          (column) => column
              .map((card) => '${card.id}:${card.faceUp ? 1 : 0}')
              .join(','),
        )
        .join('|');
    final stock = state.stock.cards
        .map((card) => '${card.id}:${card.faceUp ? 1 : 0}')
        .join(',');
    return '${state.moves};${state.foundations.completedRuns};$tableau;$stock';
  }

  bool _applySolutionStep(SolutionStepDto step, {required GameEngine engine}) {
    final before = _stateFingerprint(engine.state);

    bool applied;
    if (step.isDeal) {
      applied = engine.dealFromStock();
    } else {
      if (!step.isMove ||
          step.fromColumn == null ||
          step.toColumn == null ||
          step.startIndex == null) {
        return false;
      }
      applied = engine.moveStack(
        step.fromColumn!,
        step.startIndex!,
        step.toColumn!,
      );
    }

    if (!applied) {
      return false;
    }

    if (step.isMove) {
      final after = _stateFingerprint(engine.state);
      if (before == after) {
        return false;
      }
    }

    return true;
  }

  bool _isCurrentDealVerifiedOneSuit() {
    final source = _engine.state.dealSource;
    return _engine.state.difficulty == Difficulty.oneSuit &&
        (source is DailySolvableDealSource ||
            source is RandomSolvableDealSource);
  }

  List<SolutionStepDto>? _solutionPrefixForCurrentSeed() {
    if (!_isCurrentDealVerifiedOneSuit()) {
      return null;
    }
    return verifiedSolutionPrefixForSeed1Suit(_engine.state.seed);
  }

  Future<void> _showSolutionSheet() async {
    if (_solutionPreviewActive) {
      return;
    }

    final prefix = _solutionPrefixForCurrentSeed();
    final enabled = prefix != null && prefix.isNotEmpty;

    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          top: false,
          child: ListView(
            shrinkWrap: true,
            children: [
              ListTile(
                title: const Text('Show first 30 steps'),
                subtitle: const Text(
                  'Preview only. Returns to your current game when done.',
                ),
                enabled: enabled,
                onTap: enabled
                    ? () => Navigator.of(context).pop('prefix')
                    : null,
              ),
            ],
          ),
        );
      },
    );

    if (!mounted || action != 'prefix' || !enabled) {
      return;
    }

    await _runSolutionPreview(prefix.take(30).toList(growable: false));
  }

  Future<void> _runSolutionPreview(List<SolutionStepDto> steps) async {
    if (steps.isEmpty || _solutionPreviewActive) {
      return;
    }

    final previewEngine = GameEngine();
    previewEngine.restoreState(_engine.state);

    setState(() {
      _solutionPreviewActive = true;
      _solutionPreviewPaused = false;
      _solutionPreviewCancelRequested = false;
      _solutionPreviewStepIndex = 0;
      _solutionPreviewTotalSteps = steps.length;
      _solutionPreviewPendingSingleSteps = 0;
      _solutionPreviewStepDescription = '';
      _solutionPreviewEngine = previewEngine;
      _selectedColumn = null;
    });

    for (var i = 0; i < steps.length; i++) {
      if (!mounted || _solutionPreviewCancelRequested) {
        break;
      }

      while (mounted &&
          !_solutionPreviewCancelRequested &&
          _solutionPreviewPaused &&
          _solutionPreviewPendingSingleSteps <= 0) {
        await _waitForPreviewSignal();
      }
      if (!mounted || _solutionPreviewCancelRequested) {
        break;
      }

      if (_solutionPreviewPaused && _solutionPreviewPendingSingleSteps > 0) {
        _solutionPreviewPendingSingleSteps--;
      }

      final step = steps[i];
      final stepDescription = _describeSolutionStep(step);
      final ok = _applySolutionStep(step, engine: previewEngine);
      if (!ok) {
        _showSnack(
          'Solution preview stopped at step ${i + 1}: $stepDescription',
        );
        break;
      }

      if (!mounted) {
        break;
      }
      setState(() {
        _solutionPreviewStepIndex = i + 1;
        _solutionPreviewStepDescription = stepDescription;
      });

      await SchedulerBinding.instance.endOfFrame;
      await _waitStepDelayOrCancel(_solutionPreviewStepDelay);
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _solutionPreviewActive = false;
      _solutionPreviewPaused = false;
      _solutionPreviewCancelRequested = false;
      _solutionPreviewStepIndex = 0;
      _solutionPreviewTotalSteps = 0;
      _solutionPreviewPendingSingleSteps = 0;
      _solutionPreviewStepDescription = '';
      _solutionPreviewWaiter = null;
      _solutionPreviewEngine = null;
    });
  }

  void _setPreviewPaused(bool paused) {
    if (!_solutionPreviewActive) {
      return;
    }
    setState(() {
      _solutionPreviewPaused = paused;
    });
    if (!paused) {
      _signalPreviewLoop();
    }
  }

  void _stepPreviewOnce() {
    if (!_solutionPreviewActive || !_solutionPreviewPaused) {
      return;
    }
    setState(() {
      _solutionPreviewPendingSingleSteps += 1;
    });
    _signalPreviewLoop();
  }

  void _cancelSolutionPreview() {
    setState(() {
      _solutionPreviewCancelRequested = true;
    });
    _signalPreviewLoop();
  }

  void _showSnack(String message) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _afterRealMove() async {
    await _recordCompletedSolvableSeedIfNeeded();
    if (!mounted) {
      return;
    }
    setState(() {});
  }

  void _onColumnTap(int column) {
    if (_solutionPreviewActive) {
      return;
    }

    if (_selectedColumn == null) {
      setState(() => _selectedColumn = column);
      return;
    }
    if (_selectedColumn == column) {
      setState(() => _selectedColumn = null);
      return;
    }

    final from = _selectedColumn!;
    final startIndex = _engine.state.tableau.columns[from].lastIndexWhere(
      (card) => card.faceUp,
    );
    if (startIndex >= 0) {
      _engine.moveStack(from, startIndex, column);
    }
    setState(() => _selectedColumn = null);
    unawaited(_afterRealMove());
  }

  @override
  Widget build(BuildContext context) {
    final state = _displayState;
    final elapsed = DateTime.now().difference(state.startedAt);
    final stockRowsRemaining = state.stock.cards.length ~/ 10;

    return Scaffold(
      appBar: AppBar(title: const Text('Spider')),
      body: Stack(
        children: [
          IgnorePointer(
            ignoring: _solutionPreviewActive,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  child: Row(
                    children: [
                      Text('Time: ${_format(elapsed)}'),
                      const SizedBox(width: 18),
                      Text('Moves: ${state.moves}'),
                      const Spacer(),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('Stock: $stockRowsRemaining rows'),
                          const SizedBox(height: 4),
                          FilledButton(
                            onPressed: state.stock.cards.length >= 10
                                ? () {
                                    _engine.dealFromStock();
                                    setState(() {
                                      _selectedColumn = null;
                                    });
                                    unawaited(_afterRealMove());
                                  }
                                : null,
                            child: const Text('Deal'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      _playInfoLabel(state),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: List.generate(
                        10,
                        (i) => Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: TableauColumnView(
                            cards: state.tableau.columns[i],
                            onTap: () => _onColumnTap(i),
                            isSelected: _selectedColumn == i,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Expanded(
                          child: FilledButton.tonal(
                            onPressed: _engine.canUndo
                                ? () {
                                    _engine.undo();
                                    setState(() => _selectedColumn = null);
                                    unawaited(_afterRealMove());
                                  }
                                : null,
                            child: const Text('Undo'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: FilledButton.tonal(
                            onPressed: _engine.canRedo
                                ? () {
                                    _engine.redo();
                                    setState(() => _selectedColumn = null);
                                    unawaited(_afterRealMove());
                                  }
                                : null,
                            child: const Text('Redo'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: FilledButton.tonal(
                            onPressed: () {
                              _engine.requestHint();
                              _showSnack('Hint not implemented yet.');
                            },
                            child: const Text('Hint'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: FilledButton.tonal(
                            onPressed: () {
                              setState(() {
                                _engine.restartSameDeal();
                                _selectedColumn = null;
                                _solvableUsageRecorded = false;
                              });
                            },
                            child: const Text('Restart'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: FilledButton.tonal(
                            onPressed: _solutionPrefixForCurrentSeed() == null
                                ? null
                                : _showSolutionSheet,
                            child: const Text('Solution'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: FilledButton(
                            onPressed: () =>
                                Navigator.of(context).pushNamedAndRemoveUntil(
                                  AppRoutes.home,
                                  (route) => false,
                                ),
                            child: const Text('Menu'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_solutionPreviewActive)
            Positioned(
              left: 12,
              right: 12,
              bottom: 56,
              child: Material(
                elevation: 6,
                borderRadius: BorderRadius.circular(12),
                color: Theme.of(context).colorScheme.surface,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Step $_solutionPreviewStepIndex / $_solutionPreviewTotalSteps',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _solutionPreviewStepDescription.isEmpty
                            ? 'Waiting...'
                            : _solutionPreviewStepDescription,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          FilledButton.tonalIcon(
                            onPressed: () {
                              _setPreviewPaused(!_solutionPreviewPaused);
                            },
                            icon: Icon(
                              _solutionPreviewPaused
                                  ? Icons.play_arrow
                                  : Icons.pause,
                            ),
                            label: Text(
                              _solutionPreviewPaused ? 'Play' : 'Pause',
                            ),
                          ),
                          const SizedBox(width: 8),
                          FilledButton.tonalIcon(
                            onPressed: _solutionPreviewPaused
                                ? _stepPreviewOnce
                                : null,
                            icon: const Icon(Icons.skip_next),
                            label: const Text('Next'),
                          ),
                          const SizedBox(width: 8),
                          FilledButton.tonal(
                            onPressed: _cancelSolutionPreview,
                            child: const Text('Cancel'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
