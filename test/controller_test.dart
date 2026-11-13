import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:walkguard/core/models/guard_settings.dart';
import 'package:walkguard/core/models/guard_status.dart';
import 'package:walkguard/core/services/guard_bridge.dart';
import 'package:walkguard/core/services/guard_controller.dart';

class FakeBridge implements GuardBridge {
  final stream = StreamController<Map<dynamic, dynamic>>.broadcast(sync: true);
  Map<String, Object?> state = {'phase': 'STOPPED', 'camera': 'OFF'};
  Map<String, Object> saved = const GuardSettings().toMap();
  bool reject = false;
  final calls = <String>[];
  @override
  Stream<Map<dynamic, dynamic>> get events => stream.stream;
  @override
  Future<dynamic> call(String method, [Map<String, Object>? arguments]) async {
    calls.add(method);
    if (reject) throw StateError('permission denied');
    return switch (method) {
      'snapshot' => state,
      'settings' => saved,
      'saveSettings' => saved = arguments!,
      _ => null,
    };
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('settings survive a round trip', () {
    final s = const GuardSettings()
        .withValue('mode', 'ECO')
        .withValue('preview', true);
    expect(GuardSettings.fromMap(s.toMap()).toMap(), s.toMap());
  });
  test('invalid settings are clamped', () {
    final s = GuardSettings.fromMap({
      'mode': 'bad',
      'hideDelayMs': -5,
      'glow': double.nan,
    });
    expect(s.mode, 'BALANCED');
    expect(s.hideDelayMs, 350);
    expect(s.glow, .7);
  });
  test('missing metrics never invent performance', () {
    const s = GuardStatus({});
    expect(s.metric('fps'), 'N/A');
    expect(s.active, false);
    expect(s.ready, false);
  });
  test('permission readiness requires every real permission', () {
    expect(
      const GuardStatus({
        'permissions': {
          'camera': true,
          'overlay': true,
          'notifications': false,
        },
      }).ready,
      false,
    );
  });
  test('start never fakes the native ACTIVE state', () async {
    final bridge = FakeBridge();
    final c = GuardController(bridge: bridge);
    await c.initialize();
    await c.action('start');
    expect(c.status.phase, 'STOPPED');
    bridge.stream.add({'phase': 'STARTING'});
    expect(c.status.active, false);
    bridge.stream.add({'phase': 'ACTIVE', 'camera': 'ON'});
    expect(c.status.active, true);
    c.dispose();
    await bridge.stream.close();
  });
  test('stop waits for native state and events resynchronize', () async {
    final bridge = FakeBridge()..state = {'phase': 'ACTIVE'};
    final c = GuardController(bridge: bridge);
    await c.initialize();
    await c.action('stop');
    expect(c.status.active, true);
    bridge.stream.add({'phase': 'STOPPED', 'camera': 'OFF'});
    expect(c.status.active, false);
    c.dispose();
    await bridge.stream.close();
  });
  test('failed command exposes error and releases busy flag', () async {
    final bridge = FakeBridge();
    final c = GuardController(bridge: bridge);
    await c.initialize();
    bridge.reject = true;
    expect(await c.action('start'), false);
    expect(c.error, isNotNull);
    expect(c.busy, false);
    expect(c.status.active, false);
    c.dispose();
    await bridge.stream.close();
  });
  test('settings persist through native bridge', () async {
    final bridge = FakeBridge();
    final c = GuardController(bridge: bridge);
    await c.initialize();
    await c.save(c.settings.withValue('mode', 'PERFORMANCE'));
    expect(c.settings.mode, 'PERFORMANCE');
    expect(bridge.saved['mode'], 'PERFORMANCE');
    c.dispose();
    await bridge.stream.close();
  });
  test(
    'rapid independent setting changes do not overwrite each other',
    () async {
      final bridge = FakeBridge();
      final c = GuardController(bridge: bridge);
      await c.initialize();
      final a = c.updateSetting('mode', 'ECO');
      final b = c.updateSetting('vibration', false);
      await Future.wait([a, b]);
      expect(c.settings.mode, 'ECO');
      expect(c.settings.vibration, false);
      c.dispose();
      await bridge.stream.close();
    },
  );
  test('failed settings write keeps the last persisted settings', () async {
    final bridge = FakeBridge();
    final c = GuardController(bridge: bridge);
    await c.initialize();
    bridge.reject = true;
    await c.updateSetting('mode', 'ECO');
    expect(c.settings.mode, 'BALANCED');
    expect(c.error, contains('Настройки не сохранены'));
    c.dispose();
    await bridge.stream.close();
  });
}
