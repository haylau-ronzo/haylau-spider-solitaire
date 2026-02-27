import '../model/game_state.dart';

abstract class GameAction {
  GameState apply(GameState state);
  GameState revert(GameState state);
}
