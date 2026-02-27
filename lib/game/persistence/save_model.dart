import '../model/game_state.dart';

class SaveModel {
  const SaveModel({required this.gameState, required this.savedAt});

  final GameState gameState;
  final DateTime savedAt;
}
