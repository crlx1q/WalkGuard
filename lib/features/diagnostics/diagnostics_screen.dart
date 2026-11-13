import 'package:material_ui/material_ui.dart';

import '../../app/theme/guard_theme.dart';
import '../../core/services/guard_controller.dart';
import '../../shared/widgets/guard_widgets.dart';
import '../onboarding/onboarding_screen.dart';

class DiagnosticsScreen extends StatelessWidget {
  const DiagnosticsScreen({super.key, required this.controller});
  final GuardController controller;
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) {
      final s = controller.status;
      return GuardPage(
        title: 'Диагностика',
        children: [
          const TechnicalLabel('Текущая сессия'),
          const SizedBox(height: 16),
          const Text(
            'Данные устройства',
            style: TextStyle(fontSize: 29, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          const Text(
            'N/A — измерение ещё не получено. Отсутствие обнаружений не означает, что путь безопасен.',
            style: TextStyle(
              fontSize: 13,
              color: GuardColors.muted,
              height: 1.7,
            ),
          ),
          const SizedBox(height: 24),
          ErrorNotice(controller.error ?? s.data['error'] as String?),
          GuardPanel(
            child: Column(
              children: [
                MetricRow('Камера', s.text('camera', 'OFF')),
                MetricRow('Сервис', s.phase),
                MetricRow('Модель', s.text('engine', 'UNLOADED')),
                MetricRow('Кадров / с', s.active ? s.metric('fps') : 'N/A'),
                MetricRow('Среднее время', s.metric('averageMs', ' ms')),
                MetricRow('Последний анализ', s.metric('lastMs', ' ms')),
                MetricRow('Полный цикл', s.metric('pipelineMs', ' ms')),
                MetricRow('Пропущено кадров', s.text('skipped', '0')),
                MetricRow('Предупреждение', s.text('risk', 'IDLE')),
                MetricRow('Последний объект', s.text('lastDetection')),
                MetricRow('Файл модели', s.text('model')),
                MetricRow('Исполнение', s.text('runtime')),
                MetricRow('Разрешение', s.text('resolution')),
                MetricRow('Объектив', s.text('lens')),
                MetricRow('Положение', s.text('pose')),
                MetricRow('Температурный режим', s.text('thermal')),
                MetricRow(
                  'Целевая частота',
                  s.active ? s.text('effectiveTargetFps') : 'N/A',
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          GuardPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const TechnicalLabel('Тест без камеры', color: GuardColors.red),
                const SizedBox(height: 12),
                const Text(
                  'Проверить сигнал',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Камера не запускается. Тестовый оверлей с меткой DEMO исчезнет через 4,5 секунды. Для проверки остановите прогулку.',
                  style: TextStyle(
                    fontSize: 13,
                    color: GuardColors.muted,
                    height: 1.7,
                  ),
                ),
                const SizedBox(height: 20),
                OutlinedButton.icon(
                  onPressed: controller.busy || s.canStop || s.transitioning
                      ? null
                      : () async {
                          if (!s.granted('overlay')) {
                            await Navigator.push(
                              context,
                              GuardRoute<void>(
                                builder: (_) =>
                                    OnboardingScreen(controller: controller),
                              ),
                            );
                          } else {
                            await controller.action('demo');
                          }
                        },
                  icon: const Icon(Icons.visibility_outlined),
                  label: const Text('Показать DEMO'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: controller.busy ? null : controller.refresh,
            icon: const Icon(Icons.refresh),
            label: const Text('Обновить состояние'),
          ),
          const SizedBox(height: 16),
          const Text(
            'INFERENCE TIME — выполнение нейросети; Полный цикл включает преобразование кадра. Показатели последней сессии сохраняются в памяти до следующего запуска. Положение телефона — эвристика наклона, а не проверка видимости дороги.',
            style: TextStyle(
              fontSize: 12,
              color: GuardColors.muted,
              height: 1.7,
            ),
          ),
        ],
      );
    },
  );
}
