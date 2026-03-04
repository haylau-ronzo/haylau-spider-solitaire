import 'package:flutter_test/flutter_test.dart';
import 'package:haylau_spider_solitaire/features/settings/settings_model.dart';
import 'package:haylau_spider_solitaire/features/settings/settings_repo.dart';
import 'package:haylau_spider_solitaire/game/solvable/verified_solvable_data_override.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('LocalSettingsRepo persists tap mode and drag preview toggle', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});

    final firstRepo = LocalSettingsRepo();
    final initial = await firstRepo.loadSettings();
    expect(initial.tapMode, TapMode.onTwoTap);
    expect(initial.previewNextCardOnDrag, isFalse);
    expect(initial.ignoreVerifiedSolvableData, isFalse);

    await firstRepo.saveSettings(
      initial.copyWith(
        tapMode: TapMode.auto,
        previewNextCardOnDrag: true,
        ignoreVerifiedSolvableData: true,
      ),
    );

    final secondRepo = LocalSettingsRepo();
    final reloaded = await secondRepo.loadSettings();
    expect(reloaded.tapMode, TapMode.auto);
    expect(reloaded.previewNextCardOnDrag, isTrue);
    expect(reloaded.ignoreVerifiedSolvableData, isTrue);
    expect(ignoreVerifiedSolvableData, isTrue);
  });
}
