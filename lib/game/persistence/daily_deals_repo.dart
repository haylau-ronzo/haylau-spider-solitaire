import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'daily_deals_model.dart';

abstract class DailyDealsRepo {
  ValueListenable<DailyDealsModel> watch();
  DailyDealsModel current();
  Future<DailyDealsModel> load();
  Future<void> save(DailyDealsModel model);
  Future<void> markInProgress(String dateKeyLocal);
  Future<void> markCompleted({
    required String dateKeyLocal,
    required DailyCompletionMetrics metrics,
    required DateTime completedAt,
  });
  Future<void> markAbortedIfNotCompleted(String dateKeyLocal);
}

class InMemoryDailyDealsRepo implements DailyDealsRepo {
  final ValueNotifier<DailyDealsModel> _notifier =
      ValueNotifier<DailyDealsModel>(DailyDealsModel.empty);

  @override
  DailyDealsModel current() => _notifier.value;

  @override
  Future<DailyDealsModel> load() async => _notifier.value;

  @override
  Future<void> save(DailyDealsModel model) async {
    _notifier.value = model;
  }

  @override
  ValueListenable<DailyDealsModel> watch() => _notifier;

  @override
  Future<void> markInProgress(String dateKeyLocal) async {
    final existing = _notifier.value.recordsByDateKey[dateKeyLocal];
    if (existing != null && existing.status == DailyDealStatus.completed) {
      return;
    }
    final next = Map<String, DailyDealRecord>.from(
      _notifier.value.recordsByDateKey,
    );
    next[dateKeyLocal] =
        (existing ??
                DailyDealRecord(
                  dateKeyLocal: dateKeyLocal,
                  status: DailyDealStatus.notStarted,
                ))
            .copyWith(status: DailyDealStatus.inProgress);
    _notifier.value = DailyDealsModel(recordsByDateKey: next);
  }

  @override
  Future<void> markCompleted({
    required String dateKeyLocal,
    required DailyCompletionMetrics metrics,
    required DateTime completedAt,
  }) async {
    final existing = _notifier.value.recordsByDateKey[dateKeyLocal];
    if (existing != null && existing.status == DailyDealStatus.completed) {
      return;
    }

    final next = Map<String, DailyDealRecord>.from(
      _notifier.value.recordsByDateKey,
    );
    next[dateKeyLocal] = DailyDealRecord(
      dateKeyLocal: dateKeyLocal,
      status: DailyDealStatus.completed,
      completedAt: completedAt,
      metrics: metrics,
    );
    _notifier.value = DailyDealsModel(recordsByDateKey: next);
  }

  @override
  Future<void> markAbortedIfNotCompleted(String dateKeyLocal) async {
    final existing = _notifier.value.recordsByDateKey[dateKeyLocal];
    if (existing == null || existing.status == DailyDealStatus.completed) {
      return;
    }
    final next = Map<String, DailyDealRecord>.from(
      _notifier.value.recordsByDateKey,
    )..remove(dateKeyLocal);
    _notifier.value = DailyDealsModel(recordsByDateKey: next);
  }
}

class LocalDailyDealsRepo implements DailyDealsRepo {
  LocalDailyDealsRepo({SharedPreferences? prefs}) : _prefsOverride = prefs;

  static const String _storageKey = 'daily.deals.v1';

  final SharedPreferences? _prefsOverride;
  final ValueNotifier<DailyDealsModel> _notifier =
      ValueNotifier<DailyDealsModel>(DailyDealsModel.empty);

  @override
  DailyDealsModel current() => _notifier.value;

  @override
  Future<DailyDealsModel> load() async {
    final prefs = await _prefs();
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) {
      _notifier.value = DailyDealsModel.empty;
      return _notifier.value;
    }

    try {
      final parsed = jsonDecode(raw) as Map<String, dynamic>;
      _notifier.value = DailyDealsModel.fromJson(parsed);
    } catch (_) {
      _notifier.value = DailyDealsModel.empty;
    }
    return _notifier.value;
  }

  @override
  Future<void> save(DailyDealsModel model) async {
    _notifier.value = model;
    final prefs = await _prefs();
    await prefs.setString(_storageKey, jsonEncode(model.toJson()));
  }

  @override
  ValueListenable<DailyDealsModel> watch() => _notifier;

  @override
  Future<void> markInProgress(String dateKeyLocal) async {
    final existing = _notifier.value.recordsByDateKey[dateKeyLocal];
    if (existing != null && existing.status == DailyDealStatus.completed) {
      return;
    }
    final next = Map<String, DailyDealRecord>.from(
      _notifier.value.recordsByDateKey,
    );
    next[dateKeyLocal] =
        (existing ??
                DailyDealRecord(
                  dateKeyLocal: dateKeyLocal,
                  status: DailyDealStatus.notStarted,
                ))
            .copyWith(status: DailyDealStatus.inProgress);
    await save(DailyDealsModel(recordsByDateKey: next));
  }

  @override
  Future<void> markCompleted({
    required String dateKeyLocal,
    required DailyCompletionMetrics metrics,
    required DateTime completedAt,
  }) async {
    final existing = _notifier.value.recordsByDateKey[dateKeyLocal];
    if (existing != null && existing.status == DailyDealStatus.completed) {
      return;
    }

    final next = Map<String, DailyDealRecord>.from(
      _notifier.value.recordsByDateKey,
    );
    next[dateKeyLocal] = DailyDealRecord(
      dateKeyLocal: dateKeyLocal,
      status: DailyDealStatus.completed,
      completedAt: completedAt,
      metrics: metrics,
    );
    await save(DailyDealsModel(recordsByDateKey: next));
  }

  @override
  Future<void> markAbortedIfNotCompleted(String dateKeyLocal) async {
    final existing = _notifier.value.recordsByDateKey[dateKeyLocal];
    if (existing == null || existing.status == DailyDealStatus.completed) {
      return;
    }
    final next = Map<String, DailyDealRecord>.from(
      _notifier.value.recordsByDateKey,
    )..remove(dateKeyLocal);
    await save(DailyDealsModel(recordsByDateKey: next));
  }

  Future<SharedPreferences> _prefs() async {
    return _prefsOverride ?? SharedPreferences.getInstance();
  }
}
