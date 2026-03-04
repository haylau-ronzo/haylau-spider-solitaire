import 'package:flutter/material.dart';

import 'app/app.dart';
import 'app/app_services.dart';
import 'utils/orientation_lock.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await AppServices.initialize();
  await applyOrientationLock(
    AppServices.settingsRepo.current().orientationLock,
  );

  runApp(const SpiderSolitaireApp());
}
