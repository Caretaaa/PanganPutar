import 'package:flutter/material.dart';

import 'tokens.dart';

/// Breakpoint tunggal untuk seluruh layar (desain.md §3.1).
enum AppSize { compact, medium, expanded }

AppSize appSizeOf(double w) => w < 500
    ? AppSize.compact
    : w < 760
    ? AppSize.medium
    : AppSize.expanded;

/// Page spacing; [AppContentFrame] owns the desktop content measure.
EdgeInsets pagePadding(BuildContext context) {
  final w = MediaQuery.sizeOf(context).width;
  final s = appSizeOf(w);
  final side = switch (s) {
    AppSize.compact => AppTokens.pagePadPhone,
    AppSize.medium => AppTokens.pagePadTablet,
    AppSize.expanded => AppTokens.pagePadTablet,
  };
  return EdgeInsets.fromLTRB(side, 12, side, 16);
}

/// Extent maksimum kolom grid listing: 1 kolom di compact, 2–3 kolom di atasnya.
double gridExtentFor(AppSize s) => switch (s) {
  AppSize.compact => AppTokens.gridExtentCompact,
  AppSize.medium => AppTokens.gridExtentMedium,
  AppSize.expanded => AppTokens.gridExtentExpanded,
};

/// Apakah shell memakai NavigationRail (rail mulai 500 — kriteria penerimaan).
bool useNavigationRail(AppSize s) => s != AppSize.compact;

/// A shared readable canvas for both shell pages and pushed routes.
/// Keep navigation outside this frame; size changes never hide page actions.
class AppContentFrame extends StatelessWidget {
  final Widget child;

  /// Page bodies fill the viewport height. Short bars and footers set this to
  /// false so the frame sizes to its child instead of the whole screen.
  final bool fillHeight;

  const AppContentFrame({
    super.key,
    required this.child,
    this.fillHeight = true,
  });

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    heightFactor: fillHeight ? null : 1,
    child: ConstrainedBox(
      constraints: const BoxConstraints(
        maxWidth: AppTokens.maxWidthTablet + 2 * AppTokens.pagePadTablet,
      ),
      child: child,
    ),
  );
}

/// Keep headings readable instead of squeezing them beside a long badge/CTA.
class AdaptiveSectionHeader extends StatelessWidget {
  final Widget title;
  final Widget? leading;
  final Widget? action;
  const AdaptiveSectionHeader({
    super.key,
    required this.title,
    this.leading,
    this.action,
  });

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final heading = Row(
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: 8)],
          Expanded(child: title),
        ],
      );
      if (action == null) return heading;
      if (constraints.maxWidth < 480 ||
          MediaQuery.textScalerOf(context).scale(14) > 18) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [heading, const SizedBox(height: 10), action!],
        );
      }
      return Row(
        children: [
          Expanded(child: heading),
          const SizedBox(width: 16),
          action!,
        ],
      );
    },
  );
}
