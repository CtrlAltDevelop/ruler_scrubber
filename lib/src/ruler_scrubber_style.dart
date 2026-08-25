import 'package:material_ui/material_ui.dart';

import 'ruler_scrubber_metrics.dart';

/// Colours, shape and elevation used to draw a [RulerScrubber].
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
    this.shape = defaultShape,
    this.activeShadows = const [],
    this.activeNeedleShadows = const [],
  });

  /// A plainly rounded card with a hairline border, which is what the widget
  /// draws when it is given no shape of its own.
  static const defaultShape = RoundedRectangleBorder(
    side: BorderSide(width: kRulerCardBorderWidth),
    borderRadius: BorderRadius.all(Radius.circular(kRulerCardRadius)),
  );

  final Color backgroundColor;
  final Color borderColor;
  final Color activeBorderColor;
  final Color minorTickColor;
  final Color majorTickColor;
  final Color needleColor;

  /// The outline of the card the ruler runs inside.
  ///
  /// Any [OutlinedBorder] will do — a [StadiumBorder], a
  /// [ContinuousRectangleBorder], a squircle from a package, or one of your
  /// own — so the scrubber can be given the same corner as everything else on
  /// the screen without this package having an opinion about which it is.
  ///
  /// The border is drawn with the shape's own [OutlinedBorder.side], except
  /// for its colour: that comes from [borderColor] and [activeBorderColor], so
  /// it can light up while the ruler is being scrubbed. Give the shape a
  /// [BorderSide.none] to go without a border, and a wider side to get a
  /// heavier one.
  final OutlinedBorder shape;

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
