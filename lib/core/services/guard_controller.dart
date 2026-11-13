import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';

import '../models/guard_settings.dart';
import '../models/guard_status.dart';
import 'guard_bridge.dart';

class GuardController extends ChangeNotifier with WidgetsBindingObserver {
  GuardController({GuardBridge? bridge})
    : bridge = bridge ?? AndroidGuardBridge();
  final GuardBridge bridge;
  GuardSettings settings = const GuardSettings();
  GuardStatus status = const GuardStatus({});
  bool loaded = false, busy = false;
  String? error;
  StreamSubscription<Map<dynamic, dynamic>>? _subscription;
  bool _disposed = false;
  Future<void> _saveQueue = Future.value();
  GuardSettings? _desiredSettings;
  Future<void> initialize() async {
    WidgetsBinding.instance.addObserver(this);
    try {
      _subscription = bridge.events.listen(
        (event) {
          status = GuardStatus({...status.data, ...event});
          _notify();
        },
        onError: (Object e) {
          error = 'Поток состояния недоступен: $e';
          _notify();
        },
      );
      settings = GuardSettings.fromMap(await bridge.call('settings') as Map);
      await refresh();
    } catch (e) {
      error = 'Android-компонент недоступен: $e';
    }
    loaded = true;
    _notify();
  }

  Future<void> refresh() async {
    try {
      status = GuardStatus(await bridge.call('snapshot') as Map);
    } catch (e) {
      error = 'Не удалось получить состояние: $e';
    }
    _notify();
  }

  Future<bool> action(String method) async {
    if (busy) return false;
    busy = true;
    error = null;
    _notify();
    try {
      await bridge.call(method);
      await refresh();
      return true;
    } catch (e) {
      error = e is PlatformException
          ? e.message ?? 'Не удалось выполнить команду'
          : e.toString();
      return false;
    } finally {
      busy = false;
      _notify();
    }
  }

  Future<void> updateSetting(String key, Object value) =>
      save((_desiredSettings ?? settings).withValue(key, value));

  Future<void> save(GuardSettings next) {
    _desiredSettings = next;
    final task = _saveQueue.then((_) async {
      final result = await bridge.call('saveSettings', next.toMap());
      settings = GuardSettings.fromMap(result as Map);
      if (identical(_desiredSettings, next)) _desiredSettings = null;
      error = null;
      _notify();
    });
    _saveQueue = task.catchError((Object e) {
      if (identical(_desiredSettings, next)) _desiredSettings = null;
      error = 'Настройки не сохранены: $e';
      _notify();
    });
    return _saveQueue;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(refresh());
  }

  void clearError() {
    error = null;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_subscription?.cancel());
    super.dispose();
  }
}
