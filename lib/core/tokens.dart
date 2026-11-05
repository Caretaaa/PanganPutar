/// Shared layout, shape, and motion values for the Putaran design system.
abstract final class AppTokens {
  // Shape: generous round cards, with tighter controls.
  static const radiusCard = 22.0;
  static const radiusInput = 14.0;
  static const radiusBtn = 14.0;
  static const radiusChip = 999.0;
  static const radiusPhoto = 18.0;

  // Spacing scale.
  static const space2 = 2.0;
  static const space4 = 4.0;
  static const space8 = 8.0;
  static const space12 = 12.0;
  static const space16 = 16.0;
  static const space20 = 20.0;
  static const space24 = 24.0;
  static const space32 = 32.0;
  static const pagePadPhone = 20.0;
  static const pagePadTablet = 24.0;
  static const gapCard = 12.0;
  static const gapSection = 24.0;

  // Responsive layout.
  static const maxWidthPhone = 600.0;
  static const maxWidthTablet = 840.0;
  static const gridExtentCompact = 360.0;
  static const gridExtentMedium = 280.0;
  static const gridExtentExpanded = 220.0;
  static const feedMaxWidth = 840.0;

  // Motion and touch.
  static const animFast = Duration(milliseconds: 180);
  static const animStandard = Duration(milliseconds: 280);
  static const minTouch = 44.0;
  static const countdownRingCompact = 44.0;
  static const priceBadge = 76.0;

  // Feed behavior.
  static const segeraBerakhirWindow = Duration(hours: 3);
  static const hampirHabisSisa = 2;
}
