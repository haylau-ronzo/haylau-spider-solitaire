import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'merge_solvable_solutions appends new keys and skips duplicates',
    () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'merge_solvable_solutions_tool_test_',
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

const Map<int, List<SolutionStepDto>> solutionFirst30_1Suit =
    <int, List<SolutionStepDto>>{
      9: <SolutionStepDto>[SolutionStepDto.move(fromColumn: 9, toColumn: 9, startIndex: 9)],
      29: <SolutionStepDto>[SolutionStepDto.deal()],
    };
''');

      target.writeAsStringSync('''
import 'solvable_solution_step.dart';

const Map<int, List<SolutionStepDto>> solutionFirst30_1Suit =
    <int, List<SolutionStepDto>>{
      9: <SolutionStepDto>[SolutionStepDto.deal()],
    };

const Map<int, List<SolutionStepDto>> solutionFull_1Suit =
    <int, List<SolutionStepDto>>{
      9: <SolutionStepDto>[SolutionStepDto.deal()],
    };
''');

      final command = Platform.isWindows ? 'cmd' : 'dart';
      final arguments = Platform.isWindows
          ? <String>[
              '/c',
              'dart',
              'run',
              'tool/merge_solvable_solutions.dart',
              '--generated=${generated.path}',
              '--target=${target.path}',
              '--apply',
            ]
          : <String>[
              'run',
              'tool/merge_solvable_solutions.dart',
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

      final stdoutText = result.stdout.toString();
      expect(stdoutText, contains('Merge report (solutionFirst30_1Suit):'));
      expect(stdoutText, contains('added keys (1): [29]'));
      expect(stdoutText, contains('skipped duplicates: 1'));
      expect(stdoutText, contains('Merge report (solutionFull_1Suit):'));

      final merged = target.readAsStringSync();
      expect(
        merged,
        contains('9: <SolutionStepDto>[SolutionStepDto.deal()],'),
        reason: 'existing seed 9 must not be overwritten',
      );
      expect(
        merged,
        contains('29: <SolutionStepDto>[SolutionStepDto.deal()],'),
        reason: 'new seed 29 should be appended',
      );
      expect(
        merged,
        contains('const Map<int, List<SolutionStepDto>> solutionFull_1Suit ='),
        reason:
            'missing generated full map should leave target full map intact',
      );
      expect(merged, contains('solutionFull_1Suit'));
      expect(
        merged,
        isNot(
          contains(
            'SolutionStepDto.move(fromColumn: 9, toColumn: 9, startIndex: 9)',
          ),
        ),
        reason:
            'duplicate seed 9 from generated must not overwrite existing target entry',
      );
    },
  );

  test(
    'merge_solvable_solutions can append into empty baseline target',
    () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'merge_solvable_solutions_tool_test_empty_',
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

const Map<int, List<SolutionStepDto>> solutionFirst30_1Suit =
    <int, List<SolutionStepDto>>{
      29: <SolutionStepDto>[SolutionStepDto.deal()],
    };
''');

      target.writeAsStringSync('''
import 'solvable_solution_step.dart';

const Map<int, List<SolutionStepDto>> solutionFirst30_1Suit =
    <int, List<SolutionStepDto>>{};

const Map<int, List<SolutionStepDto>> solutionFull_1Suit =
    <int, List<SolutionStepDto>>{};
''');

      final command = Platform.isWindows ? 'cmd' : 'dart';
      final arguments = Platform.isWindows
          ? <String>[
              '/c',
              'dart',
              'run',
              'tool/merge_solvable_solutions.dart',
              '--generated=${generated.path}',
              '--target=${target.path}',
              '--apply',
            ]
          : <String>[
              'run',
              'tool/merge_solvable_solutions.dart',
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
      expect(
        merged,
        contains('29: <SolutionStepDto>[SolutionStepDto.deal()],'),
      );
    },
  );
}
