import 'package:material_ui/material_ui.dart';

import '../../app/theme/guard_theme.dart';
import '../../core/services/guard_controller.dart';
import '../../shared/widgets/guard_widgets.dart';
import '../../shared/widgets/dot_arc.dart';
import 'onboarding_screen.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({
    super.key,
    required this.controller,
    this.replay = false,
  });
  final GuardController controller;
  final bool replay;
  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  int step = 0;
  bool saving = false;
  static const titles = [
    'Телефон в руке.\nВзгляд вперёд.',
    'Сигнал, который\nвы заметите.',
    'Всё остаётся\nна телефоне.',
  ];
  static const bodies = [
    'WalkGuard замечает некоторые объекты через заднюю камеру и напоминает поднять взгляд. Камера должна видеть пространство перед вами.',
    'Точечный полукруг появляется поверх других приложений. Касания проходят сквозь него. Вибрацию и внешний вид можно настроить.',
    'Без облака, регистрации и записи видео. Камера включается только по вашему нажатию и останавливается при блокировке экрана.',
  ];
  Future<void> finish({required bool setup}) async {
    if (saving) return;
    setState(() => saving = true);
    if (widget.replay) {
      Navigator.pop(context);
      return;
    }
    if (setup) {
      await Navigator.push(
        context,
        GuardRoute<void>(
          builder: (_) => OnboardingScreen(controller: widget.controller),
        ),
      );
    }
    await widget.controller.updateSetting('welcomeComplete', true);
    if (mounted) setState(() => saving = false);
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.controller,
    builder: (context, _) => Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: widget.replay,
        title: const Text('WalkGuard'),
        actions: [
          if (!widget.replay)
            TextButton(
              onPressed: saving ? null : () => finish(setup: false),
              child: const Text('Позже'),
            ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(28, 20, 28, 24),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: (constraints.maxHeight - 44).clamp(
                  0,
                  double.infinity,
                ),
              ),
              child: IntrinsicHeight(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text('${step + 1} / 3', style: technicalStyle),
                        const Spacer(),
                        for (var i = 0; i < 3; i++)
                          Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: AnimatedContainer(
                              duration: MediaQuery.disableAnimationsOf(context)
                                  ? Duration.zero
                                  : const Duration(milliseconds: 220),
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: i == step
                                    ? GuardColors.text
                                    : GuardColors.border,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    AnimatedSwitcher(
                      duration: MediaQuery.disableAnimationsOf(context)
                          ? Duration.zero
                          : const Duration(milliseconds: 260),
                      child: Align(
                        key: ValueKey(step),
                        alignment: Alignment.centerLeft,
                        child: Text(
                          titles[step],
                          style: TextStyle(
                            fontSize: MediaQuery.sizeOf(context).width < 360
                                ? 34
                                : 40,
                            height: 1.15,
                            letterSpacing: -1.2,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),
                    SizedBox(
                      height: (constraints.maxHeight * .28).clamp(160.0, 280.0),
                      child: DotArc(
                        settings: widget.controller.settings.withValue(
                          'arcStyle',
                          'MATRIX',
                        ),
                        color: step == 1 ? GuardColors.red : GuardColors.text,
                        intensity: step == 1 ? 1 : .45,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      step == 1
                          ? 'Образец предупреждения'
                          : step == 2
                          ? 'Обработка на устройстве'
                          : 'Помощник на прогулке',
                      style: technicalStyle,
                    ),
                    const SizedBox(height: 32),
                    Text(
                      bodies[step],
                      style: const TextStyle(
                        fontSize: 15,
                        height: 1.7,
                        color: GuardColors.text,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      step == 0
                          ? 'Приложение не заменяет внимательность и может ошибаться.'
                          : step == 1
                          ? 'Этот сигнал — демонстрация, камера выключена.'
                          : 'Разрешения можно настроить сейчас или перед прогулкой.',
                      style: const TextStyle(
                        fontSize: 12,
                        height: 1.6,
                        color: GuardColors.muted,
                      ),
                    ),
                    const Spacer(),
                    const SizedBox(height: 32),
                    ErrorNotice(widget.controller.error),
                    FilledButton(
                      key: const ValueKey('welcome-next'),
                      onPressed: saving
                          ? null
                          : step < 2
                          ? () => setState(() => step++)
                          : () => finish(setup: !widget.replay),
                      child: Text(
                        step < 2
                            ? 'Продолжить'
                            : widget.replay
                            ? 'Вернуться'
                            : 'Настроить разрешения',
                      ),
                    ),
                    if (step > 0)
                      Center(
                        child: TextButton(
                          onPressed: saving
                              ? null
                              : () => setState(() => step--),
                          child: const Text('Назад'),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
