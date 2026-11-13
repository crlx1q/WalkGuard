import 'package:material_ui/material_ui.dart';

import '../../app/theme/guard_theme.dart';
import '../../core/services/guard_controller.dart';
import '../../shared/widgets/guard_widgets.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key, required this.controller});
  final GuardController controller;
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) {
      final s = controller.status;
      final index = !s.granted('camera')
          ? 0
          : !s.granted('overlay')
          ? 1
          : !s.granted('notifications')
          ? 2
          : 3;
      final entries = [
        (
          'Камера',
          'Анализирует изображение на телефоне. Видео не записывается.',
          'camera',
          'requestCamera',
        ),
        (
          'Поверх других приложений',
          'Показывает точечный сигнал, не блокируя касания.',
          'overlay',
          'overlaySettings',
        ),
        (
          'Уведомления',
          'Позволяют остановить камеру, не возвращаясь в приложение.',
          'notifications',
          'requestNotifications',
        ),
      ];
      return GuardPage(
        title: 'Подготовка',
        children: [
          const SizedBox(height: 20),
          Text('$index из 3 разрешений', style: technicalStyle),
          const SizedBox(height: 16),
          Text(
            index == 3 ? 'Можно\nначинать' : 'Всего три\nразрешения',
            style: const TextStyle(
              fontSize: 40,
              height: 1.12,
              letterSpacing: -1.4,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Камера запустится только после нажатия «Начать прогулку».',
            style: TextStyle(
              fontSize: 14,
              height: 1.6,
              color: GuardColors.muted,
            ),
          ),
          const SizedBox(height: 32),
          ErrorNotice(controller.error),
          for (var i = 0; i < entries.length; i++) ...[
            const Divider(),
            const SizedBox(height: 24),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 36,
                  child: s.granted(entries[i].$3)
                      ? const Icon(
                          Icons.check,
                          size: 18,
                          color: GuardColors.text,
                        )
                      : Text('0${i + 1}', style: technicalStyle),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entries[i].$1,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        entries[i].$2,
                        style: const TextStyle(
                          fontSize: 13,
                          height: 1.6,
                          color: GuardColors.muted,
                        ),
                      ),
                      if (index == i) ...[
                        const SizedBox(height: 16),
                        OutlinedButton(
                          onPressed: controller.busy
                              ? null
                              : () => controller.action(entries[i].$4),
                          child: Text(
                            i == 1 ? 'Открыть настройки Android' : 'Разрешить',
                          ),
                        ),
                      ],
                      if (s.granted(entries[i].$3))
                        const Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: Text('Разрешено', style: technicalStyle),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],
          const Divider(),
          const SizedBox(height: 24),
          if (index == 3)
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('К главному экрану'),
            )
          else
            TextButton(
              onPressed: controller.busy
                  ? null
                  : () => controller.action(
                      index == 2 ? 'notificationSettings' : 'appSettings',
                    ),
              child: const Text('Не получается разрешить?'),
            ),
          const SizedBox(height: 16),
          const Text(
            'Android может скрывать предупреждение на защищённых экранах. Выданные разрешения можно отозвать в настройках телефона.',
            style: TextStyle(
              fontSize: 12,
              height: 1.6,
              color: GuardColors.muted,
            ),
          ),
        ],
      );
    },
  );
}
