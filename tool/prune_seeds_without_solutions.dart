import 'dart:io';

void main(List<String> args) {
  if (args.contains('--help') || args.contains('-h')) {
    stdout.write(_usage());
    return;
  }

  final seedsPath = _stringArg(
    args,
    name: 'seeds',
    fallback: 'lib/game/solvable/solvable_seeds_verified.dart',
  );
  final apply = args.contains('--apply');

  final legacySolutions1 = _stringArgOrNull(args, name: 'solutions');
  final solutionPaths = <String, String>{
    '1-suit': _stringArg(
      args,
      name: 'solutions-1',
      fallback:
          legacySolutions1 ??
          'lib/game/solvable/solvable_solutions_1suit_verified.dart',
    ),
    '2-suit': _stringArg(
      args,
      name: 'solutions-2',
      fallback: 'lib/game/solvable/solvable_solutions_2suit_verified.dart',
    ),
    '4-suit': _stringArg(
      args,
      name: 'solutions-4',
      fallback: 'lib/game/solvable/solvable_solutions_4suit_verified.dart',
    ),
  };

  final seedsFile = File(seedsPath);
  if (!seedsFile.existsSync()) {
    stderr.writeln('ERROR: seeds file not found: $seedsPath');
    exitCode = 2;
    return;
  }

  final seedsSource = seedsFile.readAsStringSync();

  final specs = <_PruneSpec>[
    const _PruneSpec(
      label: '1-suit',
      dailyListName: 'dailySolvableSeeds1Suit',
      randomListName: 'randomSolvableSeeds1Suit',
      fullMapName: 'solutionFull_1Suit',
    ),
    const _PruneSpec(
      label: '2-suit',
      dailyListName: 'dailySolvableSeeds2Suit',
      randomListName: 'randomSolvableSeeds2Suit',
      fullMapName: 'solutionFull_2Suit',
    ),
    const _PruneSpec(
      label: '4-suit',
      dailyListName: 'dailySolvableSeeds4Suit',
      randomListName: 'randomSolvableSeeds4Suit',
      fullMapName: 'solutionFull_4Suit',
    ),
  ];

  final results = <_PruneResult>[];

  try {
    for (final spec in specs) {
      final dailySeeds = _extractIntList(seedsSource, spec.dailyListName);
      final randomSeeds = _extractIntList(seedsSource, spec.randomListName);

      final solutionsPath = solutionPaths[spec.label]!;
      final solutionsFile = File(solutionsPath);
      if (!solutionsFile.existsSync()) {
        stdout.writeln(
          'WARN: ${spec.label} solutions file missing: $solutionsPath (skipping prune)',
        );
        results.add(
          _PruneResult.skipped(
            spec: spec,
            dailyBefore: dailySeeds,
            randomBefore: randomSeeds,
          ),
        );
        continue;
      }

      final solutionsSource = solutionsFile.readAsStringSync();
      final fullMapBody = _extractMapBody(solutionsSource, spec.fullMapName);
      final solutionKeys = _extractMapKeys(fullMapBody);

      final filteredDaily = dailySeeds.where(solutionKeys.contains).toList();
      final filteredRandom = randomSeeds.where(solutionKeys.contains).toList();

      final removedDaily = dailySeeds
          .where((seed) => !solutionKeys.contains(seed))
          .toList();
      final removedRandom = randomSeeds
          .where((seed) => !solutionKeys.contains(seed))
          .toList();

      results.add(
        _PruneResult(
          spec: spec,
          skipped: false,
          dailyBefore: dailySeeds,
          randomBefore: randomSeeds,
          dailyAfter: filteredDaily,
          randomAfter: filteredRandom,
          removedDaily: removedDaily,
          removedRandom: removedRandom,
        ),
      );
    }
  } on FormatException catch (e) {
    stderr.writeln('ERROR: ${e.message}');
    exitCode = 2;
    return;
  }

  for (final result in results) {
    stdout.writeln('Prune report (${result.spec.label}):');
    if (result.skipped) {
      stdout.writeln('  skipped (missing solution file)');
      continue;
    }
    stdout.writeln(
      '  daily before/after: ${result.dailyBefore.length}/${result.dailyAfter.length}',
    );
    stdout.writeln(
      '  random before/after: ${result.randomBefore.length}/${result.randomAfter.length}',
    );
    stdout.writeln(
      '  removed daily (${result.removedDaily.length}): ${result.removedDaily}',
    );
    stdout.writeln(
      '  removed random (${result.removedRandom.length}): ${result.removedRandom}',
    );
    if (result.dailyAfter.isEmpty) {
      stdout.writeln('  WARN: ${result.spec.dailyListName} becomes empty.');
    }
    if (result.randomAfter.isEmpty) {
      stdout.writeln('  WARN: ${result.spec.randomListName} becomes empty.');
    }
  }

  final changed = results.any((result) {
    if (result.skipped) {
      return false;
    }
    return result.dailyBefore.length != result.dailyAfter.length ||
        result.randomBefore.length != result.randomAfter.length;
  });

  if (!changed) {
    stdout.writeln('No changes.');
    return;
  }

  if (!apply) {
    stdout.writeln('Dry run only. Re-run with --apply to write changes.');
    return;
  }

  var updatedSource = seedsSource;
  for (final result in results) {
    if (result.skipped) {
      continue;
    }
    updatedSource = _replaceIntList(
      updatedSource,
      result.spec.dailyListName,
      result.dailyAfter,
    );
    updatedSource = _replaceIntList(
      updatedSource,
      result.spec.randomListName,
      result.randomAfter,
    );
  }

  try {
    seedsFile.writeAsStringSync(updatedSource);
  } on FileSystemException catch (e) {
    stderr.writeln('ERROR: unable to write seeds file: ${e.message}');
    exitCode = 3;
    return;
  }

  stdout.writeln('Applied pruning to: $seedsPath');
}

class _PruneSpec {
  const _PruneSpec({
    required this.label,
    required this.dailyListName,
    required this.randomListName,
    required this.fullMapName,
  });

  final String label;
  final String dailyListName;
  final String randomListName;
  final String fullMapName;
}

class _PruneResult {
  const _PruneResult({
    required this.spec,
    required this.skipped,
    required this.dailyBefore,
    required this.randomBefore,
    required this.dailyAfter,
    required this.randomAfter,
    required this.removedDaily,
    required this.removedRandom,
  });

  factory _PruneResult.skipped({
    required _PruneSpec spec,
    required List<int> dailyBefore,
    required List<int> randomBefore,
  }) {
    return _PruneResult(
      spec: spec,
      skipped: true,
      dailyBefore: dailyBefore,
      randomBefore: randomBefore,
      dailyAfter: dailyBefore,
      randomAfter: randomBefore,
      removedDaily: const <int>[],
      removedRandom: const <int>[],
    );
  }

  final _PruneSpec spec;
  final bool skipped;
  final List<int> dailyBefore;
  final List<int> randomBefore;
  final List<int> dailyAfter;
  final List<int> randomAfter;
  final List<int> removedDaily;
  final List<int> removedRandom;
}

String _usage() => '''Usage:
  dart run tool/prune_seeds_without_solutions.dart [options]

Options:
  --seeds=<path>        Verified seeds file.
                        Default: lib/game/solvable/solvable_seeds_verified.dart
  --solutions-1=<path>  1-suit verified solutions file.
                        Default: lib/game/solvable/solvable_solutions_1suit_verified.dart
  --solutions-2=<path>  2-suit verified solutions file.
                        Default: lib/game/solvable/solvable_solutions_2suit_verified.dart
  --solutions-4=<path>  4-suit verified solutions file.
                        Default: lib/game/solvable/solvable_solutions_4suit_verified.dart
  --apply               Apply pruning. Without this, dry-run only.
  --help, -h            Show this help.
''';

String? _stringArgOrNull(List<String> args, {required String name}) {
  final prefix = '--$name=';
  final raw = args.cast<String?>().firstWhere(
    (arg) => arg != null && arg.startsWith(prefix),
    orElse: () => null,
  );
  if (raw == null) {
    return null;
  }
  return raw.substring(prefix.length);
}

String _stringArg(
  List<String> args, {
  required String name,
  required String fallback,
}) {
  final prefix = '--$name=';
  final raw = args.cast<String?>().firstWhere(
    (arg) => arg != null && arg.startsWith(prefix),
    orElse: () => null,
  );
  if (raw == null) {
    return fallback;
  }
  return raw.substring(prefix.length);
}

List<int> _extractIntList(String source, String listName) {
  final exp = RegExp(
    'const\\s+List<int>\\s+$listName\\s*=\\s*<int>\\s*\\[([\\s\\S]*?)\\];',
    multiLine: true,
  );
  final match = exp.firstMatch(source);
  if (match == null) {
    throw FormatException('Could not find List<int> $listName in source.');
  }

  final body = match.group(1) ?? '';
  final valueExp = RegExp(r'-?\d+');
  return valueExp.allMatches(body).map((m) => int.parse(m.group(0)!)).toList();
}

String _extractMapBody(String source, String mapName) {
  final pattern = RegExp(
    'const\\s+Map<int,\\s*List<SolutionStepDto>>\\s+$mapName\\s*=\\s*<int,\\s*List<SolutionStepDto>>\\s*\\{',
  );
  final match = pattern.firstMatch(source);
  if (match == null) {
    throw FormatException('Could not find map declaration for $mapName.');
  }

  final openBrace = source.indexOf('{', match.end - 1);
  if (openBrace < 0) {
    throw FormatException('Malformed map declaration for $mapName.');
  }

  var depth = 0;
  var closeBrace = -1;
  for (var i = openBrace; i < source.length; i++) {
    final ch = source.codeUnitAt(i);
    if (ch == 123) {
      depth++;
    } else if (ch == 125) {
      depth--;
      if (depth == 0) {
        closeBrace = i;
        break;
      }
    }
  }

  if (closeBrace < 0) {
    throw FormatException('Could not find closing brace for $mapName.');
  }

  return source.substring(openBrace + 1, closeBrace);
}

Set<int> _extractMapKeys(String mapBody) {
  final keyExp = RegExp(r'^\s*(\d+)\s*:', multiLine: true);
  return keyExp.allMatches(mapBody).map((m) => int.parse(m.group(1)!)).toSet();
}

String _replaceIntList(String source, String listName, List<int> values) {
  final exp = RegExp(
    'const\\s+List<int>\\s+$listName\\s*=\\s*<int>\\s*\\[[\\s\\S]*?\\];',
    multiLine: true,
  );
  final match = exp.firstMatch(source);
  if (match == null) {
    throw FormatException('Could not replace List<int> $listName in source.');
  }

  final lines = values.map((v) => '  $v,').join('\n');
  final replacement = 'const List<int> $listName = <int>[\n$lines\n];';
  return source.replaceRange(match.start, match.end, replacement);
}
