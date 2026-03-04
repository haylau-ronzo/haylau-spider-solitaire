import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../game/solvable/verified_solvable_data_override.dart';
import 'settings_model.dart';

abstract class SettingsRepo {
  ValueListenable<SettingsModel> watch();
  SettingsModel current();
  Future<SettingsModel> loadSettings();
  Future<void> saveSettings(SettingsModel settings);
}

class InMemorySettingsRepo implements SettingsRepo {
  final ValueNotifier<SettingsModel> _notifier = ValueNotifier<SettingsModel>(
    SettingsModel.defaults,
  );

  @override
  SettingsModel current() => _notifier.value;

  @override
  Future<SettingsModel> loadSettings() async {
    setIgnoreVerifiedSolvableData(_notifier.value.ignoreVerifiedSolvableData);
    return _notifier.value;
  }

  @override
  Future<void> saveSettings(SettingsModel settings) async {
    _notifier.value = settings;
    setIgnoreVerifiedSolvableData(settings.ignoreVerifiedSolvableData);
  }

  @override
  ValueListenable<SettingsModel> watch() => _notifier;
}

class LocalSettingsRepo implements SettingsRepo {
  LocalSettingsRepo({SharedPreferences? prefs}) : _prefsOverride = prefs;

  static const String _storageKey = 'app.settings.v1';

  final SharedPreferences? _prefsOverride;
  final ValueNotifier<SettingsModel> _notifier = ValueNotifier<SettingsModel>(
    SettingsModel.defaults,
  );

  @override
  SettingsModel current() => _notifier.value;

  @override
  Future<SettingsModel> loadSettings() async {
    final prefs = await _prefs();
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) {
      _notifier.value = SettingsModel.defaults;
      setIgnoreVerifiedSolvableData(_notifier.value.ignoreVerifiedSolvableData);
      return _notifier.value;
    }

    try {
      final parsed = jsonDecode(raw) as Map<String, dynamic>;
      _notifier.value = SettingsModel.fromJson(parsed);
    } catch (_) {
      _notifier.value = SettingsModel.defaults;
    }

    setIgnoreVerifiedSolvableData(_notifier.value.ignoreVerifiedSolvableData);
    return _notifier.value;
  }

  @override
  Future<void> saveSettings(SettingsModel settings) async {
    final prefs = await _prefs();
    _notifier.value = settings;
    setIgnoreVerifiedSolvableData(settings.ignoreVerifiedSolvableData);
    await prefs.setString(_storageKey, jsonEncode(settings.toJson()));
  }

  @override
  ValueListenable<SettingsModel> watch() => _notifier;

  Future<SharedPreferences> _prefs() async {
    return _prefsOverride ?? SharedPreferences.getInstance();
  }
}
