class SolutionStepDto {
  const SolutionStepDto._({
    required this.kind,
    this.fromColumn,
    this.toColumn,
    this.startIndex,
    this.movedLength,
  });

  const SolutionStepDto.move({
    required int fromColumn,
    required int toColumn,
    required int startIndex,
    int? movedLength,
  }) : this._(
         kind: SolutionStepKind.move,
         fromColumn: fromColumn,
         toColumn: toColumn,
         startIndex: startIndex,
         movedLength: movedLength,
       );

  const SolutionStepDto.deal() : this._(kind: SolutionStepKind.deal);

  final SolutionStepKind kind;
  final int? fromColumn;
  final int? toColumn;
  final int? startIndex;
  final int? movedLength;

  bool get isMove => kind == SolutionStepKind.move;
  bool get isDeal => kind == SolutionStepKind.deal;
}

enum SolutionStepKind { move, deal }
