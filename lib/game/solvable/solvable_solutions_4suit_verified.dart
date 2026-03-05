// ignore_for_file: unnecessary_const
import 'solvable_solution_step.dart';
import 'verified_solvable_data_override.dart';

// BEGIN GENERATED VERIFIED DATA
// Tool-owned verified solution prefixes. Safe to replace using merge tools.

const Map<int, List<SolutionStepDto>> solutionFirst30_4Suit =
    <int, List<SolutionStepDto>>{};

const Map<int, List<SolutionStepDto>> solutionFull_4Suit =
    <int, List<SolutionStepDto>>{};

// END GENERATED VERIFIED DATA

List<SolutionStepDto>? verifiedSolutionPrefixForSeed4Suit(int seed) {
  if (ignoreVerifiedSolvableData) {
    return null;
  }
  return solutionFirst30_4Suit[seed];
}

List<SolutionStepDto>? verifiedFullSolutionForSeed4Suit(int seed) {
  if (ignoreVerifiedSolvableData) {
    return null;
  }
  return solutionFull_4Suit[seed];
}
