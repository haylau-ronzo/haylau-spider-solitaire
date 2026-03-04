import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../app/app_services.dart';
import '../../game/model/difficulty.dart';
import '../../game/solvable/solvable_seed_counts_summary.dart';
import '../../game/solvable/verified_solvable_data_override.dart';
import '../../utils/orientation_lock.dart';
import 'settings_model.dart';
import 'settings_repo.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final SettingsRepo _repo = AppServices.settingsRepo;

  Future<void> _save(SettingsModel settings) {
    return _repo.saveSettings(settings);
  }

  Future<void> _saveAndApplyOrientation(SettingsModel settings) async {
    await _save(settings);
    await applyOrientationLock(settings.orientationLock);
  }

  Future<void> _showSolvableSeedCounts() {
    final usage = AppServices.solvableSeedUsageRepo.current();
    final summary = buildSolvableSeedCountsSummary(usage);

    return showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Solvable seed counts'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Daily 1-suit: ${summary.daily1SuitUsed} / ${summary.daily1SuitTotal} used',
              ),
              const SizedBox(height: 6),
              Text('Random 1-suit:  /  used'),
              const SizedBox(height: 10),
              const Text(
                'Used counts increment on win.',
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _resetSolvableUsageAndCaches() async {
    await AppServices.solvableSeedUsageRepo.clearAll();
    if (!mounted) {
      return;
    }
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Reset local solvable usage data.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ValueListenableBuilder<SettingsModel>(
        valueListenable: _repo.watch(),
        builder: (context, settings, _) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'Difficulty',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              SegmentedButton<Difficulty>(
                segments: const [
                  ButtonSegment(
                    value: Difficulty.oneSuit,
                    label: Text('1 Suit'),
                  ),
                  ButtonSegment(
                    value: Difficulty.twoSuit,
                    label: Text('2 Suit'),
                  ),
                  ButtonSegment(
                    value: Difficulty.fourSuit,
                    label: Text('4 Suit'),
                  ),
                ],
                selected: <Difficulty>{settings.difficulty},
                onSelectionChanged: (values) {
                  _save(settings.copyWith(difficulty: values.first));
                },
              ),
              const SizedBox(height: 20),
              Text('Tap mode', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              SegmentedButton<TapMode>(
                segments: const [
                  ButtonSegment(value: TapMode.off, label: Text('Off')),
                  ButtonSegment(value: TapMode.onTwoTap, label: Text('On')),
                  ButtonSegment(value: TapMode.auto, label: Text('Auto')),
                ],
                selected: <TapMode>{settings.tapMode},
                onSelectionChanged: (values) {
                  _save(settings.copyWith(tapMode: values.first));
                },
              ),
              const SizedBox(height: 20),
              Text('Deal rule', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              SegmentedButton<DealRule>(
                segments: const [
                  ButtonSegment(
                    value: DealRule.classic,
                    label: Text('Classic'),
                  ),
                  ButtonSegment(
                    value: DealRule.unrestricted,
                    label: Text('Unrestricted'),
                  ),
                ],
                selected: <DealRule>{settings.dealRule},
                onSelectionChanged: (values) {
                  _save(settings.copyWith(dealRule: values.first));
                },
              ),
              const SizedBox(height: 20),
              Text(
                'Orientation lock',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              SegmentedButton<OrientationLock>(
                segments: const [
                  ButtonSegment(
                    value: OrientationLock.landscape,
                    label: Text('Landscape'),
                  ),
                  ButtonSegment(
                    value: OrientationLock.portrait,
                    label: Text('Portrait'),
                  ),
                ],
                selected: <OrientationLock>{settings.orientationLock},
                onSelectionChanged: (values) {
                  _saveAndApplyOrientation(
                    settings.copyWith(orientationLock: values.first),
                  );
                },
              ),
              const SizedBox(height: 20),
              Text(
                'Animations',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              SegmentedButton<AnimationMode>(
                segments: const [
                  ButtonSegment(value: AnimationMode.off, label: Text('Off')),
                  ButtonSegment(
                    value: AnimationMode.minimal,
                    label: Text('Minimal'),
                  ),
                  ButtonSegment(value: AnimationMode.full, label: Text('Full')),
                ],
                selected: <AnimationMode>{settings.animations},
                onSelectionChanged: (values) {
                  _save(settings.copyWith(animations: values.first));
                },
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Sounds'),
                value: settings.soundsOn,
                onChanged: (value) {
                  _save(settings.copyWith(soundsOn: value));
                },
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Preview next card while dragging'),
                subtitle: const Text(
                  'Shows a faint preview of the next card that will be exposed.',
                ),
                value: settings.previewNextCardOnDrag,
                onChanged: (value) {
                  _save(settings.copyWith(previewNextCardOnDrag: value));
                },
              ),
              if (kDebugMode) ...[
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Ignore verified solvable data'),
                  subtitle: const Text(
                    'Treat verified pools/solutions as empty for dev testing.',
                  ),
                  value: settings.ignoreVerifiedSolvableData,
                  onChanged: (value) {
                    setIgnoreVerifiedSolvableData(value);
                    _save(settings.copyWith(ignoreVerifiedSolvableData: value));
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Reset local solvable usage/caches'),
                  subtitle: const Text('Clears local used-seed tracking data.'),
                  trailing: const Icon(Icons.delete_outline),
                  onTap: _resetSolvableUsageAndCaches,
                ),
              ],
              const SizedBox(height: 8),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Solvable seed counts'),
                subtitle: Text(
                  ignoreVerifiedSolvableData
                      ? 'Verified data ignored in debug mode.'
                      : 'View daily/random solvable pool sizes.',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: _showSolvableSeedCounts,
              ),
            ],
          );
        },
      ),
    );
  }
}
