import 'package:flutter/material.dart';

import 'routes.dart';
import 'theme.dart';

class SpiderSolitaireApp extends StatelessWidget {
  const SpiderSolitaireApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Haylau Spider Solitaire',
      theme: buildAppTheme(),
      initialRoute: AppRoutes.home,
      onGenerateRoute: onGenerateRoute,
    );
  }
}
