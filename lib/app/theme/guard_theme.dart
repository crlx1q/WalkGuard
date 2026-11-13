import 'package:material_ui/material_ui.dart';

abstract final class GuardColors {
  static const background = Color(0xFF080808),
      secondary = Color(0xFF111111),
      card = Color(0xFF181818),
      elevated = Color(0xFF262626),
      text = Color(0xFFF1F0ED),
      muted = Color(0xFF92928E),
      border = Color(0xFF292929),
      red = Color(0xFFFF5149);
}

ThemeData guardTheme() => ThemeData(
  useMaterial3: true,
  brightness: Brightness.dark,
  fontFamily: 'Manrope',
  scaffoldBackgroundColor: GuardColors.background,
  colorScheme: const ColorScheme.dark(
    primary: GuardColors.text,
    onPrimary: GuardColors.background,
    secondary: GuardColors.muted,
    surface: GuardColors.card,
    onSurface: GuardColors.text,
    error: GuardColors.red,
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: GuardColors.background,
    surfaceTintColor: Colors.transparent,
    elevation: 0,
    centerTitle: false,
    titleTextStyle: TextStyle(
      fontFamily: 'Manrope',
      fontSize: 18,
      fontWeight: FontWeight.w500,
      color: GuardColors.text,
    ),
  ),
  dividerTheme: const DividerThemeData(
    color: GuardColors.border,
    thickness: .5,
    space: 1,
  ),
  iconTheme: const IconThemeData(size: 20, color: GuardColors.muted),
  textButtonTheme: TextButtonThemeData(
    style: TextButton.styleFrom(
      foregroundColor: GuardColors.text,
      textStyle: const TextStyle(
        fontFamily: 'Manrope',
        fontWeight: FontWeight.w500,
      ),
    ),
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      minimumSize: const Size(double.infinity, 56),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      backgroundColor: GuardColors.text,
      foregroundColor: GuardColors.background,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      textStyle: const TextStyle(
        fontFamily: 'Manrope',
        fontSize: 15,
        fontWeight: FontWeight.w600,
      ),
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: GuardColors.text,
      minimumSize: const Size(0, 52),
      side: const BorderSide(color: GuardColors.border),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
  ),
  chipTheme: ChipThemeData(
    backgroundColor: GuardColors.background,
    selectedColor: GuardColors.text,
    side: const BorderSide(color: GuardColors.border),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    labelStyle: const TextStyle(fontFamily: 'Manrope', fontSize: 13),
  ),
  switchTheme: SwitchThemeData(
    thumbColor: const WidgetStatePropertyAll(GuardColors.text),
    trackColor: WidgetStateProperty.resolveWith(
      (s) => s.contains(WidgetState.selected)
          ? const Color(0xFF62625F)
          : GuardColors.elevated,
    ),
  ),
  sliderTheme: const SliderThemeData(
    activeTrackColor: GuardColors.text,
    thumbColor: GuardColors.text,
    inactiveTrackColor: GuardColors.border,
    overlayColor: Color(0x12FFFFFF),
    trackHeight: 2,
  ),
);
const technicalStyle = TextStyle(
  fontFamily: 'JetBrainsMono',
  color: GuardColors.muted,
  fontSize: 11,
  height: 1.6,
);
