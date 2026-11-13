import 'package:material_ui/material_ui.dart';

import '../../app/theme/guard_theme.dart';
import '../../core/services/guard_controller.dart';
import '../../shared/widgets/guard_widgets.dart';
import '../../shared/widgets/dot_arc.dart';
import '../settings/settings_screen.dart';
import '../appearance/appearance_screen.dart';
import '../diagnostics/diagnostics_screen.dart';
import '../onboarding/onboarding_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.controller});
  final GuardController controller;
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) {
      final s = controller.status;
      final warning = s.active && s.text('risk', 'IDLE') != 'IDLE';
      final phase = switch (s.phase) {
        'ACTIVE' => 'Камера включена',
        'STARTING' => 'Подключение камеры',
        'STOPPING' => 'Остановка',
        'ERROR' => 'Нужна проверка',
        _ => 'На паузе',
      };
      final title = warning
          ? 'Поднимите\nвзгляд'
          : s.active
          ? 'Смотрим\nвперёд'
          : 'Взгляд\nвперёд';
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(28, 12, 28, 28),
                children: [
                  Row(
                    children: [
                      const Text(
                        'WalkGuard',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w500,
                          letterSpacing: -.6,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        tooltip: 'Настройки',
                        onPressed: () => Navigator.push(
                          context,
                          GuardRoute<void>(
                            builder: (_) =>
                                SettingsScreen(controller: controller),
                          ),
                        ),
                        icon: const Icon(Icons.tune_rounded, size: 22),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  ErrorNotice(controller.error ?? s.data['error'] as String?),
                  Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: warning
                              ? GuardColors.red
                              : s.active
                              ? GuardColors.text
                              : GuardColors.muted,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        phase,
                        style: const TextStyle(
                          fontSize: 12,
                          color: GuardColors.muted,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  AnimatedSwitcher(
                    duration: MediaQuery.disableAnimationsOf(context)
                        ? Duration.zero
                        : const Duration(milliseconds: 320),
                    child: Align(
                      key: ValueKey(title),
                      alignment: Alignment.centerLeft,
                      child: Text(
                        title,
                        style: TextStyle(
                          fontSize: MediaQuery.sizeOf(context).width < 360
                              ? 46
                              : 56,
                          height: 1.02,
                          fontWeight: FontWeight.w400,
                          letterSpacing: -2,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    s.active
                        ? s.text('message', 'Анализ на устройстве')
                        : 'Телефон в руке.\nВнимание — дороге.',
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1.6,
                      color: GuardColors.muted,
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    height: 184,
                    child: DotArc(
                      settings: controller.settings,
                      color: warning ? GuardColors.red : GuardColors.text,
                      intensity: warning
                          ? 1
                          : s.active
                          ? .55
                          : .32,
                    ),
                  ),
                  const SizedBox(height: 28),
                  FilledButton(
                    onPressed:
                        !controller.loaded ||
                            controller.busy ||
                            s.phase == 'STOPPING'
                        ? null
                        : () async {
                            if (s.canStop) {
                              await controller.action('stop');
                            } else if (!s.ready) {
                              await Navigator.push(
                                context,
                                GuardRoute<void>(
                                  builder: (_) =>
                                      OnboardingScreen(controller: controller),
                                ),
                              );
                              await controller.refresh();
                            } else {
                              await controller.action('start');
                            }
                          },
                    key: const ValueKey('walk-toggle'),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          s.canStop ? Icons.stop_rounded : Icons.north_east,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Flexible(
                          child: Text(
                            s.canStop
                                ? 'Остановить'
                                : s.phase == 'STOPPING'
                                ? 'Остановка…'
                                : 'Начать прогулку',
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Center(
                    child: Text(
                      'Без интернета и записи видео',
                      style: TextStyle(fontSize: 11, color: GuardColors.muted),
                    ),
                  ),
                  const SizedBox(height: 28),
                  const Divider(),
                  GuardRow(
                    title: 'Сигнал',
                    value: switch (controller.settings.arcStyle) {
                      'CONTOUR' => 'Контур',
                      'SEGMENTS' => 'Штрихи',
                      _ => 'Точки',
                    },
                    onTap: () => Navigator.push(
                      context,
                      GuardRoute<void>(
                        builder: (_) =>
                            AppearanceScreen(controller: controller),
                      ),
                    ),
                  ),
                  const Divider(),
                  GuardRow(
                    title: 'Режим',
                    value: modeName(controller.settings.mode),
                    onTap: () => Navigator.push(
                      context,
                      GuardRoute<void>(
                        builder: (_) => SettingsScreen(controller: controller),
                      ),
                    ),
                  ),
                  const Divider(),
                  if (controller.settings.showMetrics) ...[
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: _Metric(
                            'Кадров / с',
                            s.active ? s.metric('fps') : '—',
                          ),
                        ),
                        Expanded(
                          child: _Metric(
                            'Обработка / мс',
                            s.active ? s.metric('lastMs') : '—',
                          ),
                        ),
                        IconButton(
                          tooltip: 'Диагностика системы',
                          onPressed: () => Navigator.push(
                            context,
                            GuardRoute<void>(
                              builder: (_) =>
                                  DiagnosticsScreen(controller: controller),
                            ),
                          ),
                          icon: const Icon(Icons.north_east, size: 20),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 28),
                  const Text(
                    'WalkGuard может пропускать препятствия.\nПродолжайте смотреть на дорогу.',
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.6,
                      color: GuardColors.muted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}

String modeName(String mode) => switch (mode) {
  'ECO' => 'Экономный',
  'PERFORMANCE' => 'Быстрый',
  _ => 'Баланс',
};

class _Metric extends StatelessWidget {
  const _Metric(this.label, this.value);
  final String label, value;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        value,
        style: const TextStyle(fontFamily: 'JetBrainsMono', fontSize: 20),
      ),
      const SizedBox(height: 4),
      Text(label, style: technicalStyle),
    ],
  );
}
