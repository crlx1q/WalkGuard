class GuardSettings {
  const GuardSettings({
    this.mode = 'BALANCED',
    this.sensitivity = .5,
    this.alerts = true,
    this.hideDelayMs = 1000,
    this.arcSize = 1,
    this.glow = .7,
    this.preview = false,
    this.showText = true,
    this.vibration = true,
    this.feedback = .6,
    this.arcStyle = 'MATRIX',
    this.arcThickness = 1,
    this.topOffset = 0,
    this.reduceMotion = false,
    this.welcomeComplete = false,
    this.showMetrics = true,
    this.dotDensity = 1,
    this.revealMs = 650,
  });
  final String mode, arcStyle;
  final double sensitivity,
      arcSize,
      glow,
      feedback,
      arcThickness,
      topOffset,
      dotDensity;
  final int hideDelayMs, revealMs;
  final bool alerts,
      preview,
      showText,
      vibration,
      reduceMotion,
      welcomeComplete,
      showMetrics;
  factory GuardSettings.fromMap(Map<dynamic, dynamic> m) {
    double number(String k, double fallback, [double min = 0, double max = 1]) {
      final v = (m[k] as num?)?.toDouble() ?? fallback;
      return v.isFinite ? v.clamp(min, max) : fallback;
    }

    return GuardSettings(
      mode: const ['ECO', 'BALANCED', 'PERFORMANCE'].contains(m['mode'])
          ? m['mode'] as String
          : 'BALANCED',
      sensitivity: number('sensitivity', .5),
      alerts: m['alerts'] as bool? ?? true,
      hideDelayMs: ((m['hideDelayMs'] as num?)?.toInt() ?? 1000).clamp(
        350,
        3000,
      ),
      arcSize: number('arcSize', 1, .7, 1.3),
      glow: number('glow', .7),
      preview: m['preview'] as bool? ?? false,
      showText: m['showText'] as bool? ?? true,
      vibration: m['vibration'] as bool? ?? true,
      feedback: number('feedback', .6, .2),
      arcStyle: const ['MATRIX', 'CONTOUR', 'SEGMENTS'].contains(m['arcStyle'])
          ? m['arcStyle'] as String
          : 'MATRIX',
      arcThickness: number('arcThickness', 1, .75, 2),
      topOffset: number('topOffset', 0, 0, 48),
      reduceMotion: m['reduceMotion'] as bool? ?? false,
      welcomeComplete: m['welcomeComplete'] as bool? ?? false,
      showMetrics: m['showMetrics'] as bool? ?? true,
      dotDensity: number('dotDensity', 1, .6, 1.4),
      revealMs: ((m['revealMs'] as num?)?.toInt() ?? 650).clamp(250, 1000),
    );
  }
  Map<String, Object> toMap() => {
    'mode': mode,
    'sensitivity': sensitivity,
    'alerts': alerts,
    'hideDelayMs': hideDelayMs,
    'arcSize': arcSize,
    'glow': glow,
    'preview': preview,
    'showText': showText,
    'vibration': vibration,
    'feedback': feedback,
    'arcStyle': arcStyle,
    'arcThickness': arcThickness,
    'topOffset': topOffset,
    'reduceMotion': reduceMotion,
    'welcomeComplete': welcomeComplete,
    'showMetrics': showMetrics,
    'dotDensity': dotDensity,
    'revealMs': revealMs,
  };
  GuardSettings withValue(String key, Object value) =>
      GuardSettings.fromMap({...toMap(), key: value});
}
