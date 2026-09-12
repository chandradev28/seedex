import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import 'src/app_controller.dart';
import 'src/core/theme.dart';
import 'src/presentation/onboarding_screen.dart';
import 'src/presentation/shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterForegroundTask.initCommunicationPort();
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  final controller = SeedexController();
  await controller.initialize();
  runApp(SeedexApp(controller: controller));
}

class SeedexApp extends StatelessWidget {
  const SeedexApp({required this.controller, super.key});

  final SeedexController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (BuildContext context, Widget? child) {
        final dark = controller.settings.darkMode;
        final overlay = SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: dark ? Brightness.light : Brightness.dark,
          systemNavigationBarColor: dark
              ? SeedexPalette.darkCanvas
              : SeedexPalette.surface,
          systemNavigationBarIconBrightness: dark
              ? Brightness.light
              : Brightness.dark,
          systemNavigationBarDividerColor: Colors.transparent,
        );
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: overlay,
          child: MaterialApp(
            title: 'Seedex',
            debugShowCheckedModeBanner: false,
            theme: SeedexTheme.light(),
            darkTheme: SeedexTheme.dark(),
            themeMode: dark ? ThemeMode.dark : ThemeMode.light,
            home: controller.settings.acceptedNotice
                ? WithForegroundTask(child: SeedexShell(controller: controller))
                : OnboardingScreen(controller: controller),
          ),
        );
      },
    );
  }
}
