import 'package:flutter/material.dart';

import '../../app/routes.dart';
import '../../game/model/deal_source.dart';
import '../../game/model/difficulty.dart';
import '../play/play_screen.dart';
import 'widgets/home_action_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Difficulty _difficulty = Difficulty.fourSuit;

  void _startDaily() {
    final now = DateTime.now();
    final key =
        '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
    Navigator.of(context).pushNamed(
      AppRoutes.play,
      arguments: PlayScreenArgs(
        difficulty: _difficulty,
        dealSource: DailyDealSource(key),
      ),
    );
  }

  Future<void> _startRandom() async {
    final choice = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Random Deal'),
        content: const Text('Choose deal mode'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop('solvable'),
            child: const Text('Guaranteed winnable'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop('random'),
            child: const Text('Totally random'),
          ),
        ],
      ),
    );

    if (choice == null || !mounted) {
      return;
    }

    final seed = DateTime.now().millisecondsSinceEpoch;
    Navigator.of(context).pushNamed(
      AppRoutes.play,
      arguments: PlayScreenArgs(
        difficulty: _difficulty,
        dealSource: RandomDealSource(seed),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Spider Solitaire')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: GridView.count(
          crossAxisCount: 2,
          childAspectRatio: 2.4,
          children: [
            HomeActionCard(
              title: 'Daily Deal',
              subtitle: 'Play today\'s local seeded game.',
              child: Row(
                children: [
                  Expanded(
                    child: DropdownButton<Difficulty>(
                      value: _difficulty,
                      isExpanded: true,
                      onChanged: (value) {
                        if (value == null) {
                          return;
                        }
                        setState(() => _difficulty = value);
                      },
                      items: Difficulty.values
                          .map(
                            (d) => DropdownMenuItem(
                              value: d,
                              child: Text(d.label),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton(
                    onPressed: _startDaily,
                    child: const Text('Play Today'),
                  ),
                ],
              ),
            ),
            HomeActionCard(
              title: 'Random Deal',
              subtitle: 'Start a fresh seeded shuffle.',
              child: Align(
                alignment: Alignment.centerLeft,
                child: FilledButton(
                  onPressed: _startRandom,
                  child: const Text('Play'),
                ),
              ),
            ),
            HomeActionCard(
              title: 'Scores / Stats',
              subtitle: 'Session and long-term records.',
              child: OutlinedButton(
                onPressed: () =>
                    Navigator.of(context).pushNamed(AppRoutes.stats),
                child: const Text('Open Stats'),
              ),
            ),
            HomeActionCard(
              title: 'Settings',
              subtitle: 'Gameplay preferences and defaults.',
              child: OutlinedButton(
                onPressed: () =>
                    Navigator.of(context).pushNamed(AppRoutes.settings),
                child: const Text('Open Settings'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
