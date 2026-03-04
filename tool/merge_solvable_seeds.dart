import 'dart:io';

void main(List<String> args) {
  if (args.contains('--help') || args.contains('-h')) {
    stdout.write(_usage());
    return;
  }

  final generatedPath = _stringArg(
    args,
    name: 'generated',
    fallback: 'tool/tmp_generated_seeds.dart',
  );
  final targetPath = _stringArg(
    args,
    name: 'target',
    fallback: 'lib/game/solvable/solvable_seeds_verified.dart',
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

  final specs = <_PoolSpec>[
    const _PoolSpec(
      dailyName: 'dailySolvableSeeds1Suit',
      randomName: 'randomSolvableSeeds1Suit',
      label: '1-suit',
    ),
    const _PoolSpec(
      dailyName: 'dailySolvableSeeds2Suit',
      randomName: 'randomSolvableSeeds2Suit',
      label: '2-suit',
    ),
    const _PoolSpec(
      dailyName: 'dailySolvableSeeds4Suit',
      randomName: 'randomSolvableSeeds4Suit',
      label: '4-suit',
    ),
  ];

  final generatedPools = <String, List<int>>{};
  final targetPools = <String, List<int>>{};

  try {
    for (final spec in specs) {
      final generatedDaily = _extractIntListOrNull(
        generatedSource,
        spec.dailyName,
      );
      if (generatedDaily == null) {
        stdout.writeln(
          'WARN: missing ${spec.dailyName} in generated; treating as empty.',
        );
      }
      generatedPools[spec.dailyName] = generatedDaily ?? <int>[];

      final generatedRandom = _extractIntListOrNull(
        generatedSource,
        spec.randomName,
      );
      if (generatedRandom == null) {
        stdout.writeln(
          'WARN: missing ${spec.randomName} in generated; treating as empty.',
        );
      }
      generatedPools[spec.randomName] = generatedRandom ?? <int>[];

      targetPools[spec.dailyName] = _extractIntList(
        targetSource,
        spec.dailyName,
      );
      targetPools[spec.randomName] = _extractIntList(
        targetSource,
        spec.randomName,
      );
    }
  } on FormatException catch (e) {
    stderr.writeln('ERROR: ${e.message}');
    exitCode = 2;
    return;
  }

  final generatedTotal = generatedPools.values.fold<int>(
    0,
    (sum, values) => sum + values.length,
  );
  if (generatedTotal == 0) {
    stdout.writeln(
      'Generated file contains zero seeds across all pools; no changes.',
    );
    return;
  }

  for (final spec in specs) {
    final targetDaily = targetPools[spec.dailyName]!;
    final targetRandom = targetPools[spec.randomName]!;

    final dailySet = targetDaily.toSet();
    final randomSet = targetRandom.toSet();

    if (dailySet.length != targetDaily.length) {
      stderr.writeln(
        'ERROR: ${spec.dailyName} in target has duplicates; refusing merge.',
      );
      exitCode = 3;
      return;
    }
    if (randomSet.length != targetRandom.length) {
      stderr.writeln(
        'ERROR: ${spec.randomName} in target has duplicates; refusing merge.',
      );
      exitCode = 3;
      return;
    }
    final overlap = dailySet.intersection(randomSet);
    if (overlap.isNotEmpty) {
      stderr.writeln(
        'ERROR: target overlap exists in ${spec.label} pools; refusing merge: '
        '${overlap.toList()..sort()}',
      );
      exitCode = 3;
      return;
    }
  }

  final mergedPools = <String, List<int>>{};
  final reports = <_MergeReport>[];

  for (final spec in specs) {
    final targetDaily = targetPools[spec.dailyName]!;
    final targetRandom = targetPools[spec.randomName]!;
    final generatedDaily = generatedPools[spec.dailyName]!;
    final generatedRandom = generatedPools[spec.randomName]!;

    final mergedDaily = List<int>.from(targetDaily);
    final mergedRandom = List<int>.from(targetRandom);
    final dailySet = <int>{...targetDaily};
    final randomSet = <int>{...targetRandom};

    final addedDaily = <int>[];
    final addedRandom = <int>[];
    final skippedDailyDuplicate = <int>[];
    final skippedRandomDuplicate = <int>[];
    final skippedDailyOverlap = <int>[];
    final skippedRandomOverlap = <int>[];

    for (final seed in generatedDaily) {
      if (dailySet.contains(seed)) {
        skippedDailyDuplicate.add(seed);
        continue;
      }
      if (randomSet.contains(seed)) {
        skippedDailyOverlap.add(seed);
        continue;
      }
      mergedDaily.add(seed);
      dailySet.add(seed);
      addedDaily.add(seed);
    }

    for (final seed in generatedRandom) {
      if (randomSet.contains(seed)) {
        skippedRandomDuplicate.add(seed);
        continue;
      }
      if (dailySet.contains(seed)) {
        skippedRandomOverlap.add(seed);
        continue;
      }
      mergedRandom.add(seed);
      randomSet.add(seed);
      addedRandom.add(seed);
    }

    final mergedOverlap = dailySet.intersection(randomSet);
    if (mergedOverlap.isNotEmpty) {
      stderr.writeln(
        'ERROR: Merge produced ${spec.label} daily/random overlap. '
        'Cannot satisfy invariants without deleting existing seeds.',
      );
      exitCode = 4;
      return;
    }

    mergedPools[spec.dailyName] = mergedDaily;
    mergedPools[spec.randomName] = mergedRandom;

    reports.add(
      _MergeReport(
        label: spec.label,
        generatedDailyCount: generatedDaily.length,
        generatedRandomCount: generatedRandom.length,
        targetDailyCount: targetDaily.length,
        targetRandomCount: targetRandom.length,
        finalDailyCount: mergedDaily.length,
        finalRandomCount: mergedRandom.length,
        addedDaily: addedDaily,
        addedRandom: addedRandom,
        skippedDailyDuplicate: skippedDailyDuplicate,
        skippedRandomDuplicate: skippedRandomDuplicate,
        skippedDailyOverlap: skippedDailyOverlap,
        skippedRandomOverlap: skippedRandomOverlap,
      ),
    );
  }

  for (final report in reports) {
    _printReport(report);
  }

  final changed = reports.any(
    (r) => r.addedDaily.isNotEmpty || r.addedRandom.isNotEmpty,
  );

  if (!changed) {
    stdout.writeln('No changes to apply.');
    return;
  }

  if (!apply) {
    stdout.writeln('Dry run only. Re-run with --apply to write changes.');
    return;
  }

  var updatedTarget = targetSource;
  for (final spec in specs) {
    updatedTarget = _replaceIntList(
      updatedTarget,
      spec.dailyName,
      mergedPools[spec.dailyName]!,
    );
    updatedTarget = _replaceIntList(
      updatedTarget,
      spec.randomName,
      mergedPools[spec.randomName]!,
    );
  }

  targetFile.writeAsStringSync(updatedTarget);
  stdout.writeln('Applied merge to: $targetPath');
}

class _PoolSpec {
  const _PoolSpec({
    required this.dailyName,
    required this.randomName,
    required this.label,
  });

  final String dailyName;
  final String randomName;
  final String label;
}

class _MergeReport {
  const _MergeReport({
    required this.label,
    required this.generatedDailyCount,
    required this.generatedRandomCount,
    required this.targetDailyCount,
    required this.targetRandomCount,
    required this.finalDailyCount,
    required this.finalRandomCount,
    required this.addedDaily,
    required this.addedRandom,
    required this.skippedDailyDuplicate,
    required this.skippedRandomDuplicate,
    required this.skippedDailyOverlap,
    required this.skippedRandomOverlap,
  });

  final String label;
  final int generatedDailyCount;
  final int generatedRandomCount;
  final int targetDailyCount;
  final int targetRandomCount;
  final int finalDailyCount;
  final int finalRandomCount;
  final List<int> addedDaily;
  final List<int> addedRandom;
  final List<int> skippedDailyDuplicate;
  final List<int> skippedRandomDuplicate;
  final List<int> skippedDailyOverlap;
  final List<int> skippedRandomOverlap;
}

String _usage() => '''Usage:
  dart run tool/merge_solvable_seeds.dart [options]

Options:
  --generated=<path>  Generated seed file.
                      Default: tool/tmp_generated_seeds.dart
  --target=<path>     Tool-owned verified pools file.
                      Default: lib/game/solvable/solvable_seeds_verified.dart
  --apply             Apply changes to target. Without this, dry-run only.
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

List<int>? _extractIntListOrNull(String source, String listName) {
  final exp = RegExp(
    'const\\s+List<int>\\s+$listName\\s*=\\s*<int>\\s*\\[([\\s\\S]*?)\\];',
    multiLine: true,
  );
  final match = exp.firstMatch(source);
  if (match == null) {
    return null;
  }

  final body = match.group(1) ?? '';
  final valueExp = RegExp(r'-?\d+');
  return valueExp.allMatches(body).map((m) => int.parse(m.group(0)!)).toList();
}

String _replaceIntList(String source, String listName, List<int> values) {
  final exp = RegExp(
    'const\\s+List<int>\\s+$listName\\s*=\\s*<int>\\s*\\[[\\s\\S]*?\\];',
    multiLine: true,
  );

  final replacement =
      'const List<int> $listName = <int>[\n'
      '${values.map((v) => '  $v,').join('\n')}\n'
      '];';

  final match = exp.firstMatch(source);
  if (match == null) {
    throw FormatException('Could not replace List<int> $listName in target.');
  }

  return source.replaceRange(match.start, match.end, replacement);
}

void _printReport(_MergeReport report) {
  stdout.writeln('Merge report (${report.label}):');
  stdout.writeln(
    '  generated daily/random: ${report.generatedDailyCount}/${report.generatedRandomCount}',
  );
  stdout.writeln(
    '  target daily/random:    ${report.targetDailyCount}/${report.targetRandomCount}',
  );
  stdout.writeln(
    '  final daily/random:     ${report.finalDailyCount}/${report.finalRandomCount}',
  );
  stdout.writeln('  added daily:            ${report.addedDaily.length}');
  if (report.addedDaily.isNotEmpty) {
    stdout.writeln('    values: ${report.addedDaily}');
  }
  stdout.writeln('  added random:           ${report.addedRandom.length}');
  if (report.addedRandom.isNotEmpty) {
    stdout.writeln('    values: ${report.addedRandom}');
  }

  stdout.writeln(
    '  skipped daily duplicate: ${report.skippedDailyDuplicate.length}',
  );
  if (report.skippedDailyDuplicate.isNotEmpty) {
    stdout.writeln('    values: ${report.skippedDailyDuplicate}');
  }

  stdout.writeln(
    '  skipped random duplicate: ${report.skippedRandomDuplicate.length}',
  );
  if (report.skippedRandomDuplicate.isNotEmpty) {
    stdout.writeln('    values: ${report.skippedRandomDuplicate}');
  }

  stdout.writeln(
    '  skipped daily overlap-with-random: ${report.skippedDailyOverlap.length}',
  );
  if (report.skippedDailyOverlap.isNotEmpty) {
    stdout.writeln('    WARNING values: ${report.skippedDailyOverlap}');
  }

  stdout.writeln(
    '  skipped random overlap-with-daily: ${report.skippedRandomOverlap.length}',
  );
  if (report.skippedRandomOverlap.isNotEmpty) {
    stdout.writeln('    WARNING values: ${report.skippedRandomOverlap}');
  }
}
