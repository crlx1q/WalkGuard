import 'package:material_ui/material_ui.dart';

import '../../app/theme/guard_theme.dart';
import '../../core/services/guard_controller.dart';
import '../../shared/widgets/guard_widgets.dart';
import '../appearance/appearance_screen.dart';
import '../diagnostics/diagnostics_screen.dart';
import '../onboarding/onboarding_screen.dart';
import '../onboarding/welcome_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.controller});
  final GuardController controller;
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) {
      void open(Widget page) =>
          Navigator.push(context, GuardRoute<void>(builder: (_) => page));
      final s = controller.settings;
      return GuardPage(
        title: 'Настройки',
        children: [
          const SizedBox(height: 16),
          const Text(
            'Под ваш\nритм',
            style: TextStyle(
              fontSize: 40,
              height: 1.12,
              letterSpacing: -1.4,
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Внешний вид, отклик и работа камеры',
            style: TextStyle(fontSize: 13, color: GuardColors.muted),
          ),
          const SizedBox(height: 24),
          ErrorNotice(controller.error),
          const SectionLabel('Прогулка'),
          const Divider(),
          GuardRow(
            title: 'Обнаружение',
            subtitle: 'Режим анализа и чувствительность',
            value: switch (s.mode) {
              'ECO' => 'Эко',
              'PERFORMANCE' => 'Быстрый',
              _ => 'Баланс',
            },
            onTap: () => open(DetectionSettings(controller: controller)),
          ),
          const Divider(),
          GuardRow(
            title: 'Полукруг предупреждения',
            subtitle: 'Точки, свет и плавность появления',
            onTap: () => open(AppearanceScreen(controller: controller)),
          ),
          const Divider(),
          GuardRow(
            title: 'Вибрация',
            value: s.vibration ? 'Включена' : 'Выключена',
            onTap: () => open(FeedbackSettings(controller: controller)),
          ),
          const Divider(),
          const SectionLabel('Приложение'),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Показатели на главном'),
            subtitle: const Text(
              'Частота анализа и время обработки',
              style: TextStyle(color: GuardColors.muted, fontSize: 12),
            ),
            value: s.showMetrics,
            onChanged: (v) => controller.updateSetting('showMetrics', v),
          ),
          const Divider(),
          GuardRow(
            title: 'Разрешения',
            value: controller.status.ready ? 'Настроены' : 'Проверить',
            onTap: () => open(OnboardingScreen(controller: controller)),
          ),
          const Divider(),
          GuardRow(
            title: 'Диагностика',
            onTap: () => open(DiagnosticsScreen(controller: controller)),
          ),
          const Divider(),
          const SectionLabel('О WalkGuard'),
          GuardRow(
            title: 'Приватность и возможности',
            onTap: () => open(const AboutScreen()),
          ),
          const Divider(),
          GuardRow(
            title: 'Короткое знакомство',
            onTap: () =>
                open(WelcomeScreen(controller: controller, replay: true)),
          ),
          const Divider(),
          const SizedBox(height: 32),
          const Text('WalkGuard  /  0.3.1', style: technicalStyle),
        ],
      );
    },
  );
}

class DetectionSettings extends StatelessWidget {
  const DetectionSettings({super.key, required this.controller});
  final GuardController controller;
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) {
      final s = controller.settings;
      return GuardPage(
        title: 'Обнаружение',
        children: [
          ErrorNotice(controller.error),
          const SectionLabel('Режим анализа'),
          for (final option in [
            ('ECO', 'Экономный', '3 кадра/с · меньше нагрузка'),
            ('BALANCED', 'Баланс', '6 кадров/с · на каждый день'),
            ('PERFORMANCE', 'Быстрый', '10 кадров/с · выше расход энергии'),
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Material(
                color: s.mode == option.$1
                    ? GuardColors.card
                    : Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: s.mode == option.$1
                        ? const Color(0xFF555551)
                        : GuardColors.border,
                  ),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => controller.updateSetting('mode', option.$1),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                option.$2,
                                style: const TextStyle(fontSize: 16),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                option.$3,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: GuardColors.muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          s.mode == option.$1
                              ? Icons.radio_button_checked
                              : Icons.radio_button_unchecked,
                          size: 20,
                          color: s.mode == option.$1
                              ? GuardColors.text
                              : GuardColors.muted,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          const SizedBox(height: 12),
          const Text(
            'Это целевая частота. Реальная скорость зависит от телефона и температуры.',
            style: TextStyle(
              fontSize: 12,
              height: 1.6,
              color: GuardColors.muted,
            ),
          ),
          const SectionLabel('Предупреждения'),
          SettingSlider(
            label: 'Чувствительность',
            value: s.sensitivity,
            min: 0,
            max: 1,
            valueLabel: '${(s.sensitivity * 100).round()}%',
            onChanged: (v) => controller.updateSetting('sensitivity', v),
          ),
          const Text(
            'Выше — больше срабатываний, в том числе ложных.',
            style: TextStyle(fontSize: 12, color: GuardColors.muted),
          ),
          const SizedBox(height: 16),
          const Divider(),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Показывать предупреждения'),
            subtitle: const Text(
              'Выключает сигнал и вибрацию. Анализ продолжается.',
              style: TextStyle(fontSize: 12, color: GuardColors.muted),
            ),
            value: s.alerts,
            onChanged: (v) => controller.updateSetting('alerts', v),
          ),
          const Divider(),
          SettingSlider(
            label: 'Задержка скрытия',
            value: s.hideDelayMs.toDouble(),
            min: 350,
            max: 3000,
            valueLabel: '${(s.hideDelayMs / 1000).toStringAsFixed(2)} с',
            onChanged: (v) =>
                controller.updateSetting('hideDelayMs', v.round()),
          ),
        ],
      );
    },
  );
}

class FeedbackSettings extends StatelessWidget {
  const FeedbackSettings({super.key, required this.controller});
  final GuardController controller;
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) => GuardPage(
      title: 'Вибрация',
      children: [
        ErrorNotice(controller.error),
        const SectionLabel('Тактильный сигнал'),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Вибрация при предупреждении'),
          value: controller.settings.vibration,
          onChanged: (v) => controller.updateSetting('vibration', v),
        ),
        const Divider(),
        SettingSlider(
          label: 'Сила отклика',
          value: controller.settings.feedback,
          min: .2,
          max: 1,
          valueLabel: '${(controller.settings.feedback * 100).round()}%',
          onChanged: (v) => controller.updateSetting('feedback', v),
        ),
        const Text(
          'Короткий сигнал с интервалом не менее 4 секунд. Регулировка силы зависит от вибромотора телефона.',
          style: TextStyle(fontSize: 13, height: 1.7, color: GuardColors.muted),
        ),
      ],
    ),
  );
}

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});
  @override
  Widget build(BuildContext context) => GuardPage(
    title: 'О приложении',
    children: [
      const SizedBox(height: 24),
      const Text(
        'Локально.\nЛично.',
        style: TextStyle(fontSize: 44, height: 1.1, letterSpacing: -1.4),
      ),
      const SizedBox(height: 24),
      const Text(
        'Кадры существуют только в памяти телефона. Нет аккаунтов, рекламы, аналитики и отправки видео. Камера останавливается вместе с прогулкой и при блокировке экрана.',
        style: TextStyle(fontSize: 15, height: 1.7),
      ),
      const SectionLabel('Что замечает WalkGuard'),
      const Text(
        'Людей, велосипеды, автомобили, некоторые животные и другие объекты модели COCO. В предупреждениях используется только подходящее подмножество классов.',
        style: TextStyle(fontSize: 14, height: 1.7, color: GuardColors.muted),
      ),
      const SectionLabel('Ограничения'),
      const Text(
        'Ямы, открытые люки, бордюры, края дороги и ступени не поддерживаются. Темнота, наклон и закрытый объектив мешают обнаружению. Размер объекта не является расстоянием.\n\nWalkGuard не определяет, безопасно ли переходить дорогу, и может пропускать препятствия.',
        style: TextStyle(fontSize: 14, height: 1.7, color: GuardColors.muted),
      ),
      const SectionLabel('Компоненты'),
      const Divider(),
      const MetricRow('Версия', '0.3.1'),
      const Divider(),
      const MetricRow('Модель', 'EfficientDet-Lite0 INT8'),
      const Divider(),
      const MetricRow('Исполнение', 'LiteRT 1.4.2 / CPU'),
      const SizedBox(height: 24),
      OutlinedButton(
        onPressed: () => showLicensePage(
          context: context,
          applicationName: 'WalkGuard',
          applicationVersion: '0.3.1',
        ),
        child: const Text('Лицензии компонентов'),
      ),
    ],
  );
}

class SettingSlider extends StatefulWidget {
  const SettingSlider({
    super.key,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.valueLabel,
    required this.onChanged,
  });
  final String label, valueLabel;
  final double value, min, max;
  final ValueChanged<double> onChanged;
  @override
  State<SettingSlider> createState() => _SettingSliderState();
}

class _SettingSliderState extends State<SettingSlider> {
  double? drag;
  @override
  void didUpdateWidget(SettingSlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value) drag = null;
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 20),
    child: Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Text(widget.label, style: const TextStyle(fontSize: 15)),
            ),
            const SizedBox(width: 12),
            Text(widget.valueLabel, style: technicalStyle),
          ],
        ),
        const SizedBox(height: 12),
        Slider(
          value: drag ?? widget.value,
          min: widget.min,
          max: widget.max,
          onChanged: (v) => setState(() => drag = v),
          onChangeEnd: (v) {
            widget.onChanged(v);
            setState(() => drag = null);
          },
        ),
      ],
    ),
  );
}
