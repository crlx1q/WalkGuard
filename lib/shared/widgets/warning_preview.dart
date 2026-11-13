import 'package:material_ui/material_ui.dart';

import '../../app/theme/guard_theme.dart';
import '../../core/models/guard_settings.dart';
import 'dot_arc.dart';

class WarningPreview extends StatelessWidget {
  const WarningPreview({super.key, required this.settings, this.height = 280});
  final GuardSettings settings;
  final double height;
  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Образец точечного предупреждения. Камера не используется.',
    child: SizedBox(
      height: height,
      child: Column(
        children: [
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(top: settings.topOffset * .5),
              child: DotArc(settings: settings),
            ),
          ),
          if (settings.showText)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: Text(
                'Смотри вперёд',
                style: TextStyle(fontSize: 15, color: GuardColors.red),
              ),
            ),
          const SizedBox(height: 12),
          const Text(
            'Образец · камера выключена',
            style: TextStyle(fontSize: 12, color: GuardColors.muted),
          ),
        ],
      ),
    ),
  );
}
