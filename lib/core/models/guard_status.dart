class GuardStatus {
  const GuardStatus(this.data);
  final Map<dynamic, dynamic> data;
  String get phase => data['phase'] as String? ?? 'STOPPED';
  bool get active => phase == 'ACTIVE';
  bool get transitioning => phase == 'STARTING' || phase == 'STOPPING';
  bool get canStop => active || phase == 'STARTING';
  String text(String key, [String fallback = 'N/A']) =>
      data[key]?.toString() ?? fallback;
  String metric(String key, [String suffix = '']) {
    final value = data[key];
    if (value is! num || !value.isFinite) return 'N/A';
    return '${value.toStringAsFixed(1)}$suffix';
  }

  Map<dynamic, dynamic> get permissions =>
      data['permissions'] as Map? ?? const {};
  bool granted(String key) => permissions[key] == true;
  bool get ready => ['camera', 'overlay', 'notifications'].every(granted);
}
