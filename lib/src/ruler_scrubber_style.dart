import 'package:flutter/material.dart';

/// Colours and elevation used to draw a [RulerScrubber].
///
/// Supply this when the scrubber needs to use an application's design-system
/// tokens. Omitting it derives accessible defaults from [ThemeData].
class RulerScrubberStyle {
  const RulerScrubberStyle({
    required this.backgroundColor,
    required this.borderColor,
    required this.activeBorderColor,
    required this.minorTickColor,
    required this.majorTickColor,
    required this.needleColor,
    this.activeShadows = const [],
    this.activeNeedleShadows = const [],
  });

  final Color backgroundColor;
  final Color borderColor;
  final Color activeBorderColor;
  final Color minorTickColor;
  final Color majorTickColor;
  final Color needleColor;
  final List<BoxShadow> activeShadows;
  final List<BoxShadow> activeNeedleShadows;

  static RulerScrubberStyle fromTheme(ThemeData theme) {
    final scheme = theme.colorScheme;
    return RulerScrubberStyle(
      backgroundColor: scheme.surface,
      borderColor: scheme.outlineVariant,
      activeBorderColor: scheme.primary,
      minorTickColor: scheme.outlineVariant,
      majorTickColor: scheme.onSurfaceVariant,
      needleColor: scheme.onSurfaceVariant,
      activeShadows: const [BoxShadow(blurRadius: 8, color: Color(0x1F000000))],
      activeNeedleShadows: const [
        BoxShadow(blurRadius: 4, color: Color(0x33000000)),
      ],
    );
  }
}
