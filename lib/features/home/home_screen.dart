import 'package:flutter/material.dart';

import '../../app/app_services.dart';
import '../../app/routes.dart';
import '../../game/model/deal_source.dart';
import '../../game/model/difficulty.dart';
import '../../game/persistence/save_model.dart';
import '../../game/persistence/save_repo.dart';
import '../../game/persistence/save_slots.dart';
import '../../game/solvable/solvable_seeds.dart';
import '../../game/solvable/verified_solvable_data_override.dart';
import '../../utils/date_formatters.dart';
import '../daily/daily_calendar_logic.dart';
import '../play/play_screen.dart';
import '../settings/settings_repo.dart';

bool isDailyDealAvailable({
  required Difficulty difficulty,
  bool Function(Difficulty difficulty)? dailyPoolOverride,
  bool? ignoreVerifiedOverride,
}) {
  final ignore = ignoreVerifiedOverride ?? ignoreVerifiedSolvableData;
  if (ignore) {
    return false;
  }
  return dailyPoolOverride?.call(difficulty) ??
      hasDailySolvableSeeds(difficulty);
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    this.hasGuaranteedRandomPoolOverride,
    this.hasDailyPoolOverride,
  });

  final bool Function(Difficulty difficulty)? hasGuaranteedRandomPoolOverride;
  final bool Function(Difficulty difficulty)? hasDailyPoolOverride;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final SaveRepo _saveRepo = AppServices.saveRepo;
  final SettingsRepo _settingsRepo = AppServices.settingsRepo;

  Difficulty _difficulty = Difficulty.fourSuit;
  bool _loadingSaves = true;
  SaveModel? _resumeRandom;
  SaveModel? _resumeDaily;
  int _nextGuaranteedRandomIndex = 0;

  @override
  void initState() {
    super.initState();
    _difficulty = _settingsRepo.current().difficulty;
    _settingsRepo.watch().addListener(_onSettingsChanged);
    _refreshSaves();
  }

  @override
  void dispose() {
    _settingsRepo.watch().removeListener(_onSettingsChanged);
    super.dispose();
  }

  void _onSettingsChanged() {
    if (!mounted) {
      return;
    }
    setState(() {
      _difficulty = _settingsRepo.current().difficulty;
    });
  }

  Future<void> _refreshSaves() async {
    setState(() {
      _loadingSaves = true;
    });

    final all = await _saveRepo.loadAllSlots();
    SaveModel? random;
    SaveModel? daily;
    for (final entry in all.entries) {
      final save = entry.value;
      final inProgress = save.gameState.foundations.completedRuns < 8;
      if (!inProgress) {
        continue;
      }

      if (entry.key == SaveSlots.random) {
        random = save;
        continue;
      }

      if (SaveSlots.isDaily(entry.key)) {
        if (daily == null || save.savedAt.isAfter(daily.savedAt)) {
          daily = save;
        }
      }
    }

    if (!mounted) {
      return;
    }
    setState(() {
      _resumeRandom = random;
      _resumeDaily = daily;
      _loadingSaves = false;
    });
  }

  Future<void> _openPlay(PlayScreenArgs args) async {
    await Navigator.of(context).pushNamed(AppRoutes.play, arguments: args);
    if (!mounted) {
      return;
    }
    await _refreshSaves();
  }

  Future<void> _resumeFromSave(SaveModel save) async {
    await _openPlay(
      PlayScreenArgs(
        difficulty: save.gameState.difficulty,
        dealSource: save.gameState.dealSource,
        resumeSave: save,
      ),
    );
  }

  bool _hasGuaranteedRandomPool() {
    return widget.hasGuaranteedRandomPoolOverride?.call(_difficulty) ??
        hasRandomSolvableSeeds(_difficulty);
  }

  bool _hasDailyPool() {
    return isDailyDealAvailable(
      difficulty: _difficulty,
      dailyPoolOverride: widget.hasDailyPoolOverride,
    );
  }

  int _selectGuaranteedRandomIndex() {
    final seeds = randomSolvableSeedsForDifficulty(_difficulty);
    if (seeds.isEmpty) {
      return DateTime.now().millisecondsSinceEpoch & 0x7fffffff;
    }

    if (_difficulty == Difficulty.oneSuit) {
      final used = AppServices.solvableSeedUsageRepo
          .current()
          .randomUsedSeeds1Suit;
      for (var offset = 0; offset < seeds.length; offset++) {
        final candidate = (_nextGuaranteedRandomIndex + offset) % seeds.length;
        if (!used.contains(seeds[candidate])) {
          _nextGuaranteedRandomIndex = (candidate + 1) % seeds.length;
          return candidate;
        }
      }
    }

    final selected = _nextGuaranteedRandomIndex % seeds.length;
    _nextGuaranteedRandomIndex =
        (_nextGuaranteedRandomIndex + 1) % seeds.length;
    return selected;
  }

  Future<void> _startRandomGuaranteed() async {
    final index = _selectGuaranteedRandomIndex();
    await _openPlay(
      PlayScreenArgs(
        difficulty: _difficulty,
        dealSource: RandomSolvableDealSource(index),
      ),
    );
  }

  Future<void> _startRandomTotallyRandom() async {
    final seed = DateTime.now().millisecondsSinceEpoch;
    await _openPlay(
      PlayScreenArgs(
        difficulty: _difficulty,
        dealSource: RandomDealSource(seed),
      ),
    );
  }

  Future<void> _openDailySheet() {
    final dailyAvailable = _hasDailyPool();
    if (!dailyAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Daily Deal not available yet (no verified solvable daily deals for this difficulty).',
          ),
        ),
      );
      return Future<void>.value();
    }

    final rawDateKey = _resumeDaily == null
        ? null
        : SaveSlots.dailyDateKey(_resumeDaily!.slotId);
    final parsedDate = rawDateKey == null
        ? null
        : parseDateKeyLocal(rawDateKey);
    final resumeLabel = parsedDate == null
        ? 'Resume Daily'
        : 'Resume Daily (${formatUkDate(parsedDate)})';

    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Daily Deal', style: TextStyle(fontSize: 18)),
                const SizedBox(height: 8),
                if (_resumeDaily != null)
                  FilledButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      _resumeFromSave(_resumeDaily!);
                    },
                    child: Text(resumeLabel),
                  ),
                OutlinedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    Navigator.of(
                      this.context,
                    ).pushNamed(AppRoutes.dailyCalendar);
                  },
                  child: const Text('Open Daily Calendar'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _openRandomSheet() {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Random Deal', style: TextStyle(fontSize: 18)),
                const SizedBox(height: 8),
                if (_resumeRandom != null)
                  FilledButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      _resumeFromSave(_resumeRandom!);
                    },
                    child: const Text('Resume Random'),
                  ),
                FilledButton(
                  onPressed: _hasGuaranteedRandomPool()
                      ? () {
                          Navigator.of(context).pop();
                          _startRandomGuaranteed();
                        }
                      : null,
                  child: const Text('Play (Guaranteed winnable)'),
                ),
                if (!_hasGuaranteedRandomPool())
                  const Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: Text(
                      'No verified solvable deals available yet.',
                      style: TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                  ),
                OutlinedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _startRandomTotallyRandom();
                  },
                  child: const Text('Play (Totally random)'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _menuItem({
    required String title,
    required String subtitle,
    required VoidCallback? onTap,
    required bool compact,
    bool enabled = true,
  }) {
    final titleStyle =
        (compact
                ? Theme.of(context).textTheme.titleSmall
                : Theme.of(context).textTheme.titleMedium)
            ?.copyWith(fontWeight: FontWeight.w700);
    final spiderTint = Theme.of(
      context,
    ).colorScheme.onSurface.withValues(alpha: enabled ? 0.92 : 0.35);

    return Opacity(
      opacity: enabled ? 1 : 0.65,
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: Theme.of(context).dividerColor),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: enabled ? onTap : null,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 12 : 16,
              vertical: compact ? 10 : 14,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    ColorFiltered(
                      colorFilter: ColorFilter.mode(
                        spiderTint,
                        BlendMode.srcIn,
                      ),
                      child: Image.asset(
                        'assets/images/spider_watermark.png',
                        width: compact ? 30 : 32,
                        height: compact ? 30 : 32,
                        fit: BoxFit.contain,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        title,
                        style: titleStyle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: compact ? 4 : 6),
                Text(
                  subtitle,
                  style: compact
                      ? Theme.of(context).textTheme.bodySmall
                      : Theme.of(context).textTheme.bodyMedium,
                  maxLines: compact ? 2 : null,
                  overflow: compact
                      ? TextOverflow.ellipsis
                      : TextOverflow.visible,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isPortrait =
        MediaQuery.sizeOf(context).height >= MediaQuery.sizeOf(context).width;
    final watermarkWidth = isPortrait ? 240.0 : 330.0;
    final watermarkTint = Theme.of(
      context,
    ).colorScheme.onSurface.withValues(alpha: 0.42);
    // Temporarily set to 0.25 when visually verifying, then restore.
    const watermarkOpacity = 0.09;

    final dailyAvailable = _hasDailyPool();

    final items = <Widget>[
      _menuItem(
        title: 'Daily Deal',
        subtitle: _loadingSaves
            ? 'Loading saved games...'
            : (!dailyAvailable
                  ? 'Daily Deal not available yet (no verified solvable daily deals for this difficulty).'
                  : (_resumeDaily == null
                        ? 'Open calendar and pick a day.'
                        : 'Resume or open daily calendar.')),
        onTap: dailyAvailable ? _openDailySheet : null,
        compact: !isPortrait,
        enabled: dailyAvailable,
      ),
      _menuItem(
        title: 'Random Deal',
        subtitle: _loadingSaves
            ? 'Loading saved games...'
            : (_resumeRandom == null
                  ? 'Guaranteed winnable or totally random.'
                  : 'Resume or start a new random deal.'),
        onTap: _openRandomSheet,
        compact: !isPortrait,
      ),
      _menuItem(
        title: 'Scores / Stats',
        subtitle: 'Session and lifetime records.',
        onTap: () => Navigator.of(context).pushNamed(AppRoutes.stats),
        compact: !isPortrait,
      ),
      _menuItem(
        title: 'Settings',
        subtitle: 'Difficulty, tap mode, deal rule, orientation lock.',
        onTap: () => Navigator.of(context).pushNamed(AppRoutes.settings),
        compact: !isPortrait,
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Spider Solitaire'),
        actions: [
          IconButton(
            tooltip: 'Help',
            onPressed: () => Navigator.of(context).pushNamed(AppRoutes.help),
            icon: const Icon(Icons.help_outline),
          ),
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Opacity(
                    opacity: watermarkOpacity,
                    child: ColorFiltered(
                      colorFilter: ColorFilter.mode(
                        watermarkTint,
                        BlendMode.srcIn,
                      ),
                      child: Image.asset(
                        'assets/images/spider_watermark.png',
                        width: watermarkWidth,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: isPortrait
                ? ListView.separated(
                    itemCount: items.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) =>
                        SizedBox(height: 108, child: items[index]),
                  )
                : GridView.builder(
                    itemCount: items.length,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                          childAspectRatio: 3.4,
                        ),
                    itemBuilder: (context, index) => items[index],
                  ),
          ),
        ],
      ),
    );
  }
}
