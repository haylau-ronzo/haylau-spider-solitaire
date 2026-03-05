import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('merge_solvable_solutions supports two-suit map names', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'merge_solutions_2suit_tool_test_',
    );
    addTearDown(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    final generated = File('${tempDir.path}/generated.dart');
    final target = File('${tempDir.path}/target.dart');

    generated.writeAsStringSync('''
import 'solvable_solution_step.dart';

const Map<int, List<SolutionStepDto>> solutionFirst30_2Suit =
    <int, List<SolutionStepDto>>{
      7002: <SolutionStepDto>[SolutionStepDto.deal()],
    };

const Map<int, List<SolutionStepDto>> solutionFull_2Suit =
    <int, List<SolutionStepDto>>{
      7002: <SolutionStepDto>[SolutionStepDto.deal()],
    };
''');

    target.writeAsStringSync('''
import 'solvable_solution_step.dart';

const Map<int, List<SolutionStepDto>> solutionFirst30_2Suit =
    <int, List<SolutionStepDto>>{};

const Map<int, List<SolutionStepDto>> solutionFull_2Suit =
    <int, List<SolutionStepDto>>{};
''');

    final command = Platform.isWindows ? 'cmd' : 'dart';
    final arguments = Platform.isWindows
        ? <String>[
            '/c',
            'dart',
            'run',
            'tool/merge_solvable_solutions.dart',
            '--difficulty=two',
            '--generated=${generated.path}',
            '--target=${target.path}',
            '--apply',
          ]
        : <String>[
            'run',
            'tool/merge_solvable_solutions.dart',
            '--difficulty=two',
            '--generated=${generated.path}',
            '--target=${target.path}',
            '--apply',
          ];

    final result = await Process.run(
      command,
      arguments,
      workingDirectory: Directory.current.path,
    );

    expect(result.exitCode, 0, reason: result.stderr.toString());
    final merged = target.readAsStringSync();
    expect(merged, contains('solutionFirst30_2Suit'));
    expect(merged, contains('solutionFull_2Suit'));
    expect(
      merged,
      contains('7002: <SolutionStepDto>[SolutionStepDto.deal()],'),
    );
  });
}
