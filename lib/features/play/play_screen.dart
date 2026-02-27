import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/routes.dart';
import '../../game/engine/game_engine.dart';
import '../../game/model/deal_source.dart';
import '../../game/model/difficulty.dart';
import 'widgets/tableau_column_view.dart';

class PlayScreenArgs {
  const PlayScreenArgs({required this.difficulty, required this.dealSource});

  final Difficulty difficulty;
  final DealSource dealSource;
}

class PlayScreen extends StatefulWidget {
  const PlayScreen({super.key, required this.args});

  final PlayScreenArgs args;

  @override
  State<PlayScreen> createState() => _PlayScreenState();
}

class _PlayScreenState extends State<PlayScreen> {
  late final GameEngine _engine;
  Timer? _ticker;
  int? _selectedColumn;

  @override
  void initState() {
    super.initState();
    _engine = GameEngine();
    _engine.newGame(
      difficulty: widget.args.difficulty,
      dealSource: widget.args.dealSource,
    );
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  String _format(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    final hours = d.inHours.toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }

  void _onColumnTap(int column) {
    if (_selectedColumn == null) {
      setState(() => _selectedColumn = column);
      return;
    }
    if (_selectedColumn == column) {
      setState(() => _selectedColumn = null);
      return;
    }
    final from = _selectedColumn!;
    final startIndex = _engine.state.tableau.columns[from].lastIndexWhere(
      (card) => card.faceUp,
    );
    if (startIndex >= 0) {
      _engine.moveStack(from, startIndex, column);
    }
    setState(() => _selectedColumn = null);
  }

  @override
  Widget build(BuildContext context) {
    final state = _engine.state;
    final elapsed = DateTime.now().difference(state.startedAt);
    final stockRowsRemaining = state.stock.cards.length ~/ 10;

    return Scaffold(
      appBar: AppBar(title: const Text('Spider')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                Text('Time: ${_format(elapsed)}'),
                const SizedBox(width: 18),
                Text('Moves: ${state.moves}'),
                const Spacer(),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('Stock: $stockRowsRemaining rows'),
                    const SizedBox(height: 4),
                    FilledButton(
                      onPressed: state.stock.cards.length >= 10
                          ? () => setState(() => _engine.dealFromStock())
                          : null,
                      child: const Text('Deal'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: List.generate(
                  10,
                  (i) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: TableauColumnView(
                      cards: state.tableau.columns[i],
                      onTap: () => _onColumnTap(i),
                      isSelected: _selectedColumn == i,
                    ),
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: FilledButton.tonal(
                      onPressed: _engine.canUndo
                          ? () => setState(() => _engine.undo())
                          : null,
                      child: const Text('Undo'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.tonal(
                      onPressed: _engine.canRedo
                          ? () => setState(() => _engine.redo())
                          : null,
                      child: const Text('Redo'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.tonal(
                      onPressed: () {
                        _engine.requestHint();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Hint not implemented yet.'),
                          ),
                        );
                      },
                      child: const Text('Hint'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.tonal(
                      onPressed: () => setState(_engine.restartSameDeal),
                      child: const Text('Restart'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton(
                      onPressed: () =>
                          Navigator.of(context).pushNamedAndRemoveUntil(
                            AppRoutes.home,
                            (route) => false,
                          ),
                      child: const Text('Menu'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
