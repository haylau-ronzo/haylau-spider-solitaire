import '../features/settings/settings_repo.dart';
import '../game/persistence/save_repo.dart';
import '../game/persistence/stats_repo.dart';
import '../game/persistence/daily_deals_repo.dart';
import '../game/persistence/solvable_seed_usage_repo.dart';

class AppServices {
  AppServices._();

  static final SettingsRepo settingsRepo = LocalSettingsRepo();
  static final StatsRepo statsRepo = LocalStatsRepo();
  static final SaveRepo saveRepo = LocalSaveRepo();
  static final DailyDealsRepo dailyDealsRepo = LocalDailyDealsRepo();
  static final SolvableSeedUsageRepo solvableSeedUsageRepo =
      LocalSolvableSeedUsageRepo();

  static Future<void> initialize() async {
    await settingsRepo.loadSettings();
    await statsRepo.loadStats();
    await dailyDealsRepo.load();
    await solvableSeedUsageRepo.load();
  }
}
