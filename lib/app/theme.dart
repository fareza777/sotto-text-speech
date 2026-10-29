import 'dart:ui' show FontVariation;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show SystemUiOverlayStyle;

class SottoPalette {
  const SottoPalette({
    required this.paper,
    required this.surface,
    required this.surfaceRaised,
    required this.ink,
    required this.muted,
    required this.accent,
    required this.accentInk,
    required this.accentWash,
    required this.hairline,
    required this.olive,
    required this.danger,
  });

  final Color paper;
  final Color surface;
  final Color surfaceRaised;
  final Color ink;
  final Color muted;
  final Color accent;
  final Color accentInk;
  final Color accentWash;
  final Color hairline;
  final Color olive;
  final Color danger;

  static const light = SottoPalette(
    paper: Color(0xFFFAF7F1),
    surface: Color(0xFFFFFFFF),
    surfaceRaised: Color(0xFFF4EFE6),
    ink: Color(0xFF1B1714),
    muted: Color(0xFF736A5F),
    accent: Color(0xFFB3542C),
    accentInk: Color(0xFFFFFFFF),
    accentWash: Color(0xFFF6E4D9),
    hairline: Color(0xFFE8E0D4),
    olive: Color(0xFF55604B),
    danger: Color(0xFFA33A32),
  );

  static const dark = SottoPalette(
    paper: Color(0xFF121110),
    surface: Color(0xFF1B1917),
    surfaceRaised: Color(0xFF252220),
    ink: Color(0xFFF4EFE7),
    muted: Color(0xFFA79D91),
    accent: Color(0xFFE8A57C),
    accentInk: Color(0xFF2A160C),
    accentWash: Color(0xFF3A2A20),
    hairline: Color(0xFF2F2B27),
    olive: Color(0xFF9DAF93),
    danger: Color(0xFFE58A80),
  );
}

@immutable
class SottoTokens extends ThemeExtension<SottoTokens> {
  const SottoTokens({
    required this.paper,
    required this.surface,
    required this.surfaceRaised,
    required this.ink,
    required this.muted,
    required this.accent,
    required this.accentInk,
    required this.accentWash,
    required this.hairline,
    required this.olive,
    required this.danger,
    required this.isDark,
  });

  final Color paper;
  final Color surface;
  final Color surfaceRaised;
  final Color ink;
  final Color muted;
  final Color accent;
  final Color accentInk;
  final Color accentWash;
  final Color hairline;
  final Color olive;
  final Color danger;
  final bool isDark;

  @override
  SottoTokens copyWith() => this;

  @override
  SottoTokens lerp(ThemeExtension<SottoTokens>? other, double t) {
    if (other is! SottoTokens) return this;
    return t < 0.5 ? this : other;
  }

  static SottoTokens of(BuildContext context) =>
      Theme.of(context).extension<SottoTokens>()!;
}

TextStyle _display(double size, {double height = 1.02, Color? color, FontStyle? style}) {
  return TextStyle(
    fontFamily: 'InstrumentSerif',
    fontSize: size,
    height: height,
    letterSpacing: -0.4,
    color: color,
    fontStyle: style,
    fontWeight: FontWeight.w400,
  );
}

TextStyle _sans(
  double size,
  FontWeight weight, {
  double height = 1.5,
  double? letterSpacing,
  Color? color,
}) {
  return TextStyle(
    fontFamily: 'Manrope',
    fontSize: size,
    fontWeight: weight,
    height: height,
    letterSpacing: letterSpacing,
    color: color,
    fontVariations: [FontVariation('wght', weight.value.toDouble())],
  );
}

ThemeData buildTheme(Brightness brightness) {
  final isDark = brightness == Brightness.dark;
  final p = isDark ? SottoPalette.dark : SottoPalette.light;

  final scheme = ColorScheme.fromSeed(
    seedColor: p.accent,
    brightness: brightness,
  ).copyWith(
    primary: p.accent,
    onPrimary: p.accentInk,
    primaryContainer: p.accentWash,
    onPrimaryContainer: isDark ? p.accent : const Color(0xFF5C2A14),
    secondary: p.olive,
    onSecondary: isDark ? const Color(0xFF14180F) : Colors.white,
    surface: p.surface,
    onSurface: p.ink,
    surfaceContainerLowest: p.paper,
    surfaceContainerLow: p.paper,
    surfaceContainer: p.surfaceRaised,
    surfaceContainerHigh: p.surfaceRaised,
    surfaceContainerHighest: p.surfaceRaised,
    onSurfaceVariant: p.muted,
    outline: p.hairline,
    outlineVariant: p.hairline,
    error: p.danger,
  );

  final textTheme = TextTheme(
    displayLarge: _display(58, color: p.ink),
    displayMedium: _display(46, color: p.ink),
    displaySmall: _display(38, color: p.ink),
    headlineLarge: _display(32, height: 1.12, color: p.ink),
    headlineMedium: _display(27, height: 1.15, color: p.ink),
    headlineSmall: _display(23, height: 1.2, color: p.ink),
    titleLarge: _sans(20, FontWeight.w700, height: 1.3, letterSpacing: -0.2, color: p.ink),
    titleMedium: _sans(16, FontWeight.w700, height: 1.35, letterSpacing: -0.1, color: p.ink),
    titleSmall: _sans(14, FontWeight.w700, height: 1.35, color: p.ink),
    bodyLarge: _sans(16, FontWeight.w400, height: 1.6, color: p.ink),
    bodyMedium: _sans(14, FontWeight.w400, height: 1.55, color: p.ink),
    bodySmall: _sans(12.5, FontWeight.w500, height: 1.45, color: p.muted),
    labelLarge: _sans(15, FontWeight.w700, height: 1.2, letterSpacing: 0.1, color: p.ink),
    labelMedium: _sans(12, FontWeight.w700, height: 1.2, letterSpacing: 0.5, color: p.muted),
    labelSmall: _sans(11, FontWeight.w700, height: 1.2, letterSpacing: 0.7, color: p.muted),
  );

  final radius16 = BorderRadius.circular(16);
  final radius24 = BorderRadius.circular(24);

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: p.paper,
    fontFamily: 'Manrope',
    textTheme: textTheme,
    splashFactory: InkSparkle.splashFactory,
    extensions: [
      SottoTokens(
        paper: p.paper,
        surface: p.surface,
        surfaceRaised: p.surfaceRaised,
        ink: p.ink,
        muted: p.muted,
        accent: p.accent,
        accentInk: p.accentInk,
        accentWash: p.accentWash,
        hairline: p.hairline,
        olive: p.olive,
        danger: p.danger,
        isDark: isDark,
      ),
    ],
    appBarTheme: AppBarTheme(
      backgroundColor: p.paper,
      surfaceTintColor: Colors.transparent,
      foregroundColor: p.ink,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: textTheme.titleLarge,
      systemOverlayStyle: isDark
          ? SystemUiOverlayStyle.light
          : SystemUiOverlayStyle.dark,
    ),
    cardTheme: CardThemeData(
      color: p.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: radius24,
        side: BorderSide(color: p.hairline),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: p.accent,
        foregroundColor: p.accentInk,
        minimumSize: const Size(0, 54),
        padding: const EdgeInsets.symmetric(horizontal: 24),
        shape: RoundedRectangleBorder(borderRadius: radius16),
        textStyle: textTheme.labelLarge,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: p.ink,
        minimumSize: const Size(0, 52),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        side: BorderSide(color: p.hairline),
        shape: RoundedRectangleBorder(borderRadius: radius16),
        textStyle: textTheme.labelLarge,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: p.accent,
        textStyle: textTheme.labelLarge,
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 72,
      backgroundColor: p.surface,
      surfaceTintColor: Colors.transparent,
      indicatorColor: p.accentWash,
      elevation: 0,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      labelTextStyle: WidgetStatePropertyAll(textTheme.labelSmall),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return IconThemeData(
          size: 24,
          color: selected ? p.accent : p.muted,
        );
      }),
    ),
    sliderTheme: SliderThemeData(
      trackHeight: 3,
      activeTrackColor: p.accent,
      inactiveTrackColor: p.hairline,
      thumbColor: p.accent,
      overlayColor: p.accent.withValues(alpha: 0.12),
      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
      overlayShape: const RoundSliderOverlayShape(overlayRadius: 18),
      trackShape: const RoundedRectSliderTrackShape(),
      year2023: false,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: p.surfaceRaised,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      hintStyle: textTheme.bodyMedium?.copyWith(color: p.muted),
      border: OutlineInputBorder(
        borderRadius: radius16,
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: radius16,
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: radius16,
        borderSide: BorderSide(color: p.accent, width: 1.4),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: p.surfaceRaised,
      selectedColor: p.accentWash,
      side: BorderSide(color: p.hairline),
      shape: const StadiumBorder(),
      labelStyle: textTheme.labelSmall,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      showCheckmark: false,
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: p.surface,
      surfaceTintColor: Colors.transparent,
      modalBackgroundColor: p.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      showDragHandle: true,
      dragHandleColor: p.hairline,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: p.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      titleTextStyle: textTheme.headlineSmall,
      contentTextStyle: textTheme.bodyMedium,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: isDark ? p.surfaceRaised : p.ink,
      contentTextStyle: textTheme.bodyMedium?.copyWith(
        color: isDark ? p.ink : Colors.white,
      ),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    dividerTheme: DividerThemeData(color: p.hairline, thickness: 1, space: 1),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: p.accent,
      linearTrackColor: p.hairline,
      circularTrackColor: p.hairline,
    ),
    listTileTheme: ListTileThemeData(
      iconColor: p.muted,
      textColor: p.ink,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
    ),
  );
}
