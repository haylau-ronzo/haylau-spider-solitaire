import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'save_model.dart';

abstract class SaveRepo {
  Future<void> saveSlot(String slotId, SaveModel save);
  Future<SaveModel?> loadSlot(String slotId);
  Future<Map<String, SaveModel>> loadAllSlots();
  Future<void> deleteSlot(String slotId);
}

class InMemorySaveRepo implements SaveRepo {
  final Map<String, SaveModel> _saves = <String, SaveModel>{};

  @override
  Future<void> deleteSlot(String slotId) async {
    _saves.remove(slotId);
  }

  @override
  Future<Map<String, SaveModel>> loadAllSlots() async {
    return Map<String, SaveModel>.from(_saves);
  }

  @override
  Future<SaveModel?> loadSlot(String slotId) async {
    return _saves[slotId];
  }

  @override
  Future<void> saveSlot(String slotId, SaveModel save) async {
    _saves[slotId] = save;
  }
}

class LocalSaveRepo implements SaveRepo {
  static const _prefix = 'save.slot.';

  @override
  Future<void> deleteSlot(String slotId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_prefix$slotId');
  }

  @override
  Future<Map<String, SaveModel>> loadAllSlots() async {
    final prefs = await SharedPreferences.getInstance();
    final result = <String, SaveModel>{};

    for (final key in prefs.getKeys()) {
      if (!key.startsWith(_prefix)) {
        continue;
      }
      final encoded = prefs.getString(key);
      if (encoded == null) {
        continue;
      }
      final parsed = jsonDecode(encoded) as Map<String, dynamic>;
      final save = SaveModel.fromJson(parsed);
      result[save.slotId] = save;
    }
    return result;
  }

  @override
  Future<SaveModel?> loadSlot(String slotId) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = prefs.getString('$_prefix$slotId');
    if (encoded == null) {
      return null;
    }
    final parsed = jsonDecode(encoded) as Map<String, dynamic>;
    return SaveModel.fromJson(parsed);
  }

  @override
  Future<void> saveSlot(String slotId, SaveModel save) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(save.toJson());
    await prefs.setString('$_prefix$slotId', encoded);
  }
}
