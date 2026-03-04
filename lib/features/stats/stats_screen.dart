import 'package:flutter/material.dart';

import '../../app/app_services.dart';
import '../../game/model/difficulty.dart';
import '../../game/persistence/stats_model.dart';

class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key});

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
      body: ValueListenableBuilder<StatsModel>(
        valueListenable: AppServices.statsRepo.watch(),
        builder: (context, stats, _) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text('Lifetime Total Score: ${stats.lifetimeTotalScore}'),
              const SizedBox(height: 8),
              Text('Games Started: ${stats.totalGamesStarted}'),
              const SizedBox(height: 8),
              Text('Games Completed: ${stats.totalGamesCompleted}'),
              const SizedBox(height: 8),
              Text('Total Moves: ${stats.totalMoves}'),
              const SizedBox(height: 8),
              Text('Total Undos: ${stats.totalUndos}'),
              const SizedBox(height: 8),
              Text('Total Redos: ${stats.totalRedos}'),
              const SizedBox(height: 8),
              Text('Total Hints: ${stats.totalHints}'),
              const Divider(height: 24),
              Text(
                'Wins by Difficulty: ${_byDifficulty(stats.winsByDifficulty)}',
              ),
              const SizedBox(height: 8),
              Text(
                'Best Score by Difficulty: '
                '${_byDifficulty(stats.bestScoreByDifficulty)}',
              ),
              const SizedBox(height: 8),
              Text(
                'Best Time by Difficulty: '
                '${_bestTimeByDifficulty(stats.bestTimeByDifficulty)}',
              ),
            ],
          );
        },
      ),
    );
  }
}
