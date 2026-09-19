import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import 'ruler_scrubber_metrics.dart';

/// How many steps of opacity a label may be laid out at as it crosses the
/// fade. Coarse on purpose: the eye cannot tell two neighbouring steps apart,
/// and every step is one more entry to lay out and hold.
const int _kLabelFadeSteps = 8;

/// How many laid-out labels are kept before the cache starts over.
const int _kLabelCacheLimit = 256;

/// The ruler the needle is read against: evenly spaced ticks, every fifth one
/// taller, travelling under the needle as the value changes, and optionally
/// numbered.
///
/// The ticks are painted where they fall rather than laid out inside the
/// scrollable, so a range worth thousands of them costs the same as one worth
/// a dozen — only the handful under the viewport is ever drawn. Repaints come
/// from the scroll position alone, which is why nothing above it rebuilds
/// while a finger is on the ruler.
///
/// They fade out towards both ends, which is what makes the ruler read as a
/// strip passing through the card rather than as a row of marks that stops at
/// its edges. The fade is a gradient on the tick paint itself rather than a
/// mask over the whole strip — a mask would cost a compositing layer on every
/// frame of a scrub, and would take the needle down with it.
class RulerTicks extends StatefulWidget {
  /// Creates the strip of ticks for a ruler running [travel] pixels.
  const RulerTicks({
    super.key,
    required this.scroll,
    required this.travel,
    required this.minorColor,
    required this.majorColor,
    this.labelFormat,
    this.labelEvery = kRulerMajorTickEvery,
    this.labelStyle,
    this.minValue = 0,
    this.tickStep = 1,
    this.textDirection = TextDirection.ltr,
  });

  /// Where the ruler currently sits. Doubles as the painter's repaint signal.
  final ScrollController scroll;

  /// Distance between the ruler's two ends. Nothing is drawn past either of
  /// them, so a range that has run out looks like one.
  final double travel;

  /// Colour of the short marks.
  final Color minorColor;

  /// Colour of the tall marks.
  final Color majorColor;

  /// Renders the number under a labelled tick. `null` draws no labels, and is
  /// what keeps the ruler the height it was before labels existed.
  final String Function(double value)? labelFormat;

  /// How many ticks apart the labelled ones are.
  final int labelEvery;

  /// Type the labels are drawn in. Falls back to a small label in
  /// [majorColor].
  final TextStyle? labelStyle;

  /// The value the ruler's first tick stands for, and how much each tick after
  /// it adds — between them, what a label says.
  final double minValue;

  /// How much each tick adds to the value. See [minValue].
  final double tickStep;

  /// Direction the labels' own text runs in. The ruler itself always runs left
  /// to right, the way a number line does in any locale.
  final TextDirection textDirection;

  @override
  State<RulerTicks> createState() => _RulerTicksState();
}

class _RulerTicksState extends State<RulerTicks> {
  /// Laid-out labels, keyed by what they say and how faded they are.
  ///
  /// Laying text out is the expensive half of drawing it, and a scrub redraws
  /// the same handful of numbers at the same handful of opacities frame after
  /// frame — so each one is laid out once and then only painted.
  final Map<String, TextPainter> _labels = {};

  @override
  void didUpdateWidget(RulerTicks oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Anything that changes what a label says, or how it looks, makes the ones
    // already laid out worthless.
    if (oldWidget.labelFormat != widget.labelFormat ||
        oldWidget.labelStyle != widget.labelStyle ||
        oldWidget.majorColor != widget.majorColor ||
        oldWidget.textDirection != widget.textDirection ||
        oldWidget.minValue != widget.minValue ||
        oldWidget.tickStep != widget.tickStep) {
      _clearLabels();
    }
  }

  @override
  void dispose() {
    _clearLabels();
    super.dispose();
  }

  void _clearLabels() {
    for (final painter in _labels.values) {
      painter.dispose();
    }
    _labels.clear();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        size: .infinite,
        painter: _RulerTicksPainter(
          scroll: widget.scroll,
          travel: widget.travel,
          minorColor: widget.minorColor,
          majorColor: widget.majorColor,
          labelFormat: widget.labelFormat,
          labelEvery: widget.labelEvery,
          labelStyle: widget.labelStyle,
          minValue: widget.minValue,
          tickStep: widget.tickStep,
          textDirection: widget.textDirection,
          labels: _labels,
        ),
      ),
    );
  }
}

class _RulerTicksPainter extends CustomPainter {
  _RulerTicksPainter({
    required this.scroll,
    required this.travel,
    required this.minorColor,
    required this.majorColor,
    required this.labelFormat,
    required this.labelEvery,
    required this.labelStyle,
    required this.minValue,
    required this.tickStep,
    required this.textDirection,
    required this.labels,
  }) : super(repaint: scroll);

  final ScrollController scroll;
  final double travel;
  final Color minorColor;
  final Color majorColor;
  final String Function(double value)? labelFormat;
  final int labelEvery;
  final TextStyle? labelStyle;
  final double minValue;
  final double tickStep;
  final TextDirection textDirection;
  final Map<String, TextPainter> labels;

  /// Content offset under the needle. Before the ruler is attached that is the
  /// offset it was seeded with, so the very first frame already reads right.
  double get _offset =>
      scroll.hasClients ? scroll.offset : scroll.initialScrollOffset;

  /// How far in from either end of a strip [width] wide the fade reaches.
  ///
  /// Half the strip at most, so a card too narrow to hold both fades ends up
  /// with one continuous falloff rather than two that fight in the middle.
  double _edgeFraction(double width) =>
      width <= 0 ? 0 : math.min(kRulerFadeWidth / width, 0.5);

  /// A tick paint that is at full strength across the middle of [size] and
  /// fades to nothing at either end.
  Paint _fadedPaint(Color color, Size size) {
    final edge = _edgeFraction(size.width);

    return Paint()
      ..strokeWidth = kRulerTickWidth
      ..strokeCap = StrokeCap.round
      ..shader = LinearGradient(
        colors: [color.withAlpha(0), color, color, color.withAlpha(0)],
        stops: [0, edge, 1 - edge, 1],
      ).createShader(Offset.zero & size);
  }

  /// The falloff the tick gradient applies, sampled at one point — so a label
  /// fades exactly as the tick it hangs under does.
  double _fadeAt(double x, double width) {
    final edge = _edgeFraction(width);
    if (edge <= 0) return 1;

    final fraction = x / width;
    if (fraction <= 0 || fraction >= 1) return 0;
    if (fraction < edge) return fraction / edge;
    if (fraction > 1 - edge) return (1 - fraction) / edge;
    return 1;
  }

  /// A label laid out at one of [_kLabelFadeSteps] opacities, reused across
  /// frames whenever the same number comes round at the same fade.
  TextPainter _label(String text, int fadeStep) {
    final key = '$fadeStep $text';
    final cached = labels[key];
    if (cached != null) return cached;

    final base =
        labelStyle ??
        const TextStyle(
          fontSize: kRulerLabelFontSize,
          fontWeight: FontWeight.w500,
        );
    final color = base.color ?? majorColor;

    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: base.copyWith(
          color: color.withValues(alpha: color.a * fadeStep / _kLabelFadeSteps),
        ),
      ),
      textDirection: textDirection,
      maxLines: 1,
    )..layout();

    // A ruler shows a handful of numbers at a handful of opacities, so this
    // stays small — but a format that returns something new for every tick
    // would grow it without bound, and a cache that occasionally starts over
    // costs less than one that never stops.
    if (labels.length >= _kLabelCacheLimit) {
      for (final stale in labels.values) {
        stale.dispose();
      }
      labels.clear();
    }

    return labels[key] = painter;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final minor = _fadedPaint(minorColor, size);
    final major = _fadedPaint(majorColor, size);
    final format = labelFormat;

    // The needle stands in the middle of the ruler strip, and the ticks are
    // read against it, so they are centred on it rather than on the canvas.
    // The labels hang below the whole of that strip, which is why asking for
    // them grows the scrubber downwards instead of shifting the ruler.
    const center = kRulerCaretHeight + kRulerCaretGap + kRulerNeedleHeight / 2;
    const labelTop = kRulerStripHeight + kRulerLabelGap;
    final half = size.width / 2;

    // Content x of a tick is its index times the spacing, and content x sits
    // at the needle when it equals the offset — so the tick lands half a
    // viewport further along than the distance between the two.
    final first = math.max(0, ((_offset - half) / kRulerTickSpacing).ceil());
    final last = math.min(
      (travel / kRulerTickSpacing).floor(),
      ((_offset + half) / kRulerTickSpacing).floor(),
    );

    for (var i = first; i <= last; i++) {
      final x = half - _offset + i * kRulerTickSpacing;
      final isMajor = i % kRulerMajorTickEvery == 0;
      final height = isMajor ? kRulerMajorTickHeight : kRulerMinorTickHeight;

      canvas.drawLine(
        Offset(x, center - height / 2),
        Offset(x, center + height / 2),
        isMajor ? major : minor,
      );

      if (format == null || labelEvery <= 0 || i % labelEvery != 0) continue;

      final fadeStep = (_fadeAt(x, size.width) * _kLabelFadeSteps).round();
      if (fadeStep <= 0) continue;

      final label = _label(format(minValue + i * tickStep), fadeStep);
      label.paint(
        canvas,
        Offset(
          x - label.width / 2,
          labelTop + (kRulerLabelHeight - label.height) / 2,
        ),
      );
    }
  }

  @override
  bool shouldRepaint(_RulerTicksPainter oldDelegate) =>
      oldDelegate.scroll != scroll ||
      oldDelegate.travel != travel ||
      oldDelegate.minorColor != minorColor ||
      oldDelegate.majorColor != majorColor ||
      oldDelegate.labelFormat != labelFormat ||
      oldDelegate.labelEvery != labelEvery ||
      oldDelegate.labelStyle != labelStyle ||
      oldDelegate.minValue != minValue ||
      oldDelegate.tickStep != tickStep ||
      oldDelegate.textDirection != textDirection;
}
