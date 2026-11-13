import 'package:material_ui/material_ui.dart';

import '../../app/theme/guard_theme.dart';

class GuardPanel extends StatelessWidget {
  const GuardPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(24),
  });
  final Widget child;
  final EdgeInsets padding;
  @override
  Widget build(BuildContext context) => Material(
    color: GuardColors.secondary,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: BorderSide(color: GuardColors.border.withValues(alpha: .6)),
    ),
    clipBehavior: Clip.antiAlias,
    child: Padding(padding: padding, child: child),
  );
}

class TechnicalLabel extends StatelessWidget {
  const TechnicalLabel(this.text, {super.key, this.color});
  final String text;
  final Color? color;
  @override
  Widget build(BuildContext context) =>
      Text(text, style: technicalStyle.copyWith(color: color));
}

class MetricRow extends StatelessWidget {
  const MetricRow(this.label, this.value, {super.key});
  final String label, value;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: TechnicalLabel(label)),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(
              fontFamily: 'JetBrainsMono',
              fontSize: 12,
              height: 1.5,
            ),
          ),
        ),
      ],
    ),
  );
}

class GuardSymbol extends StatelessWidget {
  const GuardSymbol({super.key, this.size = 44, this.active = false});
  final double size;
  final bool active;
  @override
  Widget build(BuildContext context) => Semantics(
    label: 'WalkGuard',
    child: CustomPaint(
      size: Size.square(size),
      painter: _SymbolPainter(active),
    ),
  );
}

class _SymbolPainter extends CustomPainter {
  _SymbolPainter(this.active);
  final bool active;
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = GuardColors.text;
    final u = size.width / 9;
    const dots = [
      '001111100',
      '010000010',
      '100010001',
      '100010001',
      '100111001',
      '100010001',
      '010101010',
      '001000100',
      '000111000',
    ];
    for (var y = 0; y < dots.length; y++) {
      for (var x = 0; x < 9; x++) {
        if (dots[y][x] == '1') {
          canvas.drawCircle(Offset((x + .5) * u, (y + .5) * u), u * .28, p);
        }
      }
    }
    if (active) {
      p.color = GuardColors.red;
      canvas.drawCircle(Offset(size.width - u, u), u * .7, p);
    }
  }

  @override
  bool shouldRepaint(_SymbolPainter oldDelegate) =>
      oldDelegate.active != active;
}

class ErrorNotice extends StatelessWidget {
  const ErrorNotice(this.message, {super.key});
  final String? message;
  @override
  Widget build(BuildContext context) => message == null
      ? const SizedBox.shrink()
      : Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: GuardPanel(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.error_outline, color: GuardColors.red),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    message!,
                    style: const TextStyle(fontSize: 13, height: 1.6),
                  ),
                ),
              ],
            ),
          ),
        );
}

class GuardPage extends StatelessWidget {
  const GuardPage({super.key, required this.title, required this.children});
  final String title;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
    ),
    body: SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
            children: children,
          ),
        ),
      ),
    ),
  );
}

class GuardRoute<T> extends PageRouteBuilder<T> {
  GuardRoute({required WidgetBuilder builder})
    : super(
        transitionDuration: const Duration(milliseconds: 320),
        reverseTransitionDuration: const Duration(milliseconds: 240),
        pageBuilder: (context, animation, secondaryAnimation) =>
            builder(context),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          if (MediaQuery.disableAnimationsOf(context)) return child;
          final eased = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          );
          return FadeTransition(
            opacity: eased,
            child: SlideTransition(
              position: Tween(
                begin: const Offset(.035, 0),
                end: Offset.zero,
              ).animate(eased),
              child: child,
            ),
          );
        },
      );
}

class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 32, bottom: 12),
    child: Text(
      text,
      style: const TextStyle(fontSize: 13, color: GuardColors.muted),
    ),
  );
}

class GuardRow extends StatelessWidget {
  const GuardRow({
    super.key,
    required this.title,
    this.subtitle,
    this.value,
    this.onTap,
    this.leading,
  });
  final String title;
  final String? subtitle, value;
  final VoidCallback? onTap;
  final Widget? leading;
  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Row(
          children: [
            if (leading != null) ...[leading!, const SizedBox(width: 16)],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitle!,
                      style: const TextStyle(
                        fontSize: 12,
                        height: 1.5,
                        color: GuardColors.muted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (value != null) ...[
              const SizedBox(width: 12),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 120),
                child: Text(
                  value!,
                  textAlign: TextAlign.right,
                  style: technicalStyle,
                ),
              ),
            ],
            if (onTap != null) ...[
              const SizedBox(width: 12),
              const Icon(Icons.chevron_right, size: 18),
            ],
          ],
        ),
      ),
    ),
  );
}
