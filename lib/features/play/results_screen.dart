import 'package:flutter/material.dart';

import '../../game/model/difficulty.dart';

enum ResultsAction { playAgain, home }

class ResultsData {
  const ResultsData({
    required this.difficulty,
    required this.score,
    required this.timeSeconds,
    required this.moves,
    required this.undos,
    required this.hints,
    required this.completedRuns,
  });

  final Difficulty difficulty;
  final int score;
  final int timeSeconds;
  final int moves;
  final int undos;
  final int hints;
  final int completedRuns;
}

class ResultsScreen extends StatelessWidget {
  const ResultsScreen({super.key, required this.data});

  final ResultsData data;

  String _formatTime(int totalSeconds) {
    final hours = (totalSeconds ~/ 3600).toString().padLeft(2, '0');
    final minutes = ((totalSeconds % 3600) ~/ 60).toString().padLeft(2, '0');
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Results'),
          automaticallyImplyLeading: false,
        ),
        body: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Difficulty: ${data.difficulty.label}'),
              const SizedBox(height: 8),
              Text('Score: ${data.score}'),
              const SizedBox(height: 8),
              Text('Time: ${_formatTime(data.timeSeconds)}'),
              const SizedBox(height: 8),
              Text('Moves: ${data.moves}'),
              const SizedBox(height: 8),
              Text('Undos: ${data.undos}'),
              const SizedBox(height: 8),
              Text('Hints: ${data.hints}'),
              const SizedBox(height: 8),
              Text('Runs: ${data.completedRuns}'),
              const Spacer(),
              Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      onPressed: () {
                        Navigator.of(context).pop(ResultsAction.playAgain);
                      },
                      child: const Text('Play Again'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.of(context).pop(ResultsAction.home);
                      },
                      child: const Text('Home'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
