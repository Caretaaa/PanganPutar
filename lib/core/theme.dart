import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'tokens.dart';

// Montserrat is bundled locally and used consistently for headings and body.

const String _font = 'Montserrat';

TextTheme _textTheme(Color body) {
  // Skala mengikuti M3; bobot dikunci sesuai spesifikasi desain.
  const base = TextTheme(
    displayLarge: TextStyle(fontSize: 57, fontWeight: FontWeight.w800),
    displayMedium: TextStyle(fontSize: 45, fontWeight: FontWeight.w800),
    displaySmall: TextStyle(fontSize: 36, fontWeight: FontWeight.w800),
    headlineLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.w800),
    headlineMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
    headlineSmall: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
    titleLarge: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
    titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
    titleSmall: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
    bodyLarge: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w400,
      letterSpacing: 0,
    ),
    bodyMedium: TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w400,
      letterSpacing: 0,
    ),
    bodySmall: TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w400,
      letterSpacing: 0,
    ),
    labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
    labelMedium: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
    labelSmall: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
  );
  return base.apply(fontFamily: _font, bodyColor: body, displayColor: body);
}

/// Soft outline keeps card edges clear without competing with food imagery.
RoundedRectangleBorder _cardShape(Color side) => RoundedRectangleBorder(
  borderRadius: BorderRadius.circular(AppTokens.radiusCard),
  side: BorderSide(color: side, width: 1),
);

FilledButtonThemeData _filledLight() => FilledButtonThemeData(
  style: FilledButton.styleFrom(
    backgroundColor: AppColors.forest,
    foregroundColor: Colors.white,
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppTokens.radiusBtn),
    ),
    minimumSize: const Size(0, 48),
    textStyle: const TextStyle(
      fontFamily: _font,
      fontSize: 14,
      fontWeight: FontWeight.w700,
    ),
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
  ),
);

FilledButtonThemeData _filledDark() => FilledButtonThemeData(
  style: FilledButton.styleFrom(
    backgroundColor: AppColors.parchment,
    foregroundColor: AppColors.espresso,
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppTokens.radiusBtn),
    ),
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
    minimumSize: const Size(0, 48),
    textStyle: const TextStyle(
      fontFamily: _font,
      fontSize: 14,
      fontWeight: FontWeight.w700,
    ),
  ),
);

OutlinedButtonThemeData _outlinedLight() => OutlinedButtonThemeData(
  style: OutlinedButton.styleFrom(
    foregroundColor: AppColors.forest,
    side: const BorderSide(color: AppColors.forest, width: 1.3),
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppTokens.radiusBtn),
    ),
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
    minimumSize: const Size(0, 48),
    textStyle: const TextStyle(
      fontFamily: _font,
      fontSize: 14,
      fontWeight: FontWeight.w600,
    ),
  ),
);

OutlinedButtonThemeData _outlinedDark() => OutlinedButtonThemeData(
  style: OutlinedButton.styleFrom(
    foregroundColor: AppColors.leafLight,
    side: const BorderSide(color: AppColors.leafLight, width: 1.5),
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppTokens.radiusBtn),
    ),
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
    minimumSize: const Size(0, 48),
    textStyle: const TextStyle(
      fontFamily: _font,
      fontSize: 14,
      fontWeight: FontWeight.w600,
    ),
  ),
);

InputDecorationTheme _input({
  required Color fill,
  required Color border,
  required Color focus,
  required Color label,
}) => InputDecorationTheme(
  filled: true,
  fillColor: fill,
  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
  border: OutlineInputBorder(
    borderRadius: BorderRadius.circular(AppTokens.radiusInput),
    borderSide: BorderSide(color: border),
  ),
  enabledBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(AppTokens.radiusInput),
    borderSide: BorderSide(color: border),
  ),
  focusedBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(AppTokens.radiusInput),
    borderSide: BorderSide(color: focus, width: 1.6),
  ),
  errorBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(AppTokens.radiusInput),
    borderSide: const BorderSide(color: AppColors.coral, width: 1.2),
  ),
  focusedErrorBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(AppTokens.radiusInput),
    borderSide: const BorderSide(color: AppColors.coral, width: 1.6),
  ),
  labelStyle: TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    color: label,
  ),
  hintStyle: TextStyle(fontSize: 13, fontWeight: FontWeight.w400, color: label),
);

ThemeData buildLightTheme() {
  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    fontFamily: _font,
  );
  final text = _textTheme(AppColors.espresso);
  return base.copyWith(
    visualDensity: VisualDensity.standard,
    materialTapTargetSize: MaterialTapTargetSize.padded,
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        minimumSize: const Size(48, 48),
        visualDensity: VisualDensity.standard,
        tapTargetSize: MaterialTapTargetSize.padded,
      ),
    ),
    textTheme: text,
    scaffoldBackgroundColor: AppColors.cream,
    colorScheme: const ColorScheme(
      brightness: Brightness.light,
      primary: AppColors.forest,
      onPrimary: Colors.white,
      secondary: AppColors.forest,
      onSecondary: Colors.white,
      tertiary: AppColors.sunshine,
      onTertiary: AppColors.ink,
      error: AppColors.coral,
      onError: Colors.white,
      surface: AppColors.cream,
      onSurface: AppColors.espresso,
      surfaceContainerHighest: AppColors.sand,
      surfaceContainerLow: AppColors.paper,
      outline: AppColors.textSecondaryLight,
      outlineVariant: AppColors.cardBorderLight,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.cream,
      foregroundColor: AppColors.espresso,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: text.titleMedium?.copyWith(
        fontSize: 18,
        color: AppColors.espresso,
        fontWeight: FontWeight.w800,
      ),
    ),
    cardTheme: CardThemeData(
      color: AppColors.paper,
      elevation: 0,
      shadowColor: AppColors.ink.withValues(alpha: 0.045),
      surfaceTintColor: Colors.transparent,
      margin: EdgeInsets.zero,
      shape: _cardShape(AppColors.cardBorderLight),
    ),
    dividerTheme: const DividerThemeData(
      color: AppColors.cardBorderLight,
      thickness: 1,
      space: 1,
    ),
    // Keep older CTA call sites visually consistent with FilledButton.
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.forest,
        foregroundColor: Colors.white,
        disabledBackgroundColor: AppColors.grayLight,
        disabledForegroundColor: AppColors.grayMedium,
        elevation: 0,
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusBtn),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        minimumSize: const Size(0, 48),
        textStyle: const TextStyle(
          fontFamily: _font,
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
    filledButtonTheme: _filledLight(),
    outlinedButtonTheme: _outlinedLight(),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.forest,
        minimumSize: const Size(0, 48),
        textStyle: const TextStyle(
          fontFamily: _font,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    chipTheme: base.chipTheme.copyWith(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTokens.radiusBtn),
      ),
      backgroundColor: AppColors.neutralSoft,
      selectedColor: AppColors.positiveSoft,
      labelStyle: const TextStyle(
        fontFamily: _font,
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: AppColors.espresso,
      ),
      side: const BorderSide(color: AppColors.cardBorderLight),
    ),
    inputDecorationTheme: _input(
      fill: AppColors.paper,
      border: AppColors.cardBorderLight,
      focus: AppColors.forest,
      label: AppColors.textSecondaryLight,
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppColors.forest,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.paper,
      surfaceTintColor: Colors.transparent,
      shape: _cardShape(AppColors.cardBorderLight),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.paper,
      surfaceTintColor: Colors.transparent,
      indicatorColor: AppColors.positiveSoft,
      elevation: 0,
      height: 68,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      iconTheme: WidgetStateProperty.resolveWith(
        (s) => IconThemeData(
          color: s.contains(WidgetState.selected)
              ? AppColors.pine
              : AppColors.textSecondaryLight,
        ),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (s) => TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: s.contains(WidgetState.selected)
              ? AppColors.espresso
              : AppColors.textSecondaryLight,
        ),
      ),
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: AppColors.paper,
      indicatorColor: AppColors.positiveSoft,
      elevation: 0,
      groupAlignment: -0.9,
      labelType: NavigationRailLabelType.all,
      selectedIconTheme: const IconThemeData(color: AppColors.pine),
      unselectedIconTheme: const IconThemeData(
        color: AppColors.textSecondaryLight,
      ),
      selectedLabelTextStyle: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: AppColors.espresso,
      ),
      unselectedLabelTextStyle: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: AppColors.textSecondaryLight,
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.forestDeep,
      contentTextStyle: text.bodyMedium?.copyWith(
        color: Colors.white,
        fontWeight: FontWeight.w500,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTokens.radiusBtn),
      ),
    ),
    focusColor: AppColors.leaf.withValues(alpha: 0.12),
    hoverColor: AppColors.leaf.withValues(alpha: 0.06),
    splashFactory: InkSparkle.splashFactory,
  );
}

ThemeData buildDarkTheme() {
  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    fontFamily: _font,
  );
  final text = _textTheme(AppColors.parchment);
  return base.copyWith(
    visualDensity: VisualDensity.standard,
    materialTapTargetSize: MaterialTapTargetSize.padded,
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        minimumSize: const Size(48, 48),
        visualDensity: VisualDensity.standard,
        tapTargetSize: MaterialTapTargetSize.padded,
      ),
    ),
    textTheme: text,
    scaffoldBackgroundColor: AppColors.night,
    colorScheme: const ColorScheme(
      brightness: Brightness.dark,
      primary: AppColors.parchment,
      onPrimary: AppColors.espresso,
      secondary: AppColors.leafLight,
      onSecondary: AppColors.ink,
      tertiary: AppColors.sunshineDark,
      onTertiary: AppColors.ink,
      error: AppColors.coralDark,
      onError: Color(0xFF690005),
      surface: AppColors.nightSurface,
      onSurface: AppColors.parchment,
      surfaceContainerHighest: AppColors.nightCard,
      surfaceContainerLow: AppColors.nightCard,
      outline: AppColors.textSecondaryDark,
      outlineVariant: AppColors.cardBorderDark,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.night,
      foregroundColor: AppColors.parchment,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: text.titleMedium?.copyWith(
        fontSize: 18,
        color: AppColors.parchment,
        fontWeight: FontWeight.w800,
      ),
    ),
    cardTheme: CardThemeData(
      color: AppColors.nightCard,
      elevation: 0,
      shadowColor: Colors.black.withValues(alpha: 0.18),
      surfaceTintColor: Colors.transparent,
      margin: EdgeInsets.zero,
      shape: _cardShape(AppColors.cardBorderDark),
    ),
    dividerTheme: const DividerThemeData(
      color: AppColors.cardBorderDark,
      thickness: 1,
      space: 1,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.parchment,
        foregroundColor: AppColors.espresso,
        disabledBackgroundColor: AppColors.nightCard,
        disabledForegroundColor: AppColors.grayMedium,
        elevation: 0,
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusBtn),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        minimumSize: const Size(0, 48),
        textStyle: const TextStyle(
          fontFamily: _font,
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
    filledButtonTheme: _filledDark(),
    outlinedButtonTheme: _outlinedDark(),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.leafLight,
        minimumSize: const Size(0, 48),
        textStyle: const TextStyle(
          fontFamily: _font,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    chipTheme: base.chipTheme.copyWith(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTokens.radiusBtn),
      ),
      backgroundColor: Colors.white.withValues(alpha: 0.06),
      selectedColor: AppColors.leafLight.withValues(alpha: 0.18),
      labelStyle: const TextStyle(
        fontFamily: _font,
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: AppColors.parchment,
      ),
      side: const BorderSide(color: AppColors.cardBorderDark),
    ),
    inputDecorationTheme: _input(
      fill: Colors.white.withValues(alpha: 0.04),
      border: AppColors.cardBorderDark,
      focus: AppColors.leafLight,
      label: AppColors.parchment,
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppColors.leafLight,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.nightCard,
      surfaceTintColor: Colors.transparent,
      shape: _cardShape(AppColors.cardBorderDark),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.nightSurface,
      surfaceTintColor: Colors.transparent,
      indicatorColor: AppColors.leafLight.withValues(alpha: 0.18),
      elevation: 0,
      height: 68,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      iconTheme: WidgetStateProperty.resolveWith(
        (s) => IconThemeData(
          color: s.contains(WidgetState.selected)
              ? AppColors.leafLight
              : AppColors.textSecondaryDark,
        ),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (s) => TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: s.contains(WidgetState.selected)
              ? AppColors.parchment
              : AppColors.textSecondaryDark,
        ),
      ),
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: AppColors.nightSurface,
      indicatorColor: AppColors.leafLight.withValues(alpha: 0.18),
      elevation: 0,
      groupAlignment: -0.9,
      labelType: NavigationRailLabelType.all,
      selectedIconTheme: const IconThemeData(color: AppColors.leafLight),
      unselectedIconTheme: const IconThemeData(
        color: AppColors.textSecondaryDark,
      ),
      selectedLabelTextStyle: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: AppColors.parchment,
      ),
      unselectedLabelTextStyle: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: AppColors.textSecondaryDark,
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.parchment,
      contentTextStyle: text.bodyMedium?.copyWith(
        color: AppColors.espresso,
        fontWeight: FontWeight.w500,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTokens.radiusBtn),
      ),
    ),
    focusColor: AppColors.pineLight.withValues(alpha: 0.16),
    hoverColor: AppColors.pineLight.withValues(alpha: 0.08),
    splashFactory: InkSparkle.splashFactory,
  );
}
