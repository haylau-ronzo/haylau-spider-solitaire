import 'dart:io';

void main(List<String> args) {
  if (args.contains('--help') || args.contains('-h')) {
    stdout.write(_usage());
    return;
  }

  final spec = _DifficultySpec.fromArg(
    _stringArg(args, name: 'difficulty', fallback: 'one'),
  );
  if (spec == null) {
    stderr.writeln('ERROR: --difficulty must be one|two|four');
    exitCode = 2;
    return;
  }

  final generatedPath = _stringArg(
    args,
    name: 'generated',
    fallback: spec.generatedFallback,
  );
  final targetPath = _stringArg(
    args,
    name: 'target',
    fallback: spec.targetFallback,
  );
  final apply = args.contains('--apply');

  final generatedFile = File(generatedPath);
  final targetFile = File(targetPath);

  if (!generatedFile.existsSync()) {
    stderr.writeln('ERROR: generated file not found: $generatedPath');
    exitCode = 2;
    return;
  }
  if (!targetFile.existsSync()) {
    stderr.writeln('ERROR: target file not found: $targetPath');
    exitCode = 2;
    return;
  }

  final generatedSource = generatedFile.readAsStringSync();
  final targetSource = targetFile.readAsStringSync();

  late final _MapBlock targetPrefix;
  late final _MapBlock targetFull;

  try {
    targetPrefix = _extractRequiredMapBlock(targetSource, spec.prefixMapName);
    targetFull = _extractRequiredMapBlock(targetSource, spec.fullMapName);
  } on FormatException catch (e) {
    stderr.writeln('ERROR: ${e.message}');
    exitCode = 2;
    return;
  }

  final generatedPrefix = _extractOptionalMapBlock(
    generatedSource,
    spec.prefixMapName,
  );
  final generatedFull = _extractOptionalMapBlock(
    generatedSource,
    spec.fullMapName,
  );

  final generatedPrefixEntries = generatedPrefix == null
      ? <int, String>{}
      : _extractEntriesInOrder(generatedPrefix.body);
  final generatedFullEntries = generatedFull == null
      ? <int, String>{}
      : _extractEntriesInOrder(generatedFull.body);

  final prefixResult = _mergeBySeed(
    targetBody: targetPrefix.body,
    generatedEntries: generatedPrefixEntries,
  );
  final fullResult = _mergeBySeed(
    targetBody: targetFull.body,
    generatedEntries: generatedFullEntries,
  );

  _printReport(spec.prefixMapName, prefixResult);
  _printReport(spec.fullMapName, fullResult);

  final changed =
      prefixResult.addedSeeds.isNotEmpty || fullResult.addedSeeds.isNotEmpty;

  if (!changed) {
    stdout.writeln('No changes.');
    return;
  }

  if (!apply) {
    stdout.writeln('Dry run only. Re-run with --apply to write changes.');
    return;
  }

  var updated = targetSource;
  if (targetFull.start > targetPrefix.start) {
    updated = _replaceMapBlock(updated, targetFull, fullResult.mergedBody);
    updated = _replaceMapBlock(updated, targetPrefix, prefixResult.mergedBody);
  } else {
    updated = _replaceMapBlock(updated, targetPrefix, prefixResult.mergedBody);
    updated = _replaceMapBlock(updated, targetFull, fullResult.mergedBody);
  }

  try {
    targetFile.writeAsStringSync(updated);
  } on FileSystemException catch (e) {
    stderr.writeln('ERROR: unable to write target file: ${e.message}');
    exitCode = 3;
    return;
  }

  stdout.writeln('Applied merge to: $targetPath');
}

class _DifficultySpec {
  const _DifficultySpec({
    required this.prefixMapName,
    required this.fullMapName,
    required this.generatedFallback,
    required this.targetFallback,
  });

  final String prefixMapName;
  final String fullMapName;
  final String generatedFallback;
  final String targetFallback;

  static _DifficultySpec? fromArg(String value) {
    final normalized = value.trim().toLowerCase();
    return switch (normalized) {
      'one' => const _DifficultySpec(
        prefixMapName: 'solutionFirst30_1Suit',
        fullMapName: 'solutionFull_1Suit',
        generatedFallback: 'tool/tmp_generated_solutions_1suit.dart',
        targetFallback:
            'lib/game/solvable/solvable_solutions_1suit_verified.dart',
      ),
      'two' => const _DifficultySpec(
        prefixMapName: 'solutionFirst30_2Suit',
        fullMapName: 'solutionFull_2Suit',
        generatedFallback: 'tool/tmp_generated_solutions_2suit.dart',
        targetFallback:
            'lib/game/solvable/solvable_solutions_2suit_verified.dart',
      ),
      'four' => const _DifficultySpec(
        prefixMapName: 'solutionFirst30_4Suit',
        fullMapName: 'solutionFull_4Suit',
        generatedFallback: 'tool/tmp_generated_solutions_4suit.dart',
        targetFallback:
            'lib/game/solvable/solvable_solutions_4suit_verified.dart',
      ),
      _ => null,
    };
  }
}

class _MapBlock {
  const _MapBlock({
    required this.name,
    required this.start,
    required this.end,
    required this.body,
  });

  final String name;
  final int start;
  final int end;
  final String body;
}

class _MergeResult {
  const _MergeResult({
    required this.mergedBody,
    required this.generatedSeeds,
    required this.existingSeeds,
    required this.addedSeeds,
    required this.skippedSeeds,
  });

  final String mergedBody;
  final List<int> generatedSeeds;
  final List<int> existingSeeds;
  final List<int> addedSeeds;
  final List<int> skippedSeeds;
}

_MapBlock _extractRequiredMapBlock(String source, String name) {
  final block = _extractOptionalMapBlock(source, name);
  if (block == null) {
    throw FormatException('Could not find map declaration for $name');
  }
  return block;
}

_MapBlock? _extractOptionalMapBlock(String source, String name) {
  final pattern = RegExp(
    'const\\s+Map<int,\\s*List<SolutionStepDto>>\\s+$name\\s*=\\s*<int,\\s*List<SolutionStepDto>>\\s*\\{',
  );
  final match = pattern.firstMatch(source);
  if (match == null) {
    return null;
  }

  final openBrace = source.indexOf('{', match.end - 1);
  if (openBrace < 0) {
    throw FormatException('Malformed map declaration for $name');
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
    throw FormatException('Could not find closing brace for $name');
  }

  final semicolon = source.indexOf(';', closeBrace);
  if (semicolon < 0) {
    throw FormatException('Could not find terminating semicolon for $name');
  }

  return _MapBlock(
    name: name,
    start: match.start,
    end: semicolon + 1,
    body: source.substring(openBrace + 1, closeBrace),
  );
}

Map<int, String> _extractEntriesInOrder(String mapBody) {
  final result = <int, String>{};
  final seedPattern = RegExp(r'^\s*(\d+)\s*:', multiLine: true);

  final matches = seedPattern.allMatches(mapBody).toList();
  for (var i = 0; i < matches.length; i++) {
    final m = matches[i];
    final seed = int.parse(m.group(1)!);
    final entryStart = m.start;
    final entryEnd = i + 1 < matches.length
        ? matches[i + 1].start
        : mapBody.length;
    final entryRaw = mapBody.substring(entryStart, entryEnd).trimRight();
    final normalized = entryRaw.endsWith(',') ? entryRaw : '$entryRaw,';

    result.putIfAbsent(seed, () => normalized);
  }

  return result;
}

_MergeResult _mergeBySeed({
  required String targetBody,
  required Map<int, String> generatedEntries,
}) {
  final targetEntries = _extractEntriesInOrder(targetBody);

  final existingSeeds = targetEntries.keys.toList();
  final generatedSeeds = generatedEntries.keys.toList();
  final added = <int>[];
  final skipped = <int>[];

  final merged = <int, String>{...targetEntries};

  for (final seed in generatedSeeds) {
    if (merged.containsKey(seed)) {
      skipped.add(seed);
      continue;
    }
    merged[seed] = generatedEntries[seed]!;
    added.add(seed);
  }

  final lines = <String>[];
  for (final entry in merged.entries) {
    final indented = entry.value
        .split('\n')
        .map((line) => line.trimRight().isEmpty ? '' : '  $line')
        .join('\n');
    lines.add(indented);
  }

  final mergedBody = lines.join('\n');

  return _MergeResult(
    mergedBody: mergedBody,
    generatedSeeds: generatedSeeds,
    existingSeeds: existingSeeds,
    addedSeeds: added,
    skippedSeeds: skipped,
  );
}

String _replaceMapBlock(String source, _MapBlock block, String mergedBody) {
  final replacement =
      'const Map<int, List<SolutionStepDto>> ${block.name} =\n'
      '    <int, List<SolutionStepDto>>{\n'
      '$mergedBody\n'
      '};';

  return source.replaceRange(block.start, block.end, replacement);
}

void _printReport(String name, _MergeResult result) {
  stdout.writeln('Merge report ($name):');
  stdout.writeln(
    '  generated keys (${result.generatedSeeds.length}): ${result.generatedSeeds}',
  );
  stdout.writeln(
    '  existing keys (${result.existingSeeds.length}): ${result.existingSeeds}',
  );
  stdout.writeln(
    '  added keys (${result.addedSeeds.length}): ${result.addedSeeds}',
  );
  stdout.writeln('  skipped duplicates: ${result.skippedSeeds.length}');
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

String _usage() => '''Usage:
  dart run tool/merge_solvable_solutions.dart [options]

Options:
  --difficulty=one|two|four  Difficulty map set to merge. Default: one
  --generated=<path>         Generated solutions file.
                             Default by difficulty:
                               one:  tool/tmp_generated_solutions_1suit.dart
                               two:  tool/tmp_generated_solutions_2suit.dart
                               four: tool/tmp_generated_solutions_4suit.dart
  --target=<path>            Verified solutions file.
                             Default by difficulty:
                               one:  lib/game/solvable/solvable_solutions_1suit_verified.dart
                               two:  lib/game/solvable/solvable_solutions_2suit_verified.dart
                               four: lib/game/solvable/solvable_solutions_4suit_verified.dart
  --apply                    Apply changes. Without this, dry-run only.
  --help, -h                 Show this help.
''';
