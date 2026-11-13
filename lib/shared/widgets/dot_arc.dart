import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../core/models/guard_settings.dart';

/// Deterministic polar dot field. No assets, SVG, random particles or ticker.
/// Geometry and fading match the native Android warning renderer.
class DotArc extends StatelessWidget {
  const DotArc({
    super.key,
    required this.settings,
    this.color = const Color(0xFFFF3B35),
    this.intensity = 1,
  });
  final GuardSettings settings;
  final Color color;
  final double intensity;
  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: CustomPaint(
      painter: DotArcPainter(settings, color: color, intensity: intensity),
      size: Size.infinite,
    ),
  );
}

class DotArcPainter extends CustomPainter {
  DotArcPainter(
    this.settings, {
    this.color = const Color(0xFFFF3B35),
    this.intensity = 1,
  });
  final GuardSettings settings;
  final Color color;
  final double intensity;
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final rx = math.min(size.width * .53, size.width * .45 * settings.arcSize);
    final ry = math.min(size.height - 24, rx * .88);
    final cy = 8.0;
    final p = Paint()..style = PaintingStyle.fill;
    final rect = Rect.fromLTRB(cx - rx, cy - ry, cx + rx, cy + ry);
    if (settings.arcStyle != 'MATRIX') {
      p
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 1.4 * settings.arcThickness
        ..color = color.withValues(alpha: intensity);
      if (settings.arcStyle == 'SEGMENTS') {
        for (var i = 0; i < 35; i++) {
          canvas.drawArc(
            rect,
            (i * 5.14 + .8) * math.pi / 180,
            3.5 * math.pi / 180,
            false,
            p,
          );
        }
      } else {
        canvas.drawArc(rect, 0, math.pi, false, p);
      }
      return;
    }
    final gap = 5.2 / settings.dotDensity;
    final rows = math.min(24, (ry * .68 / gap).round());
    final columns = (math.pi * rx / gap).round().clamp(48, 180);
    for (var row = rows - 1; row >= 0; row--) {
      final radial = math.pow(1 - row / rows, 2.8).toDouble();
      for (var col = 0; col <= columns; col++) {
        final angle = col / columns * math.pi;
        final envelope = math.pow(math.sin(angle), .65).toDouble();
        final a = (radial * envelope * intensity).clamp(0.0, 1.0);
        if (a < .008) continue;
        final point = Offset(
          cx + math.cos(angle) * (rx - row * gap),
          cy + math.sin(angle) * (ry - row * gap),
        );
        if (row < 5 && settings.glow > 0) {
          p.color = color.withValues(alpha: a * .055 * settings.glow);
          canvas.drawCircle(point, 6 * settings.arcThickness, p);
          p.color = color.withValues(alpha: a * .11 * settings.glow);
          canvas.drawCircle(point, 2.8 * settings.arcThickness, p);
        }
        p.color = color.withValues(alpha: a);
        canvas.drawCircle(
          point,
          (.65 + radial * .3) * settings.arcThickness,
          p,
        );
      }
    }
    p
      ..style = PaintingStyle.stroke
      ..strokeWidth = .6;
    for (var i = 0; i < 90; i++) {
      p.color = color.withValues(
        alpha:
            math.pow(math.sin((i + .5) / 90 * math.pi), 2).toDouble() *
            .42 *
            intensity,
      );
      canvas.drawArc(rect, i * math.pi / 90, math.pi / 90 + .002, false, p);
    }
  }

  @override
  bool shouldRepaint(DotArcPainter old) =>
      old.settings != settings ||
      old.color != color ||
      old.intensity != intensity;
}
