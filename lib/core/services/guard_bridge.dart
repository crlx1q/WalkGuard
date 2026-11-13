import 'package:flutter/services.dart';

abstract class GuardBridge {
  Stream<Map<dynamic, dynamic>> get events;
  Future<dynamic> call(String method, [Map<String, Object>? arguments]);
}

class AndroidGuardBridge implements GuardBridge {
  static const _commands = MethodChannel('walkguard/commands');
  static const _events = EventChannel('walkguard/events');
  @override
  Stream<Map<dynamic, dynamic>> get events => _events
      .receiveBroadcastStream()
      .map((e) => Map<dynamic, dynamic>.from(e as Map));
  @override
  Future<dynamic> call(String method, [Map<String, Object>? arguments]) =>
      _commands.invokeMethod<dynamic>(method, arguments);
}
