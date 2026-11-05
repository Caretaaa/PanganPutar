import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../core/tokens.dart';

/// Countdown ring for food pickup deadlines.
///
/// The center shows a short time value; screen readers receive the complete
/// remaining duration. Pass the original pickup window in [window] so the arc
/// reflects how much time is left.
class PutaranCountdownRing extends StatelessWidget {
  final Duration remaining;
  final Duration window;
  final double size;

  const PutaranCountdownRing({
    super.key,
    required this.remaining,
    required this.window,
    this.size = AppTokens.countdownRingCompact,
  });

  String _timeLabel(Duration duration) {
    if (duration <= Duration.zero) return '0m';
    if (duration.inHours > 0) return '${duration.inHours}j';
    return '${duration.inMinutes.clamp(1, 59)}m';
  }

  String _semanticDuration(Duration duration) {
    if (duration <= Duration.zero) return 'waktu pengambilan telah berakhir';
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    if (hours > 0 && minutes > 0) return '$hours jam $minutes menit';
    if (hours > 0) return '$hours jam';
    return '${duration.inMinutes.clamp(1, 59)} menit';
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final fraction = window <= Duration.zero
        ? 0.0
        : (remaining.inMilliseconds / window.inMilliseconds)
              .clamp(0.0, 1.0)
              .toDouble();
    final color = remaining <= Duration.zero
        ? (dark ? AppColors.coralDark : AppColors.coral)
        : remaining <= const Duration(minutes: 30)
        ? (dark ? AppColors.coralDark : AppColors.coral)
        : remaining <= const Duration(hours: 1)
        ? (dark ? AppColors.warnFgDark : AppColors.warnFgLight)
        : (dark ? AppColors.leafLight : AppColors.forest);
    final track = dark
        ? AppColors.leafLight.withValues(alpha: 0.18)
        : AppColors.leaf.withValues(alpha: 0.14);

    return Semantics(
      label: 'Batas pengambilan: ${_semanticDuration(remaining)}',
      child: ExcludeSemantics(
        child: SizedBox.square(
          dimension: size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CircularProgressIndicator(
                value: fraction,
                strokeWidth: 3,
                strokeCap: StrokeCap.round,
                color: color,
                backgroundColor: track,
              ),
              Text(
                _timeLabel(remaining),
                maxLines: 1,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Round price sticker for the food card image corner.
///
/// Use [free] for free offers; paid offers use the sunshine surface with dark
/// text, making the two pricing modes distinct without relying on wording.
class PutaranPriceBadge extends StatelessWidget {
  final String label;
  final bool free;
  final double size;

  const PutaranPriceBadge({
    super.key,
    required this.label,
    this.free = false,
    this.size = AppTokens.priceBadge,
  });

  @override
  Widget build(BuildContext context) {
    final foreground = free
        ? AppColors.badgeGratisFg
        : AppColors.badgeBerbayarFg;
    final background = free
        ? AppColors.badgeGratisBg
        : AppColors.badgeBerbayarBg;

    return Semantics(
      label: free ? 'Gratis' : label,
      child: ExcludeSemantics(
        child: Container(
          width: size,
          height: size,
          padding: const EdgeInsets.all(AppTokens.space8),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: background,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppColors.ink.withValues(alpha: 0.12),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Text(
            free ? 'GRATIS' : label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: foreground,
              fontWeight: FontWeight.w800,
              height: 1.1,
            ),
          ),
        ),
      ),
    );
  }
}
