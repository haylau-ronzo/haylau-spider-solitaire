import 'save_model.dart';

abstract class SaveRepo {
  Future<void> saveCurrentGame(SaveModel save);
  Future<SaveModel?> loadCurrentGame();
}

class InMemorySaveRepo implements SaveRepo {
  SaveModel? _current;

  @override
  Future<SaveModel?> loadCurrentGame() async => _current;

  @override
  Future<void> saveCurrentGame(SaveModel save) async {
    _current = save;
  }
}
