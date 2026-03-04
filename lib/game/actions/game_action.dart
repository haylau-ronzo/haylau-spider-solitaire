import '../model/game_state.dart';

abstract class GameAction {
  String get type;
  Map<String, dynamic> toJson();
  GameState apply(GameState state);
  GameState revert(GameState state);
}
