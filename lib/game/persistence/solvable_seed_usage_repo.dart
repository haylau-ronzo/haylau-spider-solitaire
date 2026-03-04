import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'solvable_seed_usage_model.dart';

abstract class SolvableSeedUsageRepo {
  ValueListenable<SolvableSeedUsageModel> watch();
  SolvableSeedUsageModel current();
  Future<SolvableSeedUsageModel> load();
  Future<void> markDailyUsedSeed1Suit(int seed);
  Future<void> markRandomUsedSeed1Suit(int seed);
  Future<void> clearAll();
}

class InMemorySolvableSeedUsageRepo implements SolvableSeedUsageRepo {
  final ValueNotifier<SolvableSeedUsageModel> _notifier =
      ValueNotifier<SolvableSeedUsageModel>(SolvableSeedUsageModel.empty);

  @override
  SolvableSeedUsageModel current() => _notifier.value;

  @override
  Future<SolvableSeedUsageModel> load() async => _notifier.value;

  @override
  Future<void> markDailyUsedSeed1Suit(int seed) async {
    final current = _notifier.value;
    final next = Set<int>.from(current.dailyUsedSeeds1Suit)..add(seed);
    if (next.length == current.dailyUsedSeeds1Suit.length) {
      return;
    }
    _notifier.value = current.copyWith(dailyUsedSeeds1Suit: next);
  }

  @override
  Future<void> markRandomUsedSeed1Suit(int seed) async {
    final current = _notifier.value;
    final next = Set<int>.from(current.randomUsedSeeds1Suit)..add(seed);
    if (next.length == current.randomUsedSeeds1Suit.length) {
      return;
    }
    _notifier.value = current.copyWith(randomUsedSeeds1Suit: next);
  }

  @override
  Future<void> clearAll() async {
    _notifier.value = SolvableSeedUsageModel.empty;
  }

  @override
  ValueListenable<SolvableSeedUsageModel> watch() => _notifier;
}

class LocalSolvableSeedUsageRepo implements SolvableSeedUsageRepo {
  LocalSolvableSeedUsageRepo({SharedPreferences? prefs})
    : _prefsOverride = prefs;

  static const String _storageKey = 'solvable.seed.usage.v1';

  // Backward-compatibility keys from older formats.
  static const String _legacyJsonKey = 'solvable.seed.usage';
  static const String _legacyDailyListKey = 'solvable.seed.usage.daily1suit';
  static const String _legacyRandomListKey = 'solvable.seed.usage.random1suit';

  final SharedPreferences? _prefsOverride;
  final ValueNotifier<SolvableSeedUsageModel> _notifier =
      ValueNotifier<SolvableSeedUsageModel>(SolvableSeedUsageModel.empty);

  @override
  SolvableSeedUsageModel current() => _notifier.value;

  @override
  Future<SolvableSeedUsageModel> load() async {
    final prefs = await _prefs();
    final v1Raw = prefs.getString(_storageKey);

    if (v1Raw != null && v1Raw.isNotEmpty) {
      try {
        final parsed = jsonDecode(v1Raw) as Map<String, dynamic>;
        _notifier.value = SolvableSeedUsageModel.fromJson(parsed);
      } catch (_) {
        _notifier.value = SolvableSeedUsageModel.empty;
      }
      return _notifier.value;
    }

    final migrated = _loadLegacy(prefs);
    _notifier.value = migrated;

    if (migrated.dailyUsedSeeds1Suit.isNotEmpty ||
        migrated.randomUsedSeeds1Suit.isNotEmpty) {
      await prefs.setString(_storageKey, jsonEncode(migrated.toJson()));
    }

    return _notifier.value;
  }

  @override
  Future<void> markDailyUsedSeed1Suit(int seed) async {
    final current = _notifier.value;
    final next = Set<int>.from(current.dailyUsedSeeds1Suit)..add(seed);
    if (next.length == current.dailyUsedSeeds1Suit.length) {
      return;
    }

    final updated = current.copyWith(dailyUsedSeeds1Suit: next);
    await _save(updated);
  }

  @override
  Future<void> markRandomUsedSeed1Suit(int seed) async {
    final current = _notifier.value;
    final next = Set<int>.from(current.randomUsedSeeds1Suit)..add(seed);
    if (next.length == current.randomUsedSeeds1Suit.length) {
      return;
    }

    final updated = current.copyWith(randomUsedSeeds1Suit: next);
    await _save(updated);
  }

  @override
  Future<void> clearAll() async {
    final prefs = await _prefs();
    _notifier.value = SolvableSeedUsageModel.empty;
    await prefs.remove(_storageKey);
    await prefs.remove(_legacyJsonKey);
    await prefs.remove(_legacyDailyListKey);
    await prefs.remove(_legacyRandomListKey);
  }

  @override
  ValueListenable<SolvableSeedUsageModel> watch() => _notifier;

  SolvableSeedUsageModel _loadLegacy(SharedPreferences prefs) {
    Set<int> parseCsvOrJsonSet(String raw) {
      final trimmed = raw.trim();
      if (trimmed.isEmpty) {
        return <int>{};
      }
      try {
        final decoded = jsonDecode(trimmed);
        if (decoded is List<dynamic>) {
          return decoded.whereType<num>().map((v) => v.toInt()).toSet();
        }
      } catch (_) {
        // Fall back to CSV parsing below.
      }

      return trimmed
          .split(',')
          .map((part) => int.tryParse(part.trim()))
          .whereType<int>()
          .toSet();
    }

    Set<int> parseIntListKey(String key) {
      final list = prefs.getStringList(key);
      if (list != null) {
        return list
            .map((entry) => int.tryParse(entry))
            .whereType<int>()
            .toSet();
      }

      final raw = prefs.getString(key);
      if (raw != null) {
        return parseCsvOrJsonSet(raw);
      }

      return <int>{};
    }

    // Legacy JSON blob migration.
    final legacyJsonRaw = prefs.getString(_legacyJsonKey);
    if (legacyJsonRaw != null && legacyJsonRaw.isNotEmpty) {
      try {
        final parsed = jsonDecode(legacyJsonRaw);
        if (parsed is Map<String, dynamic>) {
          final migrated = SolvableSeedUsageModel(
            dailyUsedSeeds1Suit: _parseLegacyJsonSet(parsed, <String>[
              'dailyUsedSeeds1Suit',
              'dailyUsedSeeds',
              'dailyUsed',
            ]),
            randomUsedSeeds1Suit: _parseLegacyJsonSet(parsed, <String>[
              'randomUsedSeeds1Suit',
              'randomUsedSeeds',
              'randomUsed',
            ]),
          );
          if (migrated.dailyUsedSeeds1Suit.isNotEmpty ||
              migrated.randomUsedSeeds1Suit.isNotEmpty) {
            return migrated;
          }
        }
      } catch (_) {
        // Keep trying other legacy formats.
      }
    }

    final dailyLegacy = parseIntListKey(_legacyDailyListKey);
    final randomLegacy = parseIntListKey(_legacyRandomListKey);

    if (dailyLegacy.isEmpty && randomLegacy.isEmpty) {
      return SolvableSeedUsageModel.empty;
    }

    return SolvableSeedUsageModel(
      dailyUsedSeeds1Suit: dailyLegacy,
      randomUsedSeeds1Suit: randomLegacy,
    );
  }

  Set<int> _parseLegacyJsonSet(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final raw = json[key];
      if (raw is List<dynamic>) {
        return raw.whereType<num>().map((v) => v.toInt()).toSet();
      }
      if (raw is String && raw.isNotEmpty) {
        return raw
            .split(',')
            .map((part) => int.tryParse(part.trim()))
            .whereType<int>()
            .toSet();
      }
    }
    return <int>{};
  }

  Future<void> _save(SolvableSeedUsageModel model) async {
    final prefs = await _prefs();
    _notifier.value = model;
    await prefs.setString(_storageKey, jsonEncode(model.toJson()));
  }

  Future<SharedPreferences> _prefs() async {
    return _prefsOverride ?? SharedPreferences.getInstance();
  }
}
