import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import 'ruler_scrubber_metrics.dart';
import 'ruler_scrubber_style.dart';
import 'ruler_ticks.dart';

/// The control the calculator tools scrub their inputs with: a ruler that
/// travels under a needle standing still in the middle of the card.
///
/// Scrubbing a ruler rather than dragging a thumb is what makes a range this
/// wide usable — the value moves at [tickStep] a tick under the finger instead
/// of a whole range being squeezed into one screen width, and a flick carries
/// on scrolling, so reaching a distant value costs a gesture rather than a
/// pixel of travel. The exact number is typed into the stepper beside the
/// label; the ruler is how it is nudged and read.
///
/// The card lights up while it is being scrubbed — border and needle take the
/// primary colour — so the row being edited is obvious in a form of them.
///
/// Presentation only: it reports the value it was scrubbed to and draws the
/// value it is given, and holds no opinion about what that value means.
class RulerScrubber extends StatefulWidget {
  const RulerScrubber({
    super.key,
    required this.value,
    required this.min,
    required this.max,
    required this.tickStep,
    required this.onChanged,
    required this.semanticLabel,
    this.step,
    this.onChangeEnd,
    this.formatValue,
    this.style,
  });

  /// Where the ruler sits. Clamped into `[min, max]` before it is drawn, so an
  /// out-of-range value cannot scroll the ruler off its ends.
  final double value;

  final double min;
  final double max;

  /// How much the value changes over one tick of the ruler, and so how fast it
  /// moves under the finger. Read once while the ruler is still, so a scale
  /// that follows the value cannot change under a scrub in progress.
  final double tickStep;

  /// Reports every value the scrub passes through.
  final ValueChanged<double> onChanged;

  /// Reports the value the ruler came to rest on. Use it for work too
  /// expensive to run on every frame of a scrub.
  final ValueChanged<double>? onChangeEnd;

  /// Granularity of the scrub. `null` scrubs continuously.
  final double? step;

  /// Spoken name of the control.
  final String semanticLabel;

  /// Spoken form of the value. Falls back to the plain number.
  final String Function(double value)? formatValue;

  /// Visual treatment for the scrubber. Defaults to the surrounding Material
  /// theme when omitted.
  final RulerScrubberStyle? style;

  @override
  State<RulerScrubber> createState() => _RulerScrubberState();
}

class _RulerScrubberState extends State<RulerScrubber> {
  /// The scale the ruler is currently drawn at. Held rather than read from the
  /// widget, so a value that crosses into a coarser scale mid-scrub does not
  /// rescale the ruler under the finger.
  late double _tickStep = widget.tickStep;

  late final ScrollController _controller = ScrollController(
    initialScrollOffset: _offsetOf(widget.value),
  );

  /// True from the moment the ruler starts moving until it comes to rest,
  /// including the coast after a flick.
  bool _isScrubbing = false;

  /// True while the ruler is running to a value set somewhere else. What that
  /// run reports is the parent's own change coming back, so it is kept apart
  /// from a scrub.
  bool _isSettling = false;

  /// Tick the needle last crossed, so a scrub clicks once per tick rather than
  /// once per frame.
  int _lastTick = 0;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onScroll);
    _lastTick = (_controller.initialScrollOffset / kRulerTickSpacing).round();
  }

  @override
  void didUpdateWidget(RulerScrubber oldWidget) {
    super.didUpdateWidget(oldWidget);

    // A scrub owns the ruler until it stops: running towards the value the
    // parent echoes back would fight the finger.
    if (_isScrubbing || !_controller.hasClients) return;

    // A new scale is a new ruler, so the value is placed on it rather than
    // travelled to: the offset it sits at means something else now.
    if (widget.tickStep != _tickStep) {
      setState(() => _tickStep = widget.tickStep);
      _controller.jumpTo(_offsetOf(widget.value));
      return;
    }

    final target = _offsetOf(widget.value);
    // Half a pixel of ruler is below what the eye or the value can tell
    // apart, and chasing it would restart the animation on every rebuild.
    if ((target - _controller.offset).abs() < kRulerSettleTolerance) return;

    _isSettling = true;
    _controller
        .animateTo(
          target,
          duration: kRulerSettleDuration,
          curve: Curves.easeOutCubic,
        )
        .whenComplete(() => _isSettling = false);
  }

  @override
  void dispose() {
    _controller.removeListener(_onScroll);
    _controller.dispose();
    super.dispose();
  }

  // ── Value ↔ offset ─────────────────────────────────────────────────────

  double get _span => widget.max - widget.min;

  /// Distance between the ruler's two ends: one tick of spacing for every
  /// [_tickStep] the range covers.
  double get _travel =>
      _span <= 0 ? 0 : (_span / _tickStep) * kRulerTickSpacing;

  double _offsetOf(double value) {
    if (_travel <= 0) return 0;
    return ((value - widget.min) / _span).clamp(0.0, 1.0) * _travel;
  }

  /// The value an offset along the ruler stands for, snapped to [widget.step].
  double _valueOf(double offset) {
    if (_travel <= 0) return widget.min;

    final fraction = (offset / _travel).clamp(0.0, 1.0);
    final raw = widget.min + fraction * _span;
    final step = widget.step;
    if (step == null || step <= 0) return raw.clamp(widget.min, widget.max);

    final snapped = widget.min + ((raw - widget.min) / step).round() * step;
    return snapped.clamp(widget.min, widget.max);
  }

  // ── Scrubbing ──────────────────────────────────────────────────────────

  void _onScroll() {
    // A ruler running to a value it was given has nothing to report: echoing
    // the frames of that run back would fight whatever set it.
    if (_isSettling) return;

    final tick = (_controller.offset / kRulerTickSpacing).round();
    if (tick != _lastTick) {
      _lastTick = tick;
      // Only under a finger: a ruler running to a value the stepper set
      // should not buzz its way there.
      if (_isScrubbing) HapticFeedback.selectionClick();
    }

    final value = _valueOf(_controller.offset);
    if (value == widget.value) return;

    widget.onChanged(value);
  }

  /// Whether [notification] means the ruler has started or stopped moving. The
  /// coast after a flick still counts as scrubbing, so the card stays lit
  /// until the ruler is actually still.
  void _onScrollNotification(ScrollNotification notification) {
    // A finger landing on a ruler still running to a value takes it over.
    if (notification is ScrollStartNotification &&
        notification.dragDetails != null) {
      _isSettling = false;
    }
    if (_isSettling) return;

    final isScrubbing = switch (notification) {
      ScrollStartNotification() => true,
      ScrollEndNotification() => false,
      _ => _isScrubbing,
    };

    if (_isScrubbing && notification is ScrollEndNotification) {
      widget.onChangeEnd?.call(_valueOf(_controller.offset));
    }

    if (isScrubbing == _isScrubbing) return;
    setState(() => _isScrubbing = isScrubbing);
  }

  // ── Semantics ──────────────────────────────────────────────────────────

  String _spoken(double value) =>
      widget.formatValue?.call(value) ?? value.toStringAsFixed(2);

  /// One press of the accessibility increase/decrease action.
  double get _nudge => widget.step ?? (_span / 20);

  void _nudgeBy(double delta) {
    final value = (widget.value + delta).clamp(widget.min, widget.max);
    if (value == widget.value) return;

    widget.onChanged(value);
    widget.onChangeEnd?.call(value);
  }

  @override
  Widget build(BuildContext context) {
    final style =
        widget.style ?? RulerScrubberStyle.fromTheme(Theme.of(context));
    final accent = _isScrubbing ? style.activeBorderColor : style.needleColor;

    return Semantics(
      slider: true,
      label: widget.semanticLabel,
      value: _spoken(widget.value),
      increasedValue: _spoken(math.min(widget.max, widget.value + _nudge)),
      decreasedValue: _spoken(math.max(widget.min, widget.value - _nudge)),
      onIncrease: () => _nudgeBy(_nudge),
      onDecrease: () => _nudgeBy(-_nudge),
      child: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          _onScrollNotification(notification);
          return false;
        },
        child: _RulerCard(
          isActive: _isScrubbing,
          style: style,
          child: SizedBox(
            height: kRulerStripHeight,
            child: LayoutBuilder(
              builder: (context, constraints) => Stack(
                alignment: .center,
                children: [
                  RulerTicks(
                    scroll: _controller,
                    travel: _travel,
                    minorColor: style.minorTickColor,
                    majorColor: style.majorTickColor,
                  ),
                  _Needle(
                    color: accent,
                    isActive: _isScrubbing,
                    activeShadows: style.activeNeedleShadows,
                  ),
                  // Last, so it takes the touches: the ruler is scrubbed by
                  // dragging anywhere across the card.
                  _RulerGestureLayer(
                    controller: _controller,
                    travel: _travel,
                    viewportWidth: constraints.maxWidth,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The scrollable the ruler's position comes from.
///
/// It draws nothing — the ticks are painted behind it from its offset — and
/// exists only so the ruler inherits the platform's own scrolling: its
/// friction, its flick and its bounds.
class _RulerGestureLayer extends StatelessWidget {
  const _RulerGestureLayer({
    required this.controller,
    required this.travel,
    required this.viewportWidth,
  });

  final ScrollController controller;
  final double travel;
  final double viewportWidth;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      controller: controller,
      scrollDirection: .horizontal,
      physics: const ClampingScrollPhysics(),
      // Half a viewport of air at each end is what lets the first and last
      // values sit under the needle in the middle rather than at an edge.
      padding: .symmetric(horizontal: viewportWidth / 2),
      child: SizedBox(width: travel, height: kRulerStripHeight),
    );
  }
}

/// The bordered card the ruler runs inside, which takes the primary border
/// and lifts while it is being scrubbed.
class _RulerCard extends StatelessWidget {
  const _RulerCard({
    required this.isActive,
    required this.style,
    required this.child,
  });

  final bool isActive;
  final RulerScrubberStyle style;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: kRulerActiveDuration,
      curve: Curves.easeOut,
      padding: const .symmetric(
        horizontal: kRulerCardPaddingH,
        vertical: kRulerCardPaddingV,
      ),
      decoration: ShapeDecoration(
        color: style.backgroundColor,
        // The caller's shape, drawn in the scrubber's border colour: the
        // corner is theirs, whether it lights up is ours.
        shape: style.shape.copyWith(
          side: style.shape.side.copyWith(
            color: isActive ? style.activeBorderColor : style.borderColor,
          ),
        ),
        shadows: isActive ? style.activeShadows : const [],
      ),
      child: child,
    );
  }
}

/// The needle the ruler is read against: a capped bar standing in the middle
/// of the card.
class _Needle extends StatelessWidget {
  const _Needle({
    required this.color,
    required this.isActive,
    required this.activeShadows,
  });

  final Color color;
  final bool isActive;
  final List<BoxShadow> activeShadows;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Column(
        mainAxisSize: .min,
        spacing: kRulerCaretGap,
        children: [
          CustomPaint(
            size: const Size(kRulerCaretWidth, kRulerCaretHeight),
            painter: _CaretPainter(color: color),
          ),
          AnimatedContainer(
            duration: kRulerActiveDuration,
            curve: Curves.easeOut,
            width: kRulerNeedleWidth,
            height: kRulerNeedleHeight,
            decoration: ShapeDecoration(
              color: color,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.all(
                  Radius.circular(kRulerNeedleRadius),
                ),
              ),
              shadows: isActive ? activeShadows : const [],
            ),
          ),
        ],
      ),
    );
  }
}

/// The triangle that caps the needle, pointing at the value being read.
class _CaretPainter extends CustomPainter {
  const _CaretPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();

    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_CaretPainter oldDelegate) => oldDelegate.color != color;
}
