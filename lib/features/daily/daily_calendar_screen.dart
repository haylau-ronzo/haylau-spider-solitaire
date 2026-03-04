import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/app_services.dart';
import '../../app/routes.dart';
import '../../game/model/deal_source.dart';
import '../../game/model/difficulty.dart';
import '../../game/persistence/daily_deals_model.dart';
import '../../game/persistence/daily_deals_repo.dart';
import '../../game/persistence/save_model.dart';
import '../../game/persistence/save_repo.dart';
import '../../game/persistence/save_slots.dart';
import '../../game/solvable/solvable_seeds.dart';
import '../../game/solvable/solvable_solution_step.dart';
import '../../game/solvable/solvable_solutions_1suit_verified.dart';
import '../../utils/date_formatters.dart';
import '../play/play_screen.dart';
import '../preview/deal_choice.dart';
import '../preview/solution_preview_screen.dart';
import '../settings/settings_repo.dart';
import 'daily_calendar_logic.dart';

class DailyCalendarScreen extends StatefulWidget {
  const DailyCalendarScreen({super.key});

  @override
  State<DailyCalendarScreen> createState() => _DailyCalendarScreenState();
}

class _DailyCalendarScreenState extends State<DailyCalendarScreen> {
  final SaveRepo _saveRepo = AppServices.saveRepo;
  final DailyDealsRepo _dailyDealsRepo = AppServices.dailyDealsRepo;
  final SettingsRepo _settingsRepo = AppServices.settingsRepo;

  late DateTime _visibleMonth;
  bool _loading = true;
  Map<String, SaveModel> _inProgressDailySaves = <String, SaveModel>{};
  bool _isOpeningDay = false;

  static const List<String> _weekdayHeaders = <String>[
    'M',
    'T',
    'W',
    'T',
    'F',
    'S',
    'S',
  ];

  static const Color _futureBorderColor = Color(0xFFD3D8DE);
  static const Color _futureTextColor = Color(0xFFA7AFB8);
  static const Color _availableFillColor = Color(0xFFFAF1E2);
  static const Color _availableBorderColor = Color(0xFFD5C2A2);
  static const Color _completedFillColor = Color(0xFFE2F0E6);
  static const Color _completedBorderColor = Color(0xFF9FBBA7);
  static const Color _todayOutlineColor = Color(0xFF2F69A3);
  static const Color _inProgressDotColor = Color(0xFF2F6FC8);
  static const Color _completedDotColor = Colors.red;

  @override
  void initState() {
    super.initState();
    final today = DateTime.now();
    _visibleMonth = DateTime(today.year, today.month, 1);
    _dailyDealsRepo.watch().addListener(_onDailyDealsChanged);
    _load();
  }

  @override
  void dispose() {
    _dailyDealsRepo.watch().removeListener(_onDailyDealsChanged);
    super.dispose();
  }

  void _onDailyDealsChanged() {
    if (!mounted) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      setState(() {});
    });
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
    });

    final all = await _saveRepo.loadAllSlots();
    final mapped = <String, SaveModel>{};
    for (final entry in all.entries) {
      if (!SaveSlots.isDaily(entry.key)) {
        continue;
      }
      final inProgress = entry.value.gameState.foundations.completedRuns < 8;
      if (!inProgress) {
        continue;
      }
      final dateKey = SaveSlots.dailyDateKey(entry.key);
      if (dateKey != null) {
        mapped[dateKey] = entry.value;
      }
    }

    if (!mounted) {
      return;
    }
    setState(() {
      _inProgressDailySaves = mapped;
      _loading = false;
    });
  }

  DateTime get _today => stripLocalDate(DateTime.now());
  bool get _dailyAvailable =>
      hasDailySolvableSeeds(_settingsRepo.current().difficulty);

  List<DateTime?> _buildMonthCells(DateTime month) {
    final first = DateTime(month.year, month.month, 1);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final leadingBlankCount = first.weekday - 1;

    final cells = <DateTime?>[];
    for (var i = 0; i < leadingBlankCount; i++) {
      cells.add(null);
    }
    for (var day = 1; day <= daysInMonth; day++) {
      cells.add(DateTime(month.year, month.month, day));
    }
    while (cells.length < 42) {
      cells.add(null);
    }
    return cells.take(42).toList(growable: false);
  }

  Future<void> _openPlay(PlayScreenArgs args) async {
    await Navigator.of(context).pushNamed(AppRoutes.play, arguments: args);
    if (!mounted) {
      return;
    }
    await _load();
  }

  List<SolutionStepDto>? _prefixForSeed(int seed) {
    if (_settingsRepo.current().difficulty != Difficulty.oneSuit) {
      return null;
    }
    return verifiedSolutionPrefixForSeed1Suit(seed);
  }

  List<SolutionStepDto>? _fullForSeed(int seed) {
    if (_settingsRepo.current().difficulty != Difficulty.oneSuit) {
      return null;
    }
    return verifiedFullSolutionForSeed1Suit(seed);
  }

  Future<void> _openPreviewForDate({
    required String dateKey,
    required bool fast,
  }) {
    final difficulty = _settingsRepo.current().difficulty;
    final seed = pickDailySolvableSeed(
      difficulty: difficulty,
      dateKey: dateKey,
    );
    final steps = fast ? _fullForSeed(seed) : _prefixForSeed(seed);
    if (steps == null || steps.isEmpty) {
      return Future<void>.value();
    }

    return Navigator.of(context).pushNamed(
      AppRoutes.solutionPreview,
      arguments: SolutionPreviewArgs(
        deal: DealChoice(
          difficulty: difficulty,
          mode: DealChoiceMode.daily,
          guaranteed: true,
          seed: seed,
          dateKey: dateKey,
        ),
        steps: steps,
        title: fast ? 'Show Full Proof (Fast)' : 'Preview First 30 Steps',
        fast: fast,
      ),
    );
  }

  void _queueDateTap(DateTime date) {
    if (!_dailyAvailable) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Daily Deal not available yet (no verified solvable daily deals for this difficulty).',
            ),
          ),
        );
      }
      return;
    }

    if (_isOpeningDay) {
      return;
    }
    _isOpeningDay = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        if (!mounted) {
          return;
        }
        await _showDayDetailsForDate(date);
      } finally {
        _isOpeningDay = false;
      }
    });
  }

  _DayUiState _dayStateFor(String dateKey) {
    final isFuture = isFutureDateKey(dateKey, _today);
    final inProgressSave = _inProgressDailySaves[dateKey];
    final inProgress = inProgressSave != null;
    final record = _dailyDealsRepo.current().recordsByDateKey[dateKey];
    final completed =
        record != null && record.status == DailyDealStatus.completed;
    final completedOnDay =
        completed &&
        record.completedAt != null &&
        isCompletedOnDay(
          dateKeyLocal: dateKey,
          completedAt: record.completedAt!,
        );

    return _DayUiState(
      isFuture: isFuture,
      isInProgress: inProgress,
      isCompleted: completed,
      isCompletedOnDay: completedOnDay,
      completionRecord: record,
      inProgressSave: inProgressSave,
    );
  }

  Future<void> _showDayDetailsForDate(DateTime date) async {
    if (!_dailyAvailable) {
      return;
    }

    final dateKey = toDateKeyLocal(date);
    final state = _dayStateFor(dateKey);
    if (state.isFuture) {
      return;
    }

    final action = await _showDayDetailsPanel(date, state);
    if (!mounted || action == null || action == 'close') {
      return;
    }

    if (action == 'play' || action == 'replay') {
      await _openPlay(
        PlayScreenArgs(
          difficulty: _settingsRepo.current().difficulty,
          dealSource: DailySolvableDealSource(dateKey),
        ),
      );
      return;
    }

    if (action == 'resume') {
      final save = state.inProgressSave;
      if (save == null) {
        return;
      }
      await _openPlay(
        PlayScreenArgs(
          difficulty: save.gameState.difficulty,
          dealSource: save.gameState.dealSource,
          resumeSave: save,
        ),
      );
      return;
    }

    if (action == 'abort') {
      await _saveRepo.deleteSlot(SaveSlots.daily(dateKey));
      await _dailyDealsRepo.markAbortedIfNotCompleted(dateKey);
      if (!mounted) {
        return;
      }
      await _load();
      return;
    }

    if (action == 'preview') {
      await _openPreviewForDate(dateKey: dateKey, fast: false);
      return;
    }

    if (action == 'full-proof') {
      await _openPreviewForDate(dateKey: dateKey, fast: true);
      return;
    }
  }

  Future<String?> _showDayDetailsPanel(DateTime date, _DayUiState state) {
    final statusLine = state.statusLine;
    final completion = state.completionRecord?.metrics;
    final completedAt = state.completionRecord?.completedAt;
    final lastPlayedAt = state.inProgressSave?.savedAt;
    final dateKey = toDateKeyLocal(date);
    final seed = pickDailySolvableSeed(
      difficulty: _settingsRepo.current().difficulty,
      dateKey: dateKey,
    );
    final prefix = _prefixForSeed(seed);
    final full = _fullForSeed(seed);
    final canPreview = prefix != null && prefix.isNotEmpty;
    final canShowFull = full != null && full.isNotEmpty;

    final details = <MapEntry<String, String>>[];
    if (state.isCompleted && completion != null) {
      details.addAll([
        MapEntry('Score', '${completion.score}'),
        MapEntry('Time', _formatTime(completion.timeSeconds)),
        MapEntry('Moves', '${completion.moves}'),
        MapEntry('Undos', '${completion.undos}'),
        MapEntry('Hints', '${completion.hints}'),
        if (completedAt != null)
          MapEntry('Completed', formatUkDateTime(completedAt)),
      ]);
    } else if (state.isInProgress && lastPlayedAt != null) {
      details.add(MapEntry('Last played', formatUkDateTime(lastPlayedAt)));
    }

    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        final maxHeight = MediaQuery.sizeOf(context).height * 0.78;
        final labelStyle = Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(color: Colors.black54);
        final valueStyle = Theme.of(context).textTheme.bodyMedium;

        return SafeArea(
          top: false,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxHeight),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 6, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            formatUkDate(date),
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 2),
                          Text(statusLine),
                          const SizedBox(height: 2),
                          Text(
                            'Seed: ',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const SizedBox(height: 8),
                          for (final item in details)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SizedBox(
                                    width: 88,
                                    child: Text(item.key, style: labelStyle),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(item.value, style: valueStyle),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop('close'),
                        child: const Text('Close'),
                      ),
                      if (state.isCompleted)
                        FilledButton(
                          onPressed: () => Navigator.of(context).pop('replay'),
                          child: const Text('Replay'),
                        )
                      else if (state.isInProgress) ...[
                        FilledButton(
                          onPressed: () => Navigator.of(context).pop('resume'),
                          child: const Text('Resume'),
                        ),
                        OutlinedButton(
                          onPressed: () => Navigator.of(context).pop('abort'),
                          child: const Text('Abort'),
                        ),
                      ] else
                        FilledButton(
                          onPressed: () => Navigator.of(context).pop('play'),
                          child: const Text('Play'),
                        ),
                      FilledButton.tonal(
                        onPressed: canPreview
                            ? () => Navigator.of(context).pop('preview')
                            : null,
                        child: const Text('Preview first 30 steps'),
                      ),
                      FilledButton.tonal(
                        onPressed: canShowFull
                            ? () => Navigator.of(context).pop('full-proof')
                            : null,
                        child: const Text('Show full proof (fast)'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String _formatTime(int totalSeconds) {
    final hours = (totalSeconds ~/ 3600).toString().padLeft(2, '0');
    final minutes = ((totalSeconds % 3600) ~/ 60).toString().padLeft(2, '0');
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }

  Widget _buildCell(DateTime? date, double cellSize) {
    if (date == null) {
      return SizedBox(width: cellSize, height: cellSize);
    }

    final dateKey = toDateKeyLocal(date);
    final dayState = _dayStateFor(dateKey);
    final isToday = stripLocalDate(date) == _today;

    final Color fillColor = dayState.isFuture
        ? Colors.transparent
        : (dayState.isCompleted ? _completedFillColor : _availableFillColor);
    final Color borderColor = dayState.isFuture
        ? _futureBorderColor
        : (dayState.isCompleted
              ? _completedBorderColor
              : _availableBorderColor);

    Color textColor;
    if (dayState.isFuture) {
      textColor = _futureTextColor;
    } else if (dayState.isInProgress && !dayState.isCompleted) {
      textColor = Theme.of(context).colorScheme.primary;
    } else {
      textColor = Theme.of(context).colorScheme.onSurface;
    }

    final dayFontSize = math.max(10.0, math.min(14.0, cellSize * 0.28));

    final circleSize = math.max(16.0, cellSize - 4);
    final todayOutlineSize = math.min(cellSize, circleSize + 2);

    return SizedBox(
      width: cellSize,
      height: cellSize,
      child: InkWell(
        onTap: (dayState.isFuture || !_dailyAvailable)
            ? null
            : () => _queueDateTap(date),
        child: Center(
          child: SizedBox(
            width: circleSize,
            height: circleSize,
            child: Stack(
              children: [
                Align(
                  alignment: Alignment.center,
                  child: Container(
                    width: circleSize,
                    height: circleSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: borderColor, width: 0.9),
                      color: fillColor,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '${date.day}',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: textColor,
                        fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
                        fontSize: dayFontSize,
                        height: 1,
                      ),
                    ),
                  ),
                ),
                if (!dayState.isFuture &&
                    (dayState.isCompleted || dayState.isInProgress))
                  Align(
                    alignment: const Alignment(0, 0.62),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _Dot(
                          size: 4,
                          color: dayState.isCompleted
                              ? _completedDotColor
                              : _inProgressDotColor,
                        ),
                        if (dayState.isCompletedOnDay) ...[
                          const SizedBox(width: 3),
                          const _Dot(size: 4, color: _completedDotColor),
                        ],
                      ],
                    ),
                  ),
                if (isToday)
                  Align(
                    alignment: Alignment.center,
                    child: IgnorePointer(
                      child: Container(
                        width: todayOutlineSize,
                        height: todayOutlineSize,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _todayOutlineColor,
                            width: 1.35,
                          ),
                        ),
                      ),
                    ),
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
    final cells = _buildMonthCells(_visibleMonth);

    return Scaffold(
      appBar: AppBar(title: const Text('Daily Calendar')),
      body: Padding(
        padding: const EdgeInsets.all(8),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : LayoutBuilder(
                builder: (context, constraints) {
                  const headerHeight = 34.0;
                  const weekdayHeight = 18.0;
                  const legendHeight = 18.0;
                  const spacing = 10.0;
                  final availableHeight =
                      constraints.maxHeight -
                      headerHeight -
                      weekdayHeight -
                      legendHeight -
                      spacing;
                  final availableWidth = constraints.maxWidth;

                  final cellSize = math.max(
                    18.0,
                    math.min(availableWidth / 7, availableHeight / 6),
                  );

                  final gridWidth = cellSize * 7;
                  final gridHeight = cellSize * 6;

                  return Column(
                    children: [
                      SizedBox(
                        height: headerHeight,
                        child: Row(
                          children: [
                            IconButton(
                              tooltip: 'Previous month',
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                              onPressed: () {
                                setState(() {
                                  _visibleMonth = DateTime(
                                    _visibleMonth.year,
                                    _visibleMonth.month - 1,
                                    1,
                                  );
                                });
                              },
                              icon: const Icon(Icons.chevron_left),
                            ),
                            Expanded(
                              child: Center(
                                child: Text(
                                  formatUkMonthYear(_visibleMonth),
                                  style: Theme.of(context).textTheme.titleSmall,
                                ),
                              ),
                            ),
                            IconButton(
                              tooltip: 'Next month',
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                              onPressed: () {
                                setState(() {
                                  _visibleMonth = DateTime(
                                    _visibleMonth.year,
                                    _visibleMonth.month + 1,
                                    1,
                                  );
                                });
                              },
                              icon: const Icon(Icons.chevron_right),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(
                        height: weekdayHeight,
                        width: gridWidth,
                        child: Row(
                          children: [
                            for (final header in _weekdayHeaders)
                              SizedBox(
                                width: cellSize,
                                child: Center(
                                  child: Text(
                                    header,
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),
                      SizedBox(
                        width: gridWidth,
                        height: gridHeight,
                        child: GridView.builder(
                          padding: EdgeInsets.zero,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: 42,
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 7,
                                childAspectRatio: 1,
                              ),
                          itemBuilder: (context, index) =>
                              _buildCell(cells[index], cellSize),
                        ),
                      ),
                      const SizedBox(height: 4),
                      const SizedBox(
                        height: legendHeight,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _Dot(size: 4, color: _inProgressDotColor),
                            SizedBox(width: 4),
                            Text('In progress', style: TextStyle(fontSize: 11)),
                            SizedBox(width: 10),
                            _Dot(size: 4, color: _completedDotColor),
                            SizedBox(width: 4),
                            Text('Complete', style: TextStyle(fontSize: 11)),
                            SizedBox(width: 10),
                            _Dot(size: 4, color: _completedDotColor),
                            SizedBox(width: 3),
                            _Dot(size: 4, color: _completedDotColor),
                            SizedBox(width: 4),
                            Text(
                              'Completed on day',
                              style: TextStyle(fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
      ),
    );
  }
}

class _DayUiState {
  const _DayUiState({
    required this.isFuture,
    required this.isInProgress,
    required this.isCompleted,
    required this.isCompletedOnDay,
    required this.completionRecord,
    required this.inProgressSave,
  });

  final bool isFuture;
  final bool isInProgress;
  final bool isCompleted;
  final bool isCompletedOnDay;
  final DailyDealRecord? completionRecord;
  final SaveModel? inProgressSave;

  String get statusLine {
    if (isCompletedOnDay) {
      return 'Completed on day';
    }
    if (isCompleted) {
      return 'Complete';
    }
    if (isInProgress) {
      return 'In progress';
    }
    return 'Not started';
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}
