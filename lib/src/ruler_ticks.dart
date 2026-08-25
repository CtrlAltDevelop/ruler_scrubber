import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import 'ruler_scrubber_metrics.dart';

/// The ruler the needle is read against: evenly spaced ticks, every fifth one
/// taller, travelling under the needle as the value changes.
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
class RulerTicks extends StatelessWidget {
  const RulerTicks({
    super.key,
    required this.scroll,
    required this.travel,
    required this.minorColor,
    required this.majorColor,
  });

  /// Where the ruler currently sits. Doubles as the painter's repaint signal.
  final ScrollController scroll;

  /// Distance between the ruler's two ends. Nothing is drawn past either of
  /// them, so a range that has run out looks like one.
  final double travel;

  final Color minorColor;
  final Color majorColor;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        size: .infinite,
        painter: _RulerTicksPainter(
          scroll: scroll,
          travel: travel,
          minorColor: minorColor,
          majorColor: majorColor,
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
  }) : super(repaint: scroll);

  final ScrollController scroll;
  final double travel;
  final Color minorColor;
  final Color majorColor;

  /// Content offset under the needle. Before the ruler is attached that is the
  /// offset it was seeded with, so the very first frame already reads right.
  double get _offset =>
      scroll.hasClients ? scroll.offset : scroll.initialScrollOffset;

  /// A tick paint that is at full strength across the middle of [size] and
  /// fades to nothing at either end.
  Paint _fadedPaint(Color color, Size size) {
    // Half the strip at most, so a card too narrow to hold both fades ends up
    // with one continuous falloff rather than two that fight in the middle.
    final edge = math.min(kRulerFadeWidth / size.width, 0.5);

    return Paint()
      ..strokeWidth = kRulerTickWidth
      ..strokeCap = StrokeCap.round
      ..shader = LinearGradient(
        colors: [color.withAlpha(0), color, color, color.withAlpha(0)],
        stops: [0, edge, 1 - edge, 1],
      ).createShader(Offset.zero & size);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final minor = _fadedPaint(minorColor, size);
    final major = _fadedPaint(majorColor, size);

    // The needle stands in the middle of the strip, and the ticks are read
    // against it, so they are centred on it rather than on the strip.
    const center = kRulerCaretHeight + kRulerCaretGap + kRulerNeedleHeight / 2;
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
    }
  }

  @override
  bool shouldRepaint(_RulerTicksPainter oldDelegate) =>
      oldDelegate.scroll != scroll ||
      oldDelegate.travel != travel ||
      oldDelegate.minorColor != minorColor ||
      oldDelegate.majorColor != majorColor;
}
