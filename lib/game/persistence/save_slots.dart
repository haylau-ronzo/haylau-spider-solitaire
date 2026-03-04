class SaveSlots {
  SaveSlots._();

  static const random = 'random';

  static String daily(String dateKeyLocal) => 'daily:$dateKeyLocal';

  static bool isDaily(String slot) => slot.startsWith('daily:');

  static String? dailyDateKey(String slot) {
    if (!isDaily(slot)) {
      return null;
    }
    return slot.substring('daily:'.length);
  }
}
