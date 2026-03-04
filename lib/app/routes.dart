import 'package:flutter/material.dart';

import '../features/daily/daily_calendar_screen.dart';
import '../features/home/home_screen.dart';
import '../features/help/help_screen.dart';
import '../features/play/play_screen.dart';
import '../features/preview/solution_preview_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/stats/stats_screen.dart';

class AppRoutes {
  static const home = '/';
  static const play = '/play';
  static const solutionPreview = '/solution-preview';
  static const settings = '/settings';
  static const stats = '/stats';
  static const dailyCalendar = '/daily-calendar';
  static const help = '/help';
}

Route<dynamic> onGenerateRoute(RouteSettings settings) {
  switch (settings.name) {
    case AppRoutes.home:
      return MaterialPageRoute<void>(builder: (_) => const HomeScreen());
    case AppRoutes.play:
      final args = settings.arguments as PlayScreenArgs?;
      if (args == null) {
        return MaterialPageRoute<void>(
          builder: (_) => const Scaffold(
            body: Center(child: Text('Missing play arguments')),
          ),
        );
      }
      return MaterialPageRoute<void>(builder: (_) => PlayScreen(args: args));
    case AppRoutes.solutionPreview:
      final args = settings.arguments as SolutionPreviewArgs?;
      if (args == null) {
        return MaterialPageRoute<void>(
          builder: (_) => const Scaffold(
            body: Center(child: Text('Missing preview arguments')),
          ),
        );
      }
      return MaterialPageRoute<void>(
        builder: (_) => SolutionPreviewScreen(args: args),
      );
    case AppRoutes.settings:
      return MaterialPageRoute<void>(builder: (_) => const SettingsScreen());
    case AppRoutes.dailyCalendar:
      return MaterialPageRoute<void>(
        builder: (_) => const DailyCalendarScreen(),
      );
    case AppRoutes.stats:
      return MaterialPageRoute<void>(builder: (_) => const StatsScreen());
    case AppRoutes.help:
      return MaterialPageRoute<void>(builder: (_) => const HelpScreen());
    default:
      return MaterialPageRoute<void>(builder: (_) => const HomeScreen());
  }
}
