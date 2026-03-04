import '../../game/model/difficulty.dart';

enum TapMode {
  off('Off (Drag only)'),
  onTwoTap('On (Two-tap)'),
  auto('Auto');

  const TapMode(this.label);
  final String label;
}

enum DealRule {
  classic('Classic'),
  unrestricted('Unrestricted');

  const DealRule(this.label);
  final String label;
}

enum AnimationMode {
  off('Off'),
  minimal('Minimal'),
  full('Full');

  const AnimationMode(this.label);
  final String label;
}

enum OrientationLock {
  landscape('Landscape'),
  portrait('Portrait');

  const OrientationLock(this.label);
  final String label;
}

class SettingsModel {
  const SettingsModel({
    required this.difficulty,
    required this.tapMode,
    required this.soundsOn,
    required this.dealRule,
    required this.animations,
    required this.previewNextCardOnDrag,
    required this.orientationLock,
    required this.ignoreVerifiedSolvableData,
  });

  static const defaults = SettingsModel(
    difficulty: Difficulty.fourSuit,
    tapMode: TapMode.onTwoTap,
    soundsOn: true,
    dealRule: DealRule.classic,
    animations: AnimationMode.minimal,
    previewNextCardOnDrag: false,
    orientationLock: OrientationLock.landscape,
    ignoreVerifiedSolvableData: false,
  );

  final Difficulty difficulty;
  final TapMode tapMode;
  final bool soundsOn;
  final DealRule dealRule;
  final AnimationMode animations;
  final bool previewNextCardOnDrag;
  final OrientationLock orientationLock;
  final bool ignoreVerifiedSolvableData;

  SettingsModel copyWith({
    Difficulty? difficulty,
    TapMode? tapMode,
    bool? soundsOn,
    DealRule? dealRule,
    AnimationMode? animations,
    bool? previewNextCardOnDrag,
    OrientationLock? orientationLock,
    bool? ignoreVerifiedSolvableData,
  }) {
    return SettingsModel(
      difficulty: difficulty ?? this.difficulty,
      tapMode: tapMode ?? this.tapMode,
      soundsOn: soundsOn ?? this.soundsOn,
      dealRule: dealRule ?? this.dealRule,
      animations: animations ?? this.animations,
      previewNextCardOnDrag:
          previewNextCardOnDrag ?? this.previewNextCardOnDrag,
      orientationLock: orientationLock ?? this.orientationLock,
      ignoreVerifiedSolvableData:
          ignoreVerifiedSolvableData ?? this.ignoreVerifiedSolvableData,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'difficulty': difficulty.name,
      'tapMode': tapMode.name,
      'soundsOn': soundsOn,
      'dealRule': dealRule.name,
      'animations': animations.name,
      'previewNextCardOnDrag': previewNextCardOnDrag,
      'orientationLock': orientationLock.name,
      'ignoreVerifiedSolvableData': ignoreVerifiedSolvableData,
    };
  }

  static SettingsModel fromJson(Map<String, dynamic> json) {
    return SettingsModel(
      difficulty: _parseDifficulty(json['difficulty'] as String?),
      tapMode: _parseTapMode(json['tapMode'] as String?),
      soundsOn: json['soundsOn'] as bool? ?? defaults.soundsOn,
      dealRule: _parseDealRule(json['dealRule'] as String?),
      animations: _parseAnimationMode(json['animations'] as String?),
      previewNextCardOnDrag:
          json['previewNextCardOnDrag'] as bool? ??
          defaults.previewNextCardOnDrag,
      orientationLock: _parseOrientationLock(
        json['orientationLock'] as String?,
      ),
      ignoreVerifiedSolvableData:
          json['ignoreVerifiedSolvableData'] as bool? ??
          defaults.ignoreVerifiedSolvableData,
    );
  }

  static Difficulty _parseDifficulty(String? name) {
    if (name == null) {
      return defaults.difficulty;
    }
    return Difficulty.values.firstWhere(
      (value) => value.name == name,
      orElse: () => defaults.difficulty,
    );
  }

  static TapMode _parseTapMode(String? name) {
    if (name == null) {
      return defaults.tapMode;
    }
    return TapMode.values.firstWhere(
      (value) => value.name == name,
      orElse: () => defaults.tapMode,
    );
  }

  static DealRule _parseDealRule(String? name) {
    if (name == null) {
      return defaults.dealRule;
    }
    return DealRule.values.firstWhere(
      (value) => value.name == name,
      orElse: () => defaults.dealRule,
    );
  }

  static AnimationMode _parseAnimationMode(String? name) {
    if (name == null) {
      return defaults.animations;
    }
    return AnimationMode.values.firstWhere(
      (value) => value.name == name,
      orElse: () => defaults.animations,
    );
  }

  static OrientationLock _parseOrientationLock(String? name) {
    if (name == null) {
      return defaults.orientationLock;
    }
    return OrientationLock.values.firstWhere(
      (value) => value.name == name,
      orElse: () => defaults.orientationLock,
    );
  }
}
