import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'stats_model.dart';

abstract class StatsRepo {
  ValueListenable<StatsModel> watch();
  StatsModel current();
  Future<StatsModel> loadStats();
  Future<void> save(StatsModel stats);
}

class InMemoryStatsRepo implements StatsRepo {
  final ValueNotifier<StatsModel> _notifier = ValueNotifier<StatsModel>(
    StatsModel.empty,
  );

  @override
  StatsModel current() => _notifier.value;

  @override
  Future<StatsModel> loadStats() async => _notifier.value;

  @override
  Future<void> save(StatsModel stats) async {
    _notifier.value = stats;
  }

  @override
  ValueListenable<StatsModel> watch() => _notifier;
}

class LocalStatsRepo implements StatsRepo {
  LocalStatsRepo({SharedPreferences? prefs}) : _prefsOverride = prefs;

  static const String _storageKey = 'stats.v1';

  final SharedPreferences? _prefsOverride;
  final ValueNotifier<StatsModel> _notifier = ValueNotifier<StatsModel>(
    StatsModel.empty,
  );

  @override
  StatsModel current() => _notifier.value;

  @override
  Future<StatsModel> loadStats() async {
    final prefs = await _prefs();
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) {
      _notifier.value = StatsModel.empty;
      return _notifier.value;
    }

    try {
      final parsed = jsonDecode(raw) as Map<String, dynamic>;
      _notifier.value = StatsModel.fromJson(parsed);
    } catch (_) {
      _notifier.value = StatsModel.empty;
    }
    return _notifier.value;
  }

  @override
  Future<void> save(StatsModel stats) async {
    _notifier.value = stats;
    final prefs = await _prefs();
    await prefs.setString(_storageKey, jsonEncode(stats.toJson()));
  }

  @override
  ValueListenable<StatsModel> watch() => _notifier;

  Future<SharedPreferences> _prefs() async {
    return _prefsOverride ?? SharedPreferences.getInstance();
  }
}
