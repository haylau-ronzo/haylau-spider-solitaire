import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../app/app_services.dart';
import '../../app/routes.dart';
import '../../game/engine/game_engine.dart';
import '../../game/model/card.dart';
import '../../game/model/deal_source.dart';
import '../../game/model/difficulty.dart';
import '../../game/model/game_state.dart';
import '../../game/persistence/save_model.dart';
import '../../game/solvable/solvable_seed_usage_tracker.dart';
import '../../game/solvable/solvable_solution_step.dart';
import '../../game/solvable/solution_step_replayer.dart';
import '../../game/solvable/solvable_solutions_1suit_verified.dart';
import 'widgets/tableau_column_view.dart';

class PlayScreenArgs {
  const PlayScreenArgs({
    required this.difficulty,
    required this.dealSource,
    this.resumeSave,
  });

  final Difficulty difficulty;
  final DealSource dealSource;
  final SaveModel? resumeSave;
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
  Timer? _hintClearTimer;
  int? _selectedColumn;
  int? _selectedStartIndex;
  int? _selectedLength;
  DragRunPayload? _activeDragPayload;
  final Map<int, List<HintFlashRun>> _hintRunsByColumn =
      <int, List<HintFlashRun>>{};
  bool _hintFlashOn = false;
  Set<int> _hintTargetColumns = <int>{};
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
    if (widget.args.resumeSave != null) {
      _engine.restoreState(
        widget.args.resumeSave!.gameState,
        undoStack: widget.args.resumeSave!.undoStack,
        redoStack: widget.args.resumeSave!.redoStack,
      );
    } else {
      _engine.newGame(
        difficulty: widget.args.difficulty,
        dealSource: widget.args.dealSource,
      );
    }

    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _hintClearTimer?.cancel();
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
    final result = applyStrictSolutionStep(state: engine.state, step: step);
    if (!result.applied) {
      return false;
    }

    engine.restoreState(result.nextState);

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

  // ignore: unused_element
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
    // Keep preview semantics identical to generated solutions: replay from dealt start.
    previewEngine.newGame(
      difficulty: _engine.state.difficulty,
      dealSource: RandomDealSource(_engine.state.seed),
    );

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
      _selectedStartIndex = null;
      _selectedLength = null;
      _activeDragPayload = null;
      _clearHintData();
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

  void _clearHintData() {
    _hintClearTimer?.cancel();
    _hintRunsByColumn.clear();
    _hintTargetColumns = <int>{};
    _hintFlashOn = false;
  }

  void _clearSelection() {
    _selectedColumn = null;
    _selectedStartIndex = null;
    _selectedLength = null;
  }

  void _resetInteractionState() {
    _clearSelection();
    _activeDragPayload = null;
    _clearHintData();
  }

  _SelectedRunInfo? _selectedRunInfo(GameState state) {
    final fromColumn = _selectedColumn;
    final startIndex = _selectedStartIndex;
    if (fromColumn == null || startIndex == null) {
      return null;
    }

    if (fromColumn < 0 || fromColumn >= state.tableau.columns.length) {
      return null;
    }

    final column = state.tableau.columns[fromColumn];
    if (column.isEmpty || startIndex < 0 || startIndex >= column.length) {
      return null;
    }

    final run = _engine.getEffectiveMoveRun(fromColumn, startIndex);
    if (run == null || run.effectiveStartIndex != startIndex) {
      return null;
    }

    if (run.effectiveStartIndex + run.length > column.length) {
      return null;
    }

    return _SelectedRunInfo(
      fromColumn: fromColumn,
      startIndex: run.effectiveStartIndex,
      length: run.length,
      firstCard: column[run.effectiveStartIndex],
    );
  }

  int? _pickBestAutoDestination(int fromColumn, PlayingCard runFirstCard) {
    final state = _engine.state;
    final targets = _engine
        .getLegalDropTargets(runFirstCard)
        .where((target) => target != fromColumn)
        .toList();
    if (targets.isEmpty) {
      return null;
    }

    targets.sort((a, b) {
      final aColumn = state.tableau.columns[a];
      final bColumn = state.tableau.columns[b];
      final aEmpty = aColumn.isEmpty ? 1 : 0;
      final bEmpty = bColumn.isEmpty ? 1 : 0;
      if (aEmpty != bEmpty) {
        return aEmpty - bEmpty;
      }
      if (aColumn.isNotEmpty && bColumn.isNotEmpty) {
        final rankCompare = bColumn.last.rank.index - aColumn.last.rank.index;
        if (rankCompare != 0) {
          return rankCompare;
        }
      }
      return a - b;
    });

    return targets.first;
  }

  bool _isDropTargetHighlighted(int column, GameState state) {
    if (_hintTargetColumns.contains(column)) {
      return true;
    }

    final selected = _selectedRunInfo(state);
    if (selected != null &&
        column != selected.fromColumn &&
        _engine.canDropRun(column, selected.firstCard).isValid) {
      return true;
    }

    final drag = _activeDragPayload;
    if (drag != null &&
        drag.cards.isNotEmpty &&
        column != drag.fromColumn &&
        _engine.canDropRun(column, drag.cards.first).isValid) {
      return true;
    }

    return false;
  }

  Future<void> _showHint() async {
    if (_solutionPreviewActive) {
      return;
    }

    final hints = _engine.requestHintRuns(maxCount: 1);
    if (hints.isEmpty) {
      setState(() {
        _clearHintData();
      });
      _showSnack('No useful hint right now.');
      return;
    }

    final hint = hints.first;
    final sourceColumnCards = _engine.state.tableau.columns[hint.fromColumn];
    if (hint.startIndex < 0 || hint.startIndex >= sourceColumnCards.length) {
      _showSnack('Hint unavailable.');
      return;
    }

    final run = _engine.getEffectiveMoveRun(hint.fromColumn, hint.startIndex);
    final targetColumns = <int>{};
    if (run != null) {
      final firstCard = sourceColumnCards[run.effectiveStartIndex];
      targetColumns.addAll(
        _engine
            .getLegalDropTargets(firstCard)
            .where((column) => column != hint.fromColumn),
      );
    }

    setState(() {
      _selectedColumn = hint.fromColumn;
      _selectedStartIndex = hint.startIndex;
      _selectedLength = hint.length;
      _activeDragPayload = null;
      _clearHintData();
      _hintRunsByColumn[hint.fromColumn] = <HintFlashRun>[
        HintFlashRun(startIndex: hint.startIndex, length: hint.length),
      ];
      _hintTargetColumns = targetColumns;
      _hintFlashOn = true;
    });

    _hintClearTimer = Timer(const Duration(seconds: 2), () {
      if (!mounted) {
        return;
      }
      setState(() {
        _hintFlashOn = false;
      });
    });

    if (targetColumns.isEmpty) {
      _showSnack('Hint: select column ${hint.fromColumn + 1}.');
    } else {
      final targetText = targetColumns.map((c) => c + 1).join(', ');
      _showSnack('Hint: ${hint.fromColumn + 1} -> $targetText');
    }
  }

  Future<void> _afterRealMove() async {
    await _recordCompletedSolvableSeedIfNeeded();
    if (!mounted) {
      return;
    }
    setState(() {});
  }

  void _onCardTap(int column, int index) {
    if (_solutionPreviewActive) {
      return;
    }

    final run = _engine.getEffectiveMoveRun(column, index);
    if (run == null || run.effectiveStartIndex != index) {
      return;
    }

    setState(() {
      _clearHintData();
    });

    final sourceCards = _engine.state.tableau.columns[column];
    final runFirstCard = sourceCards[run.effectiveStartIndex];
    final targetColumn = _pickBestAutoDestination(column, runFirstCard);
    if (targetColumn != null) {
      final moved = _engine.moveStack(
        column,
        run.effectiveStartIndex,
        targetColumn,
      );
      if (!moved) {
        _showSnack('Illegal move');
        return;
      }
      setState(() {
        _resetInteractionState();
      });
      unawaited(_afterRealMove());
      return;
    }

    setState(() {
      _selectedColumn = column;
      _selectedStartIndex = run.effectiveStartIndex;
      _selectedLength = run.length;
    });
  }

  void _onColumnTap(int column) {
    if (_solutionPreviewActive) {
      return;
    }

    setState(() {
      _clearHintData();
    });

    final selected = _selectedRunInfo(_engine.state);
    if (selected == null) {
      final topFaceUp = _engine.state.tableau.columns[column].lastIndexWhere(
        (card) => card.faceUp,
      );
      if (topFaceUp >= 0) {
        _onCardTap(column, topFaceUp);
      }
      return;
    }

    if (selected.fromColumn == column) {
      setState(() {
        _clearSelection();
      });
      return;
    }

    final moved = _engine.moveStack(
      selected.fromColumn,
      selected.startIndex,
      column,
    );
    if (!moved) {
      _showSnack('Illegal move');
      return;
    }

    setState(() {
      _resetInteractionState();
    });
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
                                      _resetInteractionState();
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
                            columnIndex: i,
                            cards: state.tableau.columns[i],
                            tapEnabled: true,
                            previewNextCardOnDrag: true,
                            activeDragPayload: _activeDragPayload,
                            selectedStartIndex: _selectedColumn == i
                                ? _selectedStartIndex
                                : null,
                            selectedLength: _selectedColumn == i
                                ? _selectedLength
                                : null,
                            isValidTapTarget: _isDropTargetHighlighted(
                              i,
                              state,
                            ),
                            hintRuns:
                                _hintRunsByColumn[i] ?? const <HintFlashRun>[],
                            hintFlashOn: _hintFlashOn,
                            canDragFromIndex: (cardIndex) {
                              final run = _engine.getEffectiveMoveRun(
                                i,
                                cardIndex,
                              );
                              return run != null &&
                                  run.effectiveStartIndex == cardIndex;
                            },
                            onBuildDragPayload: (cardIndex) {
                              final run = _engine.getEffectiveMoveRun(
                                i,
                                cardIndex,
                              );
                              if (run == null ||
                                  run.effectiveStartIndex != cardIndex) {
                                return DragRunPayload(
                                  fromColumn: i,
                                  startIndex: cardIndex,
                                  cards: const <PlayingCard>[],
                                );
                              }

                              final cards = List<PlayingCard>.of(
                                _engine.state.tableau.columns[i].sublist(
                                  run.effectiveStartIndex,
                                  run.effectiveStartIndex + run.length,
                                ),
                              );
                              return DragRunPayload(
                                fromColumn: i,
                                startIndex: run.effectiveStartIndex,
                                cards: cards,
                              );
                            },
                            canAcceptDrop: (payload) {
                              if (payload.cards.isEmpty ||
                                  payload.fromColumn == i) {
                                return false;
                              }
                              return _engine
                                  .canDropRun(i, payload.cards.first)
                                  .isValid;
                            },
                            onAcceptDrop: (payload) {
                              final moved = _engine.moveStack(
                                payload.fromColumn,
                                payload.startIndex,
                                i,
                              );
                              if (!moved) {
                                _showSnack('Illegal move');
                                return;
                              }
                              setState(() {
                                _resetInteractionState();
                              });
                              unawaited(_afterRealMove());
                            },
                            onIllegalDrop: () => _showSnack('Illegal move'),
                            onCardTap: (cardIndex) => _onCardTap(i, cardIndex),
                            onColumnTap: () => _onColumnTap(i),
                            onDragStarted: (payload) {
                              setState(() {
                                _clearHintData();
                                _activeDragPayload = payload;
                                _selectedColumn = payload.fromColumn;
                                _selectedStartIndex = payload.startIndex;
                                _selectedLength = payload.cards.length;
                              });
                            },
                            onDragCanceled: () {
                              setState(() {
                                _activeDragPayload = null;
                              });
                            },
                            onDragCompleted: () {
                              setState(() {
                                _activeDragPayload = null;
                              });
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
                    child: Material(
                      color: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(14),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            IconButton(
                              tooltip: 'Undo',
                              onPressed: _engine.canUndo
                                  ? () {
                                      _engine.undo();
                                      setState(() {
                                        _resetInteractionState();
                                      });
                                      unawaited(_afterRealMove());
                                    }
                                  : null,
                              icon: const Icon(Icons.undo),
                            ),
                            IconButton(
                              tooltip: 'Redo',
                              onPressed: _engine.canRedo
                                  ? () {
                                      _engine.redo();
                                      setState(() {
                                        _resetInteractionState();
                                      });
                                      unawaited(_afterRealMove());
                                    }
                                  : null,
                              icon: const Icon(Icons.redo),
                            ),
                            IconButton(
                              tooltip: 'Hint',
                              onPressed: _showHint,
                              icon: const Icon(Icons.lightbulb_outline),
                            ),
                            IconButton(
                              tooltip: 'Restart',
                              onPressed: () {
                                setState(() {
                                  _engine.restartSameDeal();
                                  _solvableUsageRecorded = false;
                                  _resetInteractionState();
                                });
                              },
                              icon: const Icon(Icons.refresh),
                            ),
                            IconButton(
                              tooltip: 'Menu',
                              onPressed: () =>
                                  Navigator.of(context).pushNamedAndRemoveUntil(
                                    AppRoutes.home,
                                    (route) => false,
                                  ),
                              icon: const Icon(Icons.menu),
                            ),
                          ],
                        ),
                      ),
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

class _SelectedRunInfo {
  const _SelectedRunInfo({
    required this.fromColumn,
    required this.startIndex,
    required this.length,
    required this.firstCard,
  });

  final int fromColumn;
  final int startIndex;
  final int length;
  final PlayingCard firstCard;
}
