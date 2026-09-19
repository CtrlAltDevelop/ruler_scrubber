import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';

import 'ruler_scrubber_metrics.dart';

/// Colours, shape and elevation used to draw a [RulerScrubber].
///
/// Supply this when the scrubber needs to use an application's design-system
/// tokens. Omitting it falls back to the nearest [RulerScrubberTheme], and
/// then to accessible defaults derived from [ThemeData].
@immutable
class RulerScrubberStyle {
  /// Creates a style from explicit colours.
  ///
  /// [RulerScrubberStyle.fromTheme] fills them in from a [ThemeData] when
  /// there are no design-system tokens to hand.
  const RulerScrubberStyle({
    required this.backgroundColor,
    required this.borderColor,
    required this.activeBorderColor,
    required this.minorTickColor,
    required this.majorTickColor,
    required this.needleColor,
    this.focusedBorderColor,
    this.labelStyle,
    this.shape = defaultShape,
    this.borderless = false,
    this.activeShadows = const [],
    this.activeNeedleShadows = const [],
  });

  /// A plainly rounded card with a hairline border, which is what the widget
  /// draws when it is given no shape of its own.
  static const defaultShape = RoundedRectangleBorder(
    side: BorderSide(width: kRulerCardBorderWidth),
    borderRadius: BorderRadius.all(Radius.circular(kRulerCardRadius)),
  );

  /// Fill of the card the ruler runs inside.
  final Color backgroundColor;

  /// Border colour while the scrubber is idle.
  final Color borderColor;

  /// Border colour while the scrubber is being scrubbed, including the coast
  /// after a flick.
  final Color activeBorderColor;

  /// Colour of the short marks between the tall ones.
  final Color minorTickColor;

  /// Colour of the tall marks, and of the tick labels unless [labelStyle] says
  /// otherwise.
  final Color majorTickColor;

  /// Colour of the needle and its caret while the scrubber is idle. It takes
  /// [activeBorderColor] while scrubbing.
  final Color needleColor;

  /// Border colour while the scrubber holds keyboard focus but is not being
  /// scrubbed. Falls back to [activeBorderColor], so a style written before
  /// focus was drawn still shows it.
  final Color? focusedBorderColor;

  /// Type the tick labels are drawn in, when `RulerScrubber.labelFormat` asks
  /// for them. Falls back to a small label in [majorTickColor].
  ///
  /// Only the colour, size, weight, family and features are used: the labels
  /// are laid out in a strip [kRulerLabelHeight] tall whatever the line height
  /// of the style says, so a row of scrubbers cannot end up at different
  /// heights because one of them counts in a taller font.
  final TextStyle? labelStyle;

  /// The outline of the card the ruler runs inside.
  ///
  /// Any [OutlinedBorder] will do — a [StadiumBorder], a
  /// [ContinuousRectangleBorder], a squircle from a package, or one of your
  /// own — so the scrubber can be given the same corner as everything else on
  /// the screen without this package having an opinion about which it is.
  ///
  /// The border is drawn with the shape's own [OutlinedBorder.side], except
  /// for its colour: that comes from [borderColor], [focusedBorderColor] and
  /// [activeBorderColor], so it can light up while the ruler is focused or
  /// being scrubbed. Give the shape a [BorderSide.none] to go without a
  /// border, and a wider side to get a heavier one.
  final OutlinedBorder shape;

  /// Draws the card without a border, whatever [shape]'s own side says.
  ///
  /// The corner, background and padding are kept; only the outline goes, so
  /// the focus and scrub highlight that ride on the border colours are gone
  /// with it — [activeShadows] is what still marks an active scrubber.
  final bool borderless;

  /// Shadows lifting the card while it is being scrubbed.
  final List<BoxShadow> activeShadows;

  /// Shadows lifting the needle while it is being scrubbed.
  final List<BoxShadow> activeNeedleShadows;

  /// A style derived from [theme]'s colour scheme: what a scrubber draws when
  /// it is given no style and no [RulerScrubberTheme].
  static RulerScrubberStyle fromTheme(ThemeData theme) {
    final scheme = theme.colorScheme;
    return RulerScrubberStyle(
      backgroundColor: scheme.surface,
      borderColor: scheme.outlineVariant,
      activeBorderColor: scheme.primary,
      focusedBorderColor: scheme.primary,
      minorTickColor: scheme.outlineVariant,
      majorTickColor: scheme.onSurfaceVariant,
      needleColor: scheme.onSurfaceVariant,
      labelStyle: theme.textTheme.labelSmall?.copyWith(
        color: scheme.onSurfaceVariant,
      ),
      activeShadows: const [BoxShadow(blurRadius: 8, color: Color(0x1F000000))],
      activeNeedleShadows: const [
        BoxShadow(blurRadius: 4, color: Color(0x33000000)),
      ],
    );
  }

  /// A copy of this style with the given fields replaced.
  RulerScrubberStyle copyWith({
    Color? backgroundColor,
    Color? borderColor,
    Color? activeBorderColor,
    Color? focusedBorderColor,
    Color? minorTickColor,
    Color? majorTickColor,
    Color? needleColor,
    TextStyle? labelStyle,
    OutlinedBorder? shape,
    bool? borderless,
    List<BoxShadow>? activeShadows,
    List<BoxShadow>? activeNeedleShadows,
  }) {
    return RulerScrubberStyle(
      backgroundColor: backgroundColor ?? this.backgroundColor,
      borderColor: borderColor ?? this.borderColor,
      activeBorderColor: activeBorderColor ?? this.activeBorderColor,
      focusedBorderColor: focusedBorderColor ?? this.focusedBorderColor,
      minorTickColor: minorTickColor ?? this.minorTickColor,
      majorTickColor: majorTickColor ?? this.majorTickColor,
      needleColor: needleColor ?? this.needleColor,
      labelStyle: labelStyle ?? this.labelStyle,
      shape: shape ?? this.shape,
      borderless: borderless ?? this.borderless,
      activeShadows: activeShadows ?? this.activeShadows,
      activeNeedleShadows: activeNeedleShadows ?? this.activeNeedleShadows,
    );
  }

  /// Interpolates between two styles, for animating a scrubber between design
  /// states. Returns `null` only when both ends are `null`.
  static RulerScrubberStyle? lerp(
    RulerScrubberStyle? a,
    RulerScrubberStyle? b,
    double t,
  ) {
    if (identical(a, b)) return a;
    if (a == null) return b;
    if (b == null) return a;

    return RulerScrubberStyle(
      backgroundColor: Color.lerp(a.backgroundColor, b.backgroundColor, t)!,
      borderColor: Color.lerp(a.borderColor, b.borderColor, t)!,
      activeBorderColor: Color.lerp(
        a.activeBorderColor,
        b.activeBorderColor,
        t,
      )!,
      focusedBorderColor: Color.lerp(
        a.focusedBorderColor,
        b.focusedBorderColor,
        t,
      ),
      minorTickColor: Color.lerp(a.minorTickColor, b.minorTickColor, t)!,
      majorTickColor: Color.lerp(a.majorTickColor, b.majorTickColor, t)!,
      needleColor: Color.lerp(a.needleColor, b.needleColor, t)!,
      labelStyle: TextStyle.lerp(a.labelStyle, b.labelStyle, t),
      shape: OutlinedBorder.lerp(a.shape, b.shape, t) ?? b.shape,
      borderless: t < 0.5 ? a.borderless : b.borderless,
      activeShadows:
          BoxShadow.lerpList(a.activeShadows, b.activeShadows, t) ?? const [],
      activeNeedleShadows:
          BoxShadow.lerpList(a.activeNeedleShadows, b.activeNeedleShadows, t) ??
          const [],
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is RulerScrubberStyle &&
        other.backgroundColor == backgroundColor &&
        other.borderColor == borderColor &&
        other.activeBorderColor == activeBorderColor &&
        other.focusedBorderColor == focusedBorderColor &&
        other.minorTickColor == minorTickColor &&
        other.majorTickColor == majorTickColor &&
        other.needleColor == needleColor &&
        other.labelStyle == labelStyle &&
        other.shape == shape &&
        other.borderless == borderless &&
        listEquals(other.activeShadows, activeShadows) &&
        listEquals(other.activeNeedleShadows, activeNeedleShadows);
  }

  @override
  int get hashCode => Object.hash(
    backgroundColor,
    borderColor,
    activeBorderColor,
    focusedBorderColor,
    minorTickColor,
    majorTickColor,
    needleColor,
    labelStyle,
    shape,
    borderless,
    Object.hashAll(activeShadows),
    Object.hashAll(activeNeedleShadows),
  );
}

/// Supplies a [RulerScrubberStyle] to every [RulerScrubber] beneath it.
///
/// Wrap it once around an app — or around the one form that wants a different
/// treatment — instead of threading the same style through every call site. A
/// scrubber given a `style` of its own still wins.
class RulerScrubberTheme extends InheritedWidget {
  const RulerScrubberTheme({
    super.key,
    required this.style,
    required super.child,
  });

  final RulerScrubberStyle style;

  /// The style from the nearest enclosing [RulerScrubberTheme], or `null` when
  /// there is none, in which case the scrubber derives one from [ThemeData].
  static RulerScrubberStyle? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<RulerScrubberTheme>()?.style;

  @override
  bool updateShouldNotify(RulerScrubberTheme oldWidget) =>
      oldWidget.style != style;
}
