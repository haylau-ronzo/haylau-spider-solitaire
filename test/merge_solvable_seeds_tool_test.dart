import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('merge tool accepts generated file with only 1-suit lists', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'merge_solvable_seeds_tool_test_',
    );
    addTearDown(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    final generated = File('${tempDir.path}/generated.dart');
    final target = File('${tempDir.path}/target.dart');

    generated.writeAsStringSync('''
const List<int> dailySolvableSeeds1Suit = <int>[1, 2];
const List<int> randomSolvableSeeds1Suit = <int>[3, 4];
''');

    target.writeAsStringSync('''
const List<int> dailySolvableSeeds1Suit = <int>[10];
const List<int> randomSolvableSeeds1Suit = <int>[20];

const List<int> dailySolvableSeeds2Suit = <int>[30];
const List<int> randomSolvableSeeds2Suit = <int>[40];

const List<int> dailySolvableSeeds4Suit = <int>[50];
const List<int> randomSolvableSeeds4Suit = <int>[60];
''');

    final command = Platform.isWindows ? 'cmd' : 'dart';
    final arguments = Platform.isWindows
        ? <String>[
            '/c',
            'dart',
            'run',
            'tool/merge_solvable_seeds.dart',
            '--generated=${generated.path}',
            '--target=${target.path}',
            '--apply',
          ]
        : <String>[
            'run',
            'tool/merge_solvable_seeds.dart',
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
    expect(
      stdoutText,
      contains(
        'WARN: missing dailySolvableSeeds2Suit in generated; treating as empty.',
      ),
    );
    expect(
      stdoutText,
      contains(
        'WARN: missing randomSolvableSeeds2Suit in generated; treating as empty.',
      ),
    );
    expect(
      stdoutText,
      contains(
        'WARN: missing dailySolvableSeeds4Suit in generated; treating as empty.',
      ),
    );
    expect(
      stdoutText,
      contains(
        'WARN: missing randomSolvableSeeds4Suit in generated; treating as empty.',
      ),
    );

    final merged = target.readAsStringSync();

    List<int> parse(String name) {
      final exp = RegExp(
        'const\\s+List<int>\\s+$name\\s*=\\s*<int>\\s*\\[([\\s\\S]*?)\\];',
      );
      final match = exp.firstMatch(merged);
      expect(match, isNotNull);
      final body = match!.group(1)!;
      final nums = RegExp(
        '-?\\d+',
      ).allMatches(body).map((m) => int.parse(m.group(0)!)).toList();
      return nums;
    }

    expect(parse('dailySolvableSeeds1Suit'), <int>[10, 1, 2]);
    expect(parse('randomSolvableSeeds1Suit'), <int>[20, 3, 4]);

    expect(parse('dailySolvableSeeds2Suit'), <int>[30]);
    expect(parse('randomSolvableSeeds2Suit'), <int>[40]);
    expect(parse('dailySolvableSeeds4Suit'), <int>[50]);
    expect(parse('randomSolvableSeeds4Suit'), <int>[60]);
  });

  test('merge tool can append into empty baseline target', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'merge_solvable_seeds_tool_test_empty_',
    );
    addTearDown(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    final generated = File('${tempDir.path}/generated.dart');
    final target = File('${tempDir.path}/target.dart');

    generated.writeAsStringSync('''
const List<int> dailySolvableSeeds1Suit = <int>[9];
const List<int> randomSolvableSeeds1Suit = <int>[29, 33];
''');

    target.writeAsStringSync('''
const List<int> dailySolvableSeeds1Suit = <int>[];
const List<int> randomSolvableSeeds1Suit = <int>[];
const List<int> dailySolvableSeeds2Suit = <int>[];
const List<int> randomSolvableSeeds2Suit = <int>[];
const List<int> dailySolvableSeeds4Suit = <int>[];
const List<int> randomSolvableSeeds4Suit = <int>[];
''');

    final command = Platform.isWindows ? 'cmd' : 'dart';
    final arguments = Platform.isWindows
        ? <String>[
            '/c',
            'dart',
            'run',
            'tool/merge_solvable_seeds.dart',
            '--generated=${generated.path}',
            '--target=${target.path}',
            '--apply',
          ]
        : <String>[
            'run',
            'tool/merge_solvable_seeds.dart',
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
      contains('const List<int> dailySolvableSeeds1Suit = <int>['),
    );
    expect(merged, contains('  9,'));
    expect(
      merged,
      contains('const List<int> randomSolvableSeeds1Suit = <int>['),
    );
    expect(merged, contains('  29,'));
    expect(merged, contains('  33,'));
  });
}
