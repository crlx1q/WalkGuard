import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:walkguard/app/app.dart';
import 'package:walkguard/core/services/guard_controller.dart';

import 'controller_test.dart' show FakeBridge;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    for (final entry in {
      'Manrope': 'assets/fonts/Manrope.ttf',
      'JetBrainsMono': 'assets/fonts/JetBrainsMono.ttf',
      'MaterialIcons': 'fonts/MaterialIcons-Regular.otf',
    }.entries) {
      final loader = FontLoader(entry.key)
        ..addFont(rootBundle.load(entry.value));
      await loader.load();
    }
  });
  testWidgets('standby UI renders real empty metrics', (tester) async {
    tester.view.physicalSize = const Size(432, 1120);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final c = GuardController(
      bridge: FakeBridge()..saved['welcomeComplete'] = true,
    );
    await tester.pumpWidget(WalkGuardApp(controller: c));
    await tester.pumpAndSettle();
    expect(find.text('Взгляд\nвперёд'), findsOneWidget);
    expect(find.text('Начать прогулку'), findsOneWidget);
    expect(find.text('—'), findsNWidgets(2));
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/home.png'),
    );
    await tester.pumpWidget(const SizedBox());
    c.dispose();
  });
  testWidgets('small screen and large text allow scrolling to setup', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.platformDispatcher.textScaleFactorTestValue = 1.4;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final c = GuardController(
      bridge: FakeBridge()..saved['welcomeComplete'] = true,
    );
    await tester.pumpWidget(WalkGuardApp(controller: c));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('walk-toggle')),
      300,
    );
    await tester.tap(find.byKey(const ValueKey('walk-toggle')));
    await tester.pumpAndSettle();
    expect(find.text('Подготовка'), findsOneWidget);
    expect(find.text('Камера'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    c.dispose();
  });
  testWidgets('settings navigation updates and preserves the real saved mode', (
    tester,
  ) async {
    final c = GuardController(
      bridge: FakeBridge()..saved['welcomeComplete'] = true,
    );
    await tester.pumpWidget(WalkGuardApp(controller: c));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Настройки'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Обнаружение'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Экономный'));
    await tester.pumpAndSettle();
    expect(c.settings.mode, 'ECO');
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Экономный'), 300);
    expect(find.text('Экономный'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    c.dispose();
  });
  testWidgets(
    'first launch can defer setup, persists and never starts camera',
    (tester) async {
      tester.view.physicalSize = const Size(432, 1120);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final bridge = FakeBridge();
      final c = GuardController(bridge: bridge);
      await tester.pumpWidget(WalkGuardApp(controller: c));
      await tester.pumpAndSettle();
      expect(find.text('1 / 3'), findsOneWidget);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/welcome.png'),
      );
      await tester.tap(find.byKey(const ValueKey('welcome-next')));
      await tester.pumpAndSettle();
      expect(find.text('2 / 3'), findsOneWidget);
      await tester.tap(find.text('Позже'));
      await tester.pumpAndSettle();
      expect(c.settings.welcomeComplete, true);
      expect(bridge.calls, isNot(contains('start')));
      await tester.pumpWidget(const SizedBox());
      c.dispose();
      final reopened = GuardController(bridge: bridge);
      await tester.pumpWidget(WalkGuardApp(controller: reopened));
      await tester.pumpAndSettle();
      expect(find.text('Взгляд\nвперёд'), findsOneWidget);
      expect(find.text('1 / 3'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      reopened.dispose();
    },
  );
  testWidgets('welcome remains recoverable if preference save fails', (
    tester,
  ) async {
    final bridge = FakeBridge();
    final c = GuardController(bridge: bridge);
    await tester.pumpWidget(WalkGuardApp(controller: c));
    await tester.pumpAndSettle();
    bridge.reject = true;
    await tester.tap(find.text('Позже'));
    await tester.pumpAndSettle();
    expect(c.settings.welcomeComplete, false);
    expect(find.textContaining('Настройки не сохранены'), findsOneWidget);
    bridge.reject = false;
    await tester.tap(find.text('Позже'));
    await tester.pumpAndSettle();
    expect(find.text('Взгляд\nвперёд'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    c.dispose();
  });
  testWidgets('welcome at large text leads to permissions without starting', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.4;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final bridge = FakeBridge();
    final c = GuardController(bridge: bridge);
    await tester.pumpWidget(WalkGuardApp(controller: c));
    await tester.pumpAndSettle();
    for (var i = 0; i < 3; i++) {
      await tester.ensureVisible(find.byKey(const ValueKey('welcome-next')));
      await tester.tap(find.byKey(const ValueKey('welcome-next')));
      await tester.pumpAndSettle();
    }
    expect(find.text('Подготовка'), findsOneWidget);
    expect(bridge.calls, isNot(contains('start')));
    expect(tester.takeException(), isNull);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(c.settings.welcomeComplete, true);
    await tester.pumpWidget(const SizedBox());
    c.dispose();
  });
  testWidgets(
    'appearance presets persist without changing detection settings',
    (tester) async {
      tester.view.physicalSize = const Size(432, 1120);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final bridge = FakeBridge()..saved['welcomeComplete'] = true;
      bridge.saved['sensitivity'] = .8;
      bridge.saved['mode'] = 'ECO';
      final c = GuardController(bridge: bridge);
      await tester.pumpWidget(WalkGuardApp(controller: c));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Настройки'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Полукруг предупреждения'),
        300,
      );
      await tester.tap(find.text('Полукруг предупреждения'));
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/appearance.png'),
      );
      await tester.tap(find.widgetWithText(ChoiceChip, 'Штрихи'));
      await tester.pumpAndSettle();
      expect(c.settings.arcStyle, 'SEGMENTS');
      expect(c.settings.sensitivity, .8);
      expect(c.settings.mode, 'ECO');
      await tester.scrollUntilVisible(find.text('Без анимации'), 300);
      await tester.tap(find.text('Без анимации'));
      await tester.pumpAndSettle();
      expect(c.settings.reduceMotion, true);
      await tester.scrollUntilVisible(
        find.text('Восстановить оформление'),
        300,
      );
      await tester.tap(find.text('Восстановить оформление'));
      await tester.pumpAndSettle();
      expect(c.settings.arcStyle, 'MATRIX');
      expect(c.settings.reduceMotion, false);
      expect(c.settings.sensitivity, .8);
      expect(bridge.calls, isNot(contains('start')));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      c.dispose();
    },
  );
  testWidgets(
    'appearance remains usable on a small screen with enlarged text',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 1.4;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final c = GuardController(
        bridge: FakeBridge()..saved['welcomeComplete'] = true,
      );
      await tester.pumpWidget(WalkGuardApp(controller: c));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Сигнал'), 300);
      await tester.tap(find.text('Сигнал'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ChoiceChip, 'Точки'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Восстановить оформление'),
        300,
      );
      expect(find.text('На моём экране · DEMO'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      c.dispose();
    },
  );
}
