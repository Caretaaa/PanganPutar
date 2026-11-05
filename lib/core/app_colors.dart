import 'package:flutter/material.dart';

/// Semantic palette for Putaran Kebaikan.
///
/// Brand green and sunshine yellow are kept separate from accessible text/action
/// colors: #1F9D55 is a decorative brand accent, while filled actions use the
/// darker forest green so white button labels meet WCAG AA.
abstract final class AppColors {
  // Brand and core surfaces.
  static const cream = Color(0xFFFFFBF3);
  static const paper = Color(0xFFFFFFFF);
  static const ink = Color(0xFF12261B);
  static const textSecondaryLight = Color(0xFF4B5B51);
  static const leaf = Color(0xFF1F9D55);
  static const forest = Color(0xFF176B3A);
  static const forestDeep = Color(0xFF0E4D2B);
  static const sunshine = Color(0xFFFFB020);
  static const sunshineSoft = Color(0xFFFFF1CC);

  // Status colors use a foreground and a pale surface, never color alone.
  static const coral = Color(0xFFA6382A);
  static const coralSoft = Color(0xFFFCE1DA);
  static const positiveSoft = Color(0xFFE4F4E8);
  static const neutralSoft = Color(0xFFF1F3EF);
  static const grayMedium = textSecondaryLight;
  static const grayLight = Color(0xFFD7DED8);
  static const sand = Color(0xFFF7F5EF);
  static const cardBorderLight = Color(0xFFE5E9E4);

  // Dark theme remains available as an explicit user preference.
  static const parchment = Color(0xFFF4F5EE);
  static const textSecondaryDark = Color(0xFFC2CEC5);
  static const night = Color(0xFF121714);
  static const nightSurface = Color(0xFF1A211C);
  static const nightCard = Color(0xFF202A23);
  static const cardBorderDark = Color(0xFF3A473E);
  static const leafLight = Color(0xFF76D59A);
  static const sunshineDark = Color(0xFFFFD27A);
  static const coralDark = Color(0xFFFFB4A7);

  // Compatibility aliases used by the existing screens.
  static const espresso = ink;
  static const pine = forest;
  static const pineLight = leafLight;

  static const warnBgLight = sunshineSoft;
  static const warnBgDark = Color(0xFF3C3016);
  static const warnFgLight = Color(0xFF684200);
  static const warnFgDark = sunshineDark;

  static const badgeGratisFg = Colors.white;
  static const badgeGratisBg = forest;
  static const badgeBerbayarFg = ink;
  static const badgeBerbayarBg = sunshine;

  static Color textSecondaryFor(bool dark) =>
      dark ? textSecondaryDark : textSecondaryLight;

  static Color textSecondary(Brightness brightness) =>
      textSecondaryFor(brightness == Brightness.dark);

  static Color positiveFgFor(bool dark) => dark ? leafLight : forest;

  static Color cardBorder(bool dark) =>
      dark ? cardBorderDark : cardBorderLight;
}
