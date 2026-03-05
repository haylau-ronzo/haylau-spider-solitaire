import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'prunes 1/2/4-suit seeds to only those with full proof entries',
    () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'prune_seeds_without_solutions_tool_test_',
      );
      addTearDown(() async {
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
      });

      final seeds = File('${tempDir.path}/seeds.dart');
      final solutions1 = File('${tempDir.path}/solutions_1.dart');
      final solutions2 = File('${tempDir.path}/solutions_2.dart');
      final solutions4 = File('${tempDir.path}/solutions_4.dart');

      seeds.writeAsStringSync('''
const List<int> dailySolvableSeeds1Suit = <int>[111, 222, 9];
const List<int> randomSolvableSeeds1Suit = <int>[333];

const List<int> dailySolvableSeeds2Suit = <int>[7001];
const List<int> randomSolvableSeeds2Suit = <int>[7002, 7003];
const List<int> dailySolvableSeeds4Suit = <int>[8001];
const List<int> randomSolvableSeeds4Suit = <int>[8002];
''');

      solutions1.writeAsStringSync('''
import 'solvable_solution_step.dart';

const Map<int, List<SolutionStepDto>> solutionFull_1Suit =
    <int, List<SolutionStepDto>>{
      9: <SolutionStepDto>[const SolutionStepDto.deal()],
      333: <SolutionStepDto>[const SolutionStepDto.deal()],
    };
''');

      solutions2.writeAsStringSync('''
import 'solvable_solution_step.dart';

const Map<int, List<SolutionStepDto>> solutionFull_2Suit =
    <int, List<SolutionStepDto>>{
      7002: <SolutionStepDto>[const SolutionStepDto.deal()],
    };
''');

      solutions4.writeAsStringSync('''
import 'solvable_solution_step.dart';

const Map<int, List<SolutionStepDto>> solutionFull_4Suit =
    <int, List<SolutionStepDto>>{};
''');

      final command = Platform.isWindows ? 'cmd' : 'dart';
      final arguments = Platform.isWindows
          ? <String>[
              '/c',
              'dart',
              'run',
              'tool/prune_seeds_without_solutions.dart',
              '--seeds=${seeds.path}',
              '--solutions-1=${solutions1.path}',
              '--solutions-2=${solutions2.path}',
              '--solutions-4=${solutions4.path}',
              '--apply',
            ]
          : <String>[
              'run',
              'tool/prune_seeds_without_solutions.dart',
              '--seeds=${seeds.path}',
              '--solutions-1=${solutions1.path}',
              '--solutions-2=${solutions2.path}',
              '--solutions-4=${solutions4.path}',
              '--apply',
            ];

      final result = await Process.run(
        command,
        arguments,
        workingDirectory: Directory.current.path,
      );

      expect(result.exitCode, 0, reason: result.stderr.toString());

      final merged = seeds.readAsStringSync();
      expect(
        merged,
        contains('const List<int> dailySolvableSeeds1Suit = <int>[\n  9,\n];'),
      );
      expect(
        merged,
        contains(
          'const List<int> randomSolvableSeeds1Suit = <int>[\n  333,\n];',
        ),
      );

      expect(
        merged,
        contains('const List<int> dailySolvableSeeds2Suit = <int>[\n\n];'),
      );
      expect(
        merged,
        contains(
          'const List<int> randomSolvableSeeds2Suit = <int>[\n  7002,\n];',
        ),
      );
      expect(
        merged,
        contains('const List<int> dailySolvableSeeds4Suit = <int>[\n\n];'),
      );
      expect(
        merged,
        contains('const List<int> randomSolvableSeeds4Suit = <int>[\n\n];'),
      );
    },
  );
}
