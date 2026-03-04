import 'package:flutter/material.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final headingStyle = Theme.of(context).textTheme.titleMedium;
    final bodyStyle = Theme.of(context).textTheme.bodyMedium;

    Widget section(String title, List<String> bullets) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: headingStyle),
            const SizedBox(height: 6),
            for (final bullet in bullets)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text('- $bullet', style: bodyStyle),
              ),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Help / How to Play')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              section('How to play Spider', [
                'Goal: clear all cards by building complete K→A sequences (same-suit); completed sequences are removed.',
                'Moves: build descending runs. In 2/4 suit, only same-suit decending runs move as a stack; otherwise move a single card.',
                'Dropping: place onto a card one rank higher, or onto an empty column.',
                'Stock: deals a new row of 10 cards.',
              ]),
              section('Deal rules (Settings)', [
                'Classic deal rule: you can only deal from stock when all 10 columns have at least one card.',
                'Unrestricted deal: allows dealing even with empty columns.',
              ]),
              section('Controls', [
                'Drag and drop: drag a movable card/run to a valid destination column.',
                'Tap mode Off: drag only.',
                'Tap mode On (two-tap): tap to select, then tap destination column to move.',
                'Tap mode Auto: tap to auto-move to the best available destination.',
                'Undo / Redo: step backward or forward through moves.',
                'Hint: quick check before dealing; highlights likely progress moves (not perfect).',
              ]),
              section('Daily calendar', [
                'Future days are locked.',
                'Blue dot = In progress.',
                'Red dot = Complete.',
                'Double red dots = Completed on day.',
                'Daily deals use curated solvable seeds.',
              ]),
              section('Scoring', [
                'Score is based on time and moves, with penalties for undos and hints.',
                'Time and moves are shown during play; final score is shown on the results screen.',
              ]),
              section('Privacy / Offline', [
                'App works offline.',
                'No ads.',
                'Online features (sync/leaderboards) are optional and may be added later.',
              ]),
            ],
          ),
        ),
      ),
    );
  }
}
