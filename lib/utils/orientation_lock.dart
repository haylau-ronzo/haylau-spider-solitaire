import 'package:flutter/services.dart';

import '../features/settings/settings_model.dart';

Future<void> applyOrientationLock(OrientationLock lock) {
  switch (lock) {
    case OrientationLock.landscape:
      return SystemChrome.setPreferredOrientations(const [
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    case OrientationLock.portrait:
      return SystemChrome.setPreferredOrientations(const [
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
  }
}
