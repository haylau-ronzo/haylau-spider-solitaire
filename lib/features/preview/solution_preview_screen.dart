import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../app/theme.dart';
import '../../game/engine/game_engine.dart';
import '../../game/model/card.dart';
import '../../game/model/deal_source.dart';
import '../../game/solvable/solvable_solution_step.dart';
import '../../game/solvable/solution_step_replayer.dart';
import '../play/widgets/felt_table_background.dart';
import '../play/widgets/tableau_column_view.dart';
import 'deal_choice.dart';

class SolutionPreviewArgs {
  const SolutionPreviewArgs({
    required this.deal,
    required this.steps,
    required this.title,
    this.fast = false,
  });

  final DealChoice deal;
  final List<SolutionStepDto> steps;
  final String title;
  final bool fast;
}

class SolutionPreviewScreen extends StatefulWidget {
  const SolutionPreviewScreen({super.key, required this.args});

  final SolutionPreviewArgs args;

  @override
  State<SolutionPreviewScreen> createState() => _SolutionPreviewScreenState();
}

class _SolutionPreviewScreenState extends State<SolutionPreviewScreen> {
  late final GameEngine _engine;

  bool _isRunning = true;
  bool _cancelRequested = false;
  int _pendingSingleSteps = 0;
  int _stepIndex = 0;
  String _stepDescription = '';
  SolutionStepKind? _currentStepKind;
  String? _lastApplyFailureReason;
  Completer<void>? _runWaiter;

  Duration get _stepDelay => widget.args.fast
      ? const Duration(milliseconds: 35)
      : const Duration(seconds: 2);

  @override
  void initState() {
    super.initState();
    _engine = GameEngine();
    // Always replay from a fresh initial state for this seed+difficulty.
    _engine.newGame(
      difficulty: widget.args.deal.difficulty,
      dealSource: RandomDealSource(widget.args.deal.seed),
    );
    if (kDebugMode) {
      debugPrint(
        'Solution preview fresh start seed=${widget.args.deal.seed} '
        'difficulty=${widget.args.deal.difficulty.name}',
      );
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_runSteps());
    });
  }

  @override
  void dispose() {
    _runWaiter?.complete();
    super.dispose();
  }

  void _signalRunLoop() {
    final waiter = _runWaiter;
    if (waiter != null && !waiter.isCompleted) {
      waiter.complete();
    }
    _runWaiter = null;
  }

  Future<void> _waitForRunSignal() async {
    final existing = _runWaiter;
    if (existing != null) {
      await existing.future;
      return;
    }
    final waiter = Completer<void>();
    _runWaiter = waiter;
    await waiter.future;
  }

  Future<void> _waitStepDelayOrCancel(Duration delay) async {
    var remaining = delay;
    const tick = Duration(milliseconds: 25);
    while (mounted && !_cancelRequested && remaining > Duration.zero) {
      final next = remaining > tick ? tick : remaining;
      await Future<void>.delayed(next);
      remaining -= next;
    }
  }

  String _describeSolutionStep(SolutionStepDto step) {
    if (step.isDeal) {
      return 'Deal';
    }
    if (!step.isMove || step.fromColumn == null || step.toColumn == null) {
      return 'Invalid step';
    }

    final lengthLabel = step.movedLength == null
        ? ''
        : ' len ${step.movedLength}';
    return 'Move ${step.fromColumn}->${step.toColumn}$lengthLabel';
  }

  String _cardLabel(PlayingCard card) {
    final face = card.faceUp ? 'U' : 'D';
    return '${card.rank.label}${card.suit.symbol}$face';
  }

  String _topFaceUpLabel(List<PlayingCard> column) {
    for (var i = column.length - 1; i >= 0; i--) {
      final card = column[i];
      if (card.faceUp) {
        return _cardLabel(card);
      }
    }
    return '-';
  }

  String _tailLabel(List<PlayingCard> column, {int maxCards = 5}) {
    if (column.isEmpty) {
      return '[]';
    }
    final start = column.length > maxCards ? column.length - maxCards : 0;
    final cards = column.sublist(start).map(_cardLabel).join(',');
    return '[$cards]';
  }

  void _debugLogDealState() {
    if (!kDebugMode) {
      return;
    }
    final state = _engine.state;
    final lengths = state.tableau.columns.map((c) => c.length).join(',');
    final tops = state.tableau.columns.map(_topFaceUpLabel).join(',');
    debugPrint(
      'Solution preview deal state seed=${widget.args.deal.seed} '
      'stock=${state.stock.cards.length} lengths=[$lengths] '
      'topFaceUp=[$tops]',
    );
  }

  void _debugLogMoveFailure(SolutionStepDto step, String reason) {
    if (!kDebugMode || !step.isMove) {
      return;
    }

    final from = step.fromColumn;
    final to = step.toColumn;
    final start = step.startIndex;
    final state = _engine.state;
    if (from == null || to == null || start == null) {
      debugPrint(
        'Solution preview move failure seed=${widget.args.deal.seed} '
        'reason=$reason dtoMissing=true',
      );
      return;
    }

    final source = (from >= 0 && from < state.tableau.columns.length)
        ? state.tableau.columns[from]
        : const <PlayingCard>[];
    final target = (to >= 0 && to < state.tableau.columns.length)
        ? state.tableau.columns[to]
        : const <PlayingCard>[];
    final run = (from >= 0 && from < state.tableau.columns.length)
        ? _engine.getEffectiveMoveRun(from, start)
        : null;
    final movedSegment = run == null
        ? const <PlayingCard>[]
        : source.sublist(
            run.effectiveStartIndex,
            run.effectiveStartIndex + run.length,
          );
    final firstCard = movedSegment.isEmpty ? null : movedSegment.first;
    final drop = firstCard == null ? null : _engine.canDropRun(to, firstCard);
    final targetTop = target.isEmpty ? '-' : _cardLabel(target.last);

    debugPrint(
      'Solution preview MOVE failure seed=${widget.args.deal.seed} '
      'step=${_stepIndex + 1}/${widget.args.steps.length} '
      'from=$from to=$to start=$start movedLength=${step.movedLength} '
      'reason=$reason dropReason=${drop?.reason ?? '-'}',
    );
    debugPrint(
      'Solution preview MOVE failure sourceTail=${_tailLabel(source)} '
      'moved=${movedSegment.map(_cardLabel).join(',')} '
      'targetTop=$targetTop targetTail=${_tailLabel(target)}',
    );
  }

  String _explainInvalidStep(SolutionStepDto step) {
    return _lastApplyFailureReason ?? 'step rejected';
  }

  String _stateFingerprint() {
    final state = _engine.state;
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

  bool _applyStep(SolutionStepDto step) {
    final before = _stateFingerprint();
    final result = applyStrictSolutionStep(state: _engine.state, step: step);
    if (!result.applied) {
      _lastApplyFailureReason = result.reason;
      return false;
    }

    _engine.restoreState(result.nextState);
    _lastApplyFailureReason = null;

    if (step.isDeal) {
      _debugLogDealState();
    }

    if (step.isMove) {
      final after = _stateFingerprint();
      if (before == after) {
        _lastApplyFailureReason = 'move produced no state change';
        return false;
      }
    }

    return true;
  }

  Future<void> _runSteps() async {
    final steps = widget.args.steps;

    for (var i = _stepIndex; i < steps.length; i++) {
      if (!mounted || _cancelRequested) {
        break;
      }

      while (mounted &&
          !_cancelRequested &&
          !_isRunning &&
          _pendingSingleSteps <= 0) {
        await _waitForRunSignal();
      }
      if (!mounted || _cancelRequested) {
        break;
      }

      if (!_isRunning && _pendingSingleSteps > 0) {
        _pendingSingleSteps--;
      }

      final step = steps[i];
      if (kDebugMode) {
        debugPrint(
          'Solution preview step seed=${widget.args.deal.seed} '
          'stepIndex=${i + 1}/${steps.length} kind=${step.kind.name}',
        );
      }
      final description = _describeSolutionStep(step);
      setState(() {
        _currentStepKind = step.kind;
      });
      final ok = _applyStep(step);
      if (!ok) {
        final reason = _explainInvalidStep(step);
        final failureLabel = step.isMove ? 'MOVE failed' : 'DEAL failed';
        if (step.isMove) {
          _debugLogMoveFailure(step, reason);
        }
        if (kDebugMode) {
          debugPrint(
            'Solution preview $failureLabel at step ${i + 1}: '
            '$description :: $reason',
          );
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Preview stopped at step ${i + 1}: $failureLabel '
                '($description) - $reason',
              ),
            ),
          );
        }
        break;
      }

      if (!mounted) {
        break;
      }
      setState(() {
        _stepIndex = i + 1;
        _stepDescription = description;
      });

      await SchedulerBinding.instance.endOfFrame;
      await _waitStepDelayOrCancel(_stepDelay);
    }
  }

  void _toggleRun() {
    setState(() {
      _isRunning = !_isRunning;
    });
    if (_isRunning) {
      _signalRunLoop();
    }
  }

  void _nextStep() {
    if (_isRunning) {
      return;
    }
    setState(() {
      _pendingSingleSteps += 1;
    });
    _signalRunLoop();
  }

  void _cancelAndExit() {
    _cancelRequested = true;
    _signalRunLoop();
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final state = _engine.state;
    final stockRowsRemaining = state.stock.cards.length ~/ 10;

    return Scaffold(
      appBar: AppBar(title: Text(widget.args.title)),
      body: Stack(
        children: [
          const Positioned.fill(child: FeltTableBackground()),
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${widget.args.deal.modeLabel} ${widget.args.deal.guaranteeLabel} | '
                      '${widget.args.deal.difficulty.label} | Seed ${widget.args.deal.seed}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 4),
                    Text('Moves: ${state.moves}  Stock: $stockRowsRemaining rows'),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: List.generate(
                      10,
                      (i) => Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: TableauColumnView(
                          columnIndex: i,
                          cards: state.tableau.columns[i],
                          tapEnabled: false,
                          canDragFromIndex: (_) => false,
                          onBuildDragPayload: (_) => DragRunPayload(
                            fromColumn: i,
                            startIndex: 0,
                            cards: const <PlayingCard>[],
                          ),
                          canAcceptDrop: (_) => false,
                          onAcceptDrop: (_) {},
                          onIllegalDrop: () {},
                          onCardTap: (_) {},
                          onColumnTap: () {},
                          onDragStarted: (_) {},
                          onDragCanceled: () {},
                          onDragCompleted: () {},
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Material(
                elevation: 4,
                color: AppPalette.panelIvory.withValues(alpha: 0.96),
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Step $_stepIndex / ${widget.args.steps.length}',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _stepDescription.isEmpty
                              ? 'Waiting...'
                              : _stepDescription,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        if (kDebugMode) ...[
                          const SizedBox(height: 4),
                          Text(
                            'DEV dtoKind: ${_currentStepKind?.name ?? 'n/a'}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            FilledButton.tonalIcon(
                              onPressed: _toggleRun,
                              icon: Icon(
                                _isRunning ? Icons.pause : Icons.play_arrow,
                              ),
                              label: Text(_isRunning ? 'Pause' : 'Play'),
                            ),
                            const SizedBox(width: 8),
                            FilledButton.tonalIcon(
                              onPressed: _isRunning ? null : _nextStep,
                              icon: const Icon(Icons.skip_next),
                              label: const Text('Next'),
                            ),
                            const SizedBox(width: 8),
                            FilledButton.tonal(
                              onPressed: _cancelAndExit,
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
        ],
      ),
    );
  }
}
