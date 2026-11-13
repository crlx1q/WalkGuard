import 'package:material_ui/material_ui.dart';

import '../core/services/guard_controller.dart';
import '../features/home/home_screen.dart';
import '../features/onboarding/welcome_screen.dart';
import 'theme/guard_theme.dart';

class WalkGuardApp extends StatefulWidget {
  const WalkGuardApp({super.key, this.controller});
  final GuardController? controller;
  @override
  State<WalkGuardApp> createState() => _WalkGuardAppState();
}

class _WalkGuardAppState extends State<WalkGuardApp> {
  late final controller = widget.controller ?? GuardController();
  @override
  void initState() {
    super.initState();
    controller.initialize();
  }

  @override
  void dispose() {
    if (widget.controller == null) controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'WalkGuard',
    debugShowCheckedModeBanner: false,
    theme: guardTheme(),
    builder: (context, child) => AnimatedBuilder(
      animation: controller,
      builder: (context, _) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          disableAnimations:
              MediaQuery.disableAnimationsOf(context) ||
              controller.settings.reduceMotion,
        ),
        child: child!,
      ),
    ),
    locale: const Locale('ru'),
    supportedLocales: const [Locale('ru'), Locale('en')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    home: AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        if (!controller.loaded) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return controller.settings.welcomeComplete
            ? HomeScreen(controller: controller)
            : WelcomeScreen(controller: controller);
      },
    ),
  );
}
