import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:haylau_spider_solitaire/game/persistence/solvable_seed_usage_repo.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('LocalSolvableSeedUsageRepo persists usage across reload', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});

    final repo1 = LocalSolvableSeedUsageRepo();
    await repo1.load();
    await repo1.markDailyUsedSeed1Suit(120314);
    await repo1.markRandomUsedSeed1Suit(346782);

    final repo2 = LocalSolvableSeedUsageRepo();
    final loaded = await repo2.load();

    expect(loaded.dailyUsedSeeds1Suit, contains(120314));
    expect(loaded.randomUsedSeeds1Suit, contains(346782));
  });

  test('LocalSolvableSeedUsageRepo migrates legacy JSON blob key', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'solvable.seed.usage': jsonEncode(<String, dynamic>{
        'dailyUsedSeeds': <int>[120314],
        'randomUsedSeeds': <int>[346782, 958440],
      }),
    });

    final repo = LocalSolvableSeedUsageRepo();
    final loaded = await repo.load();

    expect(loaded.dailyUsedSeeds1Suit, contains(120314));
    expect(loaded.randomUsedSeeds1Suit, containsAll(<int>[346782, 958440]));
  });

  test('LocalSolvableSeedUsageRepo migrates legacy split list keys', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'solvable.seed.usage.daily1suit': <String>['120314', '987231'],
      'solvable.seed.usage.random1suit': <String>['346782'],
    });

    final repo = LocalSolvableSeedUsageRepo();
    final loaded = await repo.load();

    expect(loaded.dailyUsedSeeds1Suit, containsAll(<int>[120314, 987231]));
    expect(loaded.randomUsedSeeds1Suit, contains(346782));
  });

  test('clearAll resets persisted usage to empty', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});

    final repo = LocalSolvableSeedUsageRepo();
    await repo.load();
    await repo.markDailyUsedSeed1Suit(120314);
    await repo.markRandomUsedSeed1Suit(346782);

    await repo.clearAll();

    expect(repo.current().dailyUsedSeeds1Suit, isEmpty);
    expect(repo.current().randomUsedSeeds1Suit, isEmpty);

    final reloaded = LocalSolvableSeedUsageRepo();
    final loaded = await reloaded.load();
    expect(loaded.dailyUsedSeeds1Suit, isEmpty);
    expect(loaded.randomUsedSeeds1Suit, isEmpty);
  });
}
