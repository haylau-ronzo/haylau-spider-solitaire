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
  final solutionsPath = _stringArg(
    args,
    name: 'solutions',
    fallback: 'lib/game/solvable/solvable_solutions_1suit_verified.dart',
  );
  final apply = args.contains('--apply');

  final seedsFile = File(seedsPath);
  final solutionsFile = File(solutionsPath);

  if (!seedsFile.existsSync()) {
    stderr.writeln('ERROR: seeds file not found: $seedsPath');
    exitCode = 2;
    return;
  }
  if (!solutionsFile.existsSync()) {
    stderr.writeln('ERROR: solutions file not found: $solutionsPath');
    exitCode = 2;
    return;
  }

  final seedsSource = seedsFile.readAsStringSync();
  final solutionsSource = solutionsFile.readAsStringSync();

  late final List<int> dailySeeds;
  late final List<int> randomSeeds;
  late final Set<int> solutionKeys;
  try {
    dailySeeds = _extractIntList(seedsSource, 'dailySolvableSeeds1Suit');
    randomSeeds = _extractIntList(seedsSource, 'randomSolvableSeeds1Suit');
    final prefixMapBody = _extractMapBody(
      solutionsSource,
      'solutionFirst30_1Suit',
    );
    solutionKeys = _extractMapKeys(prefixMapBody);
  } on FormatException catch (e) {
    stderr.writeln('ERROR: ${e.message}');
    exitCode = 2;
    return;
  }

  final filteredDaily = dailySeeds.where(solutionKeys.contains).toList();
  final filteredRandom = randomSeeds.where(solutionKeys.contains).toList();

  final removedDaily = dailySeeds
      .where((s) => !solutionKeys.contains(s))
      .toList();
  final removedRandom = randomSeeds
      .where((s) => !solutionKeys.contains(s))
      .toList();

  stdout.writeln('Prune report (1-suit):');
  stdout.writeln(
    '  daily before/after: ${dailySeeds.length}/${filteredDaily.length}',
  );
  stdout.writeln(
    '  random before/after: ${randomSeeds.length}/${filteredRandom.length}',
  );
  stdout.writeln('  removed daily (${removedDaily.length}): $removedDaily');
  stdout.writeln('  removed random (${removedRandom.length}): $removedRandom');

  if (filteredDaily.isEmpty) {
    stdout.writeln('WARN: dailySolvableSeeds1Suit becomes empty.');
  }
  if (filteredRandom.isEmpty) {
    stdout.writeln('WARN: randomSolvableSeeds1Suit becomes empty.');
  }

  final changed =
      filteredDaily.length != dailySeeds.length ||
      filteredRandom.length != randomSeeds.length;

  if (!changed) {
    stdout.writeln('No changes.');
    return;
  }

  if (!apply) {
    stdout.writeln('Dry run only. Re-run with --apply to write changes.');
    return;
  }

  var updatedSource = seedsSource;
  updatedSource = _replaceIntList(
    updatedSource,
    'dailySolvableSeeds1Suit',
    filteredDaily,
  );
  updatedSource = _replaceIntList(
    updatedSource,
    'randomSolvableSeeds1Suit',
    filteredRandom,
  );

  try {
    seedsFile.writeAsStringSync(updatedSource);
  } on FileSystemException catch (e) {
    stderr.writeln('ERROR: unable to write seeds file: ${e.message}');
    exitCode = 3;
    return;
  }

  stdout.writeln('Applied pruning to: $seedsPath');
}

String _usage() => '''Usage:
  dart run tool/prune_seeds_without_solutions.dart [options]

Options:
  --seeds=<path>      Verified seeds file.
                      Default: lib/game/solvable/solvable_seeds_verified.dart
  --solutions=<path>  Verified solutions file.
                      Default: lib/game/solvable/solvable_solutions_1suit_verified.dart
  --apply             Apply pruning. Without this, dry-run only.
  --help, -h          Show this help.
''';

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
