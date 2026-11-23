import 'package:material_ui/material_ui.dart';

import '../../app/theme/guard_theme.dart';
import '../../core/models/guard_settings.dart';
import '../../core/services/guard_controller.dart';
import '../../shared/widgets/guard_widgets.dart';
import '../../shared/widgets/warning_preview.dart';
import '../onboarding/onboarding_screen.dart';

class AppearanceScreen extends StatefulWidget {
  const AppearanceScreen({super.key, required this.controller});
  final GuardController controller;
  @override
  State<AppearanceScreen> createState() => _AppearanceScreenState();
}

class _AppearanceScreenState extends State<AppearanceScreen> {
  late GuardSettings draft = widget.controller.settings;
  int replay = 0;
  Future<void> commit() async {
    await widget.controller.save(draft);
    if (mounted && widget.controller.error != null) {
      setState(() => draft = widget.controller.settings);
    }
  }

  void change(String key, Object value) {
    setState(() => draft = draft.withValue(key, value));
    commit();
  }

  Widget slider(
    String key,
    String label,
    double value,
    double min,
    double max,
    String valueLabel, {
    bool integer = false,
  }) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 16),
    child: Column(
      children: [
        Row(
          children: [
            Expanded(child: Text(label, style: const TextStyle(fontSize: 14))),
            const SizedBox(width: 12),
            Text(valueLabel, style: technicalStyle),
          ],
        ),
        Slider(
          value: value,
          min: min,
          max: max,
          onChanged: (v) => setState(
            () => draft = draft.withValue(key, integer ? v.round() : v),
          ),
          onChangeEnd: (_) => commit(),
        ),
      ],
    ),
  );
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.controller,
    builder: (context, _) => Scaffold(
      appBar: AppBar(
        title: const Text('Внешний вид сигнала'),
        actions: [
          IconButton(
            tooltip: 'Повторить анимацию',
            onPressed: () => setState(() => replay++),
            icon: const Icon(Icons.replay, size: 20),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: CustomScrollView(
              slivers: [
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _PreviewHeader(
                    settings: draft,
                    replay: replay,
                    reduced: MediaQuery.disableAnimationsOf(context),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(28, 12, 28, 32),
                  sliver: SliverList.list(
                    children: [
                      ErrorNotice(widget.controller.error),
                      Row(
                        children: [
                          for (final item in [
                            ('MATRIX', 'Точки'),
                            ('CONTOUR', 'Контур'),
                            ('SEGMENTS', 'Штрихи'),
                          ])
                            Expanded(
                              child: Padding(
                                padding: EdgeInsets.only(
                                  right: item.$1 == 'SEGMENTS' ? 0 : 8,
                                ),
                                child: ChoiceChip(
                                  label: Text(
                                    item.$2,
                                    style: TextStyle(
                                      color: draft.arcStyle == item.$1
                                          ? GuardColors.background
                                          : GuardColors.text,
                                    ),
                                  ),
                                  selected: draft.arcStyle == item.$1,
                                  showCheckmark: false,
                                  onSelected: (_) =>
                                      change('arcStyle', item.$1),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SectionLabel('Геометрия'),
                      const Divider(),
                      slider(
                        'arcSize',
                        'Размер полукруга',
                        draft.arcSize,
                        .7,
                        1.3,
                        '${(draft.arcSize * 100).round()}%',
                      ),
                      slider(
                        'arcThickness',
                        draft.arcStyle == 'MATRIX'
                            ? 'Размер точек'
                            : 'Толщина линии',
                        draft.arcThickness,
                        .75,
                        2,
                        '${draft.arcThickness.toStringAsFixed(2)}×',
                      ),
                      if (draft.arcStyle == 'MATRIX')
                        slider(
                          'dotDensity',
                          'Плотность точек',
                          draft.dotDensity,
                          .6,
                          1.4,
                          '${(draft.dotDensity * 100).round()}%',
                        ),
                      slider(
                        'topOffset',
                        'Отступ от верхнего края',
                        draft.topOffset,
                        0,
                        48,
                        '${draft.topOffset.round()}',
                      ),
                      const SectionLabel('Свет и движение'),
                      const Divider(),
                      if (draft.arcStyle == 'MATRIX')
                        slider(
                          'glow',
                          'Свечение',
                          draft.glow,
                          0,
                          1,
                          '${(draft.glow * 100).round()}%',
                        ),
                      slider(
                        'revealMs',
                        'Плавность появления',
                        draft.revealMs.toDouble(),
                        250,
                        1000,
                        '${(draft.revealMs / 1000).toStringAsFixed(2)} с',
                        integer: true,
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Без анимации'),
                        subtitle: const Text(
                          'Также отключает переходы экранов',
                          style: TextStyle(
                            fontSize: 12,
                            color: GuardColors.muted,
                          ),
                        ),
                        value: draft.reduceMotion,
                        onChanged: (v) => change('reduceMotion', v),
                      ),
                      const SectionLabel('Содержимое'),
                      const Divider(),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Текст под сигналом'),
                        value: draft.showText,
                        onChanged: (v) => change('showText', v),
                      ),
                      const Divider(),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Кадр с камеры'),
                        subtitle: const Text(
                          'Внутри полукруга при предупреждении',
                          style: TextStyle(
                            fontSize: 12,
                            color: GuardColors.muted,
                          ),
                        ),
                        value: draft.preview,
                        onChanged: (v) => change('preview', v),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Проверьте положение сигнала на своём экране через DEMO. Прогулка должна быть остановлена.',
                        style: TextStyle(
                          color: GuardColors.muted,
                          fontSize: 12,
                          height: 1.6,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: () {
                          setState(
                            () => draft = GuardSettings.fromMap({
                              ...draft.toMap(),
                              'arcStyle': 'MATRIX',
                              'arcSize': 1,
                              'arcThickness': 1,
                              'topOffset': 0,
                              'glow': .7,
                              'showText': true,
                              'reduceMotion': false,
                              'preview': const GuardSettings().preview,
                              'dotDensity': 1,
                              'revealMs': 650,
                            }),
                          );
                          commit();
                        },
                        child: const Text('Восстановить оформление'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 12, 28, 12),
          child: OutlinedButton.icon(
            onPressed:
                widget.controller.status.canStop ||
                    widget.controller.status.transitioning ||
                    widget.controller.busy
                ? null
                : () async {
                    await commit();
                    if (!context.mounted || widget.controller.error != null) {
                      return;
                    }
                    if (!widget.controller.status.granted('overlay')) {
                      await Navigator.push(
                        context,
                        GuardRoute<void>(
                          builder: (_) =>
                              OnboardingScreen(controller: widget.controller),
                        ),
                      );
                    } else {
                      await widget.controller.action('demo');
                    }
                  },
            icon: const Icon(Icons.north_east, size: 18),
            label: const Text('На моём экране · DEMO'),
          ),
        ),
      ),
    ),
  );
}

class _PreviewHeader extends SliverPersistentHeaderDelegate {
  _PreviewHeader({
    required this.settings,
    required this.replay,
    required this.reduced,
  });
  final GuardSettings settings;
  final int replay;
  final bool reduced;
  @override
  double get minExtent => 256;
  @override
  double get maxExtent => 296;
  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) => Container(
    color: GuardColors.background,
    padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
    child: TweenAnimationBuilder<double>(
      key: ValueKey(replay),
      tween: Tween(begin: 0, end: 1),
      duration: reduced || settings.reduceMotion
          ? Duration.zero
          : Duration(milliseconds: settings.revealMs),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, (1 - value) * 6),
          child: child,
        ),
      ),
      child: WarningPreview(
        settings: settings,
        height: maxExtent - shrinkOffset.clamp(0, maxExtent - minExtent) - 24,
      ),
    ),
  );
  @override
  bool shouldRebuild(_PreviewHeader old) =>
      old.settings != settings ||
      old.replay != replay ||
      old.reduced != reduced;
}
