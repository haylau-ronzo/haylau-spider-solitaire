import 'package:flutter/material.dart';

import '../../app/app_services.dart';
import '../../app/theme.dart';
import '../../game/model/difficulty.dart';
import '../../game/persistence/stats_model.dart';

class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key});

  Widget _statRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
          ),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  Widget _sectionCard({
    required BuildContext context,
    required String title,
    required List<Widget> children,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            ...children,
          ],
        ),
      ),
    );
  }

  String _byDifficulty(Map<Difficulty, int> values) {
    if (values.isEmpty) {
      return '-';
    }
    return Difficulty.values
        .map((d) => '${d.label}: ${values[d] ?? 0}')
        .join(' | ');
  }

  String _bestTimeByDifficulty(Map<Difficulty, int> values) {
    if (values.isEmpty) {
      return '-';
    }
    String fmt(int seconds) {
      final h = (seconds ~/ 3600).toString().padLeft(2, '0');
      final m = ((seconds % 3600) ~/ 60).toString().padLeft(2, '0');
      final s = (seconds % 60).toString().padLeft(2, '0');
      return '$h:$m:$s';
    }

    return Difficulty.values
        .map((d) {
          final v = values[d];
          return '${d.label}: ${v == null ? '-' : fmt(v)}';
        })
        .join(' | ');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Stats')),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppPalette.feltLight, AppPalette.feltMid],
          ),
        ),
        child: ValueListenableBuilder<StatsModel>(
          valueListenable: AppServices.statsRepo.watch(),
          builder: (context, stats, _) {
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _sectionCard(
                  context: context,
                  title: 'Lifetime',
                  children: [
                    _statRow(
                      context,
                      'Total Score',
                      '${stats.lifetimeTotalScore}',
                    ),
                    _statRow(
                      context,
                      'Games Started',
                      '${stats.totalGamesStarted}',
                    ),
                    _statRow(
                      context,
                      'Games Completed',
                      '${stats.totalGamesCompleted}',
                    ),
                  ],
                ),
                _sectionCard(
                  context: context,
                  title: 'Play Activity',
                  children: [
                    _statRow(context, 'Moves', '${stats.totalMoves}'),
                    _statRow(context, 'Undos', '${stats.totalUndos}'),
                    _statRow(context, 'Redos', '${stats.totalRedos}'),
                    _statRow(context, 'Hints', '${stats.totalHints}'),
                  ],
                ),
                _sectionCard(
                  context: context,
                  title: 'Best By Difficulty',
                  children: [
                    Text(
                      'Wins: ${_byDifficulty(stats.winsByDifficulty)}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Best Score: ${_byDifficulty(stats.bestScoreByDifficulty)}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Best Time: ${_bestTimeByDifficulty(stats.bestTimeByDifficulty)}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
