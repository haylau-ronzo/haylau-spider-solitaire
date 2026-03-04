import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('prunes 1-suit seeds to only those with solution prefixes', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'prune_seeds_without_solutions_tool_test_',
    );
    addTearDown(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    final seeds = File('${tempDir.path}/seeds.dart');
    final solutions = File('${tempDir.path}/solutions.dart');

    seeds.writeAsStringSync('''
const List<int> dailySolvableSeeds1Suit = <int>[111, 222, 9];
const List<int> randomSolvableSeeds1Suit = <int>[333];

const List<int> dailySolvableSeeds2Suit = <int>[7001];
const List<int> randomSolvableSeeds2Suit = <int>[7002];
const List<int> dailySolvableSeeds4Suit = <int>[8001];
const List<int> randomSolvableSeeds4Suit = <int>[8002];
''');

    solutions.writeAsStringSync('''
import 'solvable_solution_step.dart';

const Map<int, List<SolutionStepDto>> solutionFirst30_1Suit =
    <int, List<SolutionStepDto>>{
      9: <SolutionStepDto>[const SolutionStepDto.deal()],
      333: <SolutionStepDto>[const SolutionStepDto.deal()],
    };
''');

    final command = Platform.isWindows ? 'cmd' : 'dart';
    final arguments = Platform.isWindows
        ? <String>[
            '/c',
            'dart',
            'run',
            'tool/prune_seeds_without_solutions.dart',
            '--seeds=${seeds.path}',
            '--solutions=${solutions.path}',
            '--apply',
          ]
        : <String>[
            'run',
            'tool/prune_seeds_without_solutions.dart',
            '--seeds=${seeds.path}',
            '--solutions=${solutions.path}',
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
      contains('const List<int> randomSolvableSeeds1Suit = <int>[\n  333,\n];'),
    );

    expect(
      merged,
      contains('const List<int> dailySolvableSeeds2Suit = <int>[7001];'),
    );
    expect(
      merged,
      contains('const List<int> randomSolvableSeeds2Suit = <int>[7002];'),
    );
    expect(
      merged,
      contains('const List<int> dailySolvableSeeds4Suit = <int>[8001];'),
    );
    expect(
      merged,
      contains('const List<int> randomSolvableSeeds4Suit = <int>[8002];'),
    );
  });
}
