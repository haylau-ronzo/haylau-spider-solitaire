import '../engine/move_validator.dart';
import '../engine_core/spider_engine_core.dart';
import '../model/difficulty.dart';
import '../model/game_state.dart';
import 'solvable_solution_step.dart';

class SolutionStepApplyResult {
  const SolutionStepApplyResult({
    required this.applied,
    required this.nextState,
    required this.reason,
    required this.effectiveStartIndex,
    required this.effectiveMovedLength,
  });

  final bool applied;
  final GameState nextState;
  final String? reason;
  final int? effectiveStartIndex;
  final int? effectiveMovedLength;
}

const MoveValidator _replayValidator = MoveValidator();

SolutionStepApplyResult applyStrictSolutionStep({
  required GameState state,
  required SolutionStepDto step,
}) {
  if (step.isDeal) {
    final dealt = SpiderEngineCore.tryDealFromStock(
      state,
      unrestrictedDealRule: false,
      validator: _replayValidator,
    );
    if (dealt == null) {
      final reason =
          SpiderEngineCore.canDealFromStock(state, unrestrictedDealRule: false)
          ? 'deal action rejected'
          : 'deal not allowed by strict rules';
      return SolutionStepApplyResult(
        applied: false,
        nextState: state,
        reason: reason,
        effectiveStartIndex: null,
        effectiveMovedLength: null,
      );
    }

    return SolutionStepApplyResult(
      applied: true,
      nextState: dealt,
      reason: null,
      effectiveStartIndex: null,
      effectiveMovedLength: null,
    );
  }

  if (!step.isMove ||
      step.fromColumn == null ||
      step.toColumn == null ||
      step.startIndex == null) {
    return SolutionStepApplyResult(
      applied: false,
      nextState: state,
      reason: 'invalid move dto',
      effectiveStartIndex: null,
      effectiveMovedLength: null,
    );
  }

  final move = SpiderEngineCore.tryMoveStack(
    state,
    fromColumn: step.fromColumn!,
    startIndex: step.startIndex!,
    toColumn: step.toColumn!,
    validator: _replayValidator,
  );
  if (!move.didMove) {
    return SolutionStepApplyResult(
      applied: false,
      nextState: state,
      reason: move.failureReason ?? 'move rejected',
      effectiveStartIndex: move.effectiveStartIndex,
      effectiveMovedLength: move.movedLength,
    );
  }

  if (step.movedLength != null && move.movedLength != step.movedLength) {
    return SolutionStepApplyResult(
      applied: false,
      nextState: state,
      reason:
          'movedLength mismatch expected=${step.movedLength} actual=${move.movedLength}',
      effectiveStartIndex: move.effectiveStartIndex,
      effectiveMovedLength: move.movedLength,
    );
  }

  return SolutionStepApplyResult(
    applied: true,
    nextState: move.state,
    reason: null,
    effectiveStartIndex: move.effectiveStartIndex,
    effectiveMovedLength: move.movedLength,
  );
}

String? strictReplayValidationError({
  required int seed,
  required Difficulty difficulty,
  required List<SolutionStepDto> steps,
}) {
  var state = SpiderEngineCore.buildInitialState(
    seed: seed,
    difficulty: difficulty,
  );

  for (var i = 0; i < steps.length; i++) {
    final result = applyStrictSolutionStep(state: state, step: steps[i]);
    if (!result.applied) {
      return 'step ${i + 1}: ${result.reason ?? 'rejected'}';
    }
    state = result.nextState;
  }

  return null;
}
