import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../game/engine/game_engine.dart';
import '../../game/model/card.dart';
import '../../game/model/deal_source.dart';
import '../../game/solvable/solvable_solution_step.dart';
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
  Completer<void>? _runWaiter;

  Duration get _stepDelay => widget.args.fast
      ? const Duration(milliseconds: 35)
      : const Duration(seconds: 2);

  @override
  void initState() {
    super.initState();
    _engine = GameEngine();
    _engine.newGame(
      difficulty: widget.args.deal.difficulty,
      dealSource: RandomDealSource(widget.args.deal.seed),
    );
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

    bool applied;
    if (step.isDeal) {
      applied = _engine.dealFromStock();
    } else {
      if (!step.isMove ||
          step.fromColumn == null ||
          step.toColumn == null ||
          step.startIndex == null) {
        return false;
      }
      applied = _engine.moveStack(
        step.fromColumn!,
        step.startIndex!,
        step.toColumn!,
      );
    }

    if (!applied) {
      return false;
    }

    if (step.isMove) {
      final after = _stateFingerprint();
      if (before == after) {
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
      final description = _describeSolutionStep(step);
      final ok = _applyStep(step);
      if (!ok) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Preview stopped at step ${i + 1}: $description'),
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
      body: Column(
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
            color: Theme.of(context).colorScheme.surface,
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
    );
  }
}
