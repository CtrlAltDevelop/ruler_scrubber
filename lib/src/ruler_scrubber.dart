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
/// It is reachable without a finger too: give it focus and the arrow keys nudge
/// it, Page Up and Page Down move it in strides, Home and End run it to either
/// end of the range, and assistive technology sees a slider throughout.
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
    this.onChangeStart,
    this.onChangeEnd,
    this.formatValue,
    this.labelFormat,
    this.labelEvery = kRulerMajorTickEvery,
    this.style,
    this.enabled = true,
    this.enableFeedback = true,
    this.focusNode,
    this.autofocus = false,
    this.physics,
  }) : assert(min <= max, 'min must not be greater than max'),
       assert(tickStep > 0, 'tickStep must be positive'),
       assert(step == null || step > 0, 'step must be positive when given'),
       assert(labelEvery > 0, 'labelEvery must be positive');

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

  /// Reports the value the ruler was resting on when it started moving.
  final ValueChanged<double>? onChangeStart;

  /// Reports the value the ruler came to rest on. Use it for work too
  /// expensive to run on every frame of a scrub.
  final ValueChanged<double>? onChangeEnd;

  /// Granularity of the scrub. `null` scrubs continuously.
  final double? step;

  /// Spoken name of the control.
  final String semanticLabel;

  /// Spoken form of the value. Falls back to the plain number.
  final String Function(double value)? formatValue;

  /// Renders the number printed under a labelled tick. `null` — the default —
  /// draws a ruler of bare marks, and is the only setting that leaves the
  /// scrubber the height it has always been.
  ///
  /// Labels are laid out once per number per step of the end fade and then
  /// reused, so numbering a ruler does not put text layout on the path of a
  /// scrub. Keep the format cheap and stable all the same: one that returns
  /// something different for every tick has nothing to reuse.
  final String Function(double value)? labelFormat;

  /// How many ticks apart the labelled ones are. The default numbers every
  /// major tick; a multiple of [kRulerMajorTickEvery] keeps the numbers on the
  /// tall marks, and a larger one thins them out on a crowded ruler.
  final int labelEvery;

  /// Visual treatment for the scrubber. Falls back to the nearest
  /// [RulerScrubberTheme], and then to the surrounding Material theme.
  final RulerScrubberStyle? style;

  /// Whether the ruler can be scrubbed. A disabled scrubber still draws its
  /// value and still reads as a slider, dimmed and inert.
  final bool enabled;

  /// Whether crossing a tick under the finger clicks. Turn it off for a
  /// scrubber that is one of many on a screen, or in a form where the haptics
  /// would pile up.
  final bool enableFeedback;

  final FocusNode? focusNode;
  final bool autofocus;

  /// Scroll physics for the ruler. Defaults to [ClampingScrollPhysics] on
  /// every platform: a ruler that bounced off its ends would report values it
  /// does not have, and a range that has run out should feel like one.
  final ScrollPhysics? physics;

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

  FocusNode? _internalFocusNode;
  FocusNode get _focusNode =>
      widget.focusNode ?? (_internalFocusNode ??= FocusNode());

  /// True from the moment the ruler starts moving until it comes to rest,
  /// including the coast after a flick.
  bool _isScrubbing = false;

  /// True while the ruler is running to a value set somewhere else. What that
  /// run reports is the parent's own change coming back, so it is kept apart
  /// from a scrub.
  bool _isSettling = false;

  /// Which run the ruler is currently on.
  ///
  /// Interrupting an animation completes its future, so without this a second
  /// value arriving mid-run would let the first run's completion declare the
  /// second one over — and the rest of it would be echoed back at whoever set
  /// it.
  int _settleToken = 0;

  bool _isFocused = false;

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

    // A new scale or a new range is a new ruler, so the value is placed on it
    // rather than travelled to: the offset it sits at means something else
    // now, and animating between the two would sweep through values that were
    // never asked for.
    if (widget.tickStep != _tickStep ||
        widget.min != oldWidget.min ||
        widget.max != oldWidget.max) {
      if (widget.tickStep != _tickStep) {
        setState(() => _tickStep = widget.tickStep);
      }
      _jumpTo(_offsetOf(widget.value));
      return;
    }

    final target = _offsetOf(widget.value);
    // Half a pixel of ruler is below what the eye or the value can tell
    // apart, and chasing it would restart the animation on every rebuild.
    if ((target - _controller.offset).abs() < kRulerSettleTolerance) return;

    _settleTo(target);
  }

  @override
  void dispose() {
    _controller.removeListener(_onScroll);
    _controller.dispose();
    _internalFocusNode?.dispose();
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

  /// Puts the ruler at an offset without reporting the frames of the move: a
  /// jump is a re-placement, not a scrub.
  void _jumpTo(double offset) {
    _settleToken++;
    _isSettling = true;
    _controller.jumpTo(offset);
    _isSettling = false;
  }

  /// Runs the ruler to an offset it was sent to from somewhere other than the
  /// finger, keeping the run off [RulerScrubber.onChanged].
  void _settleTo(double offset) {
    final token = ++_settleToken;
    _isSettling = true;
    _controller
        .animateTo(
          offset,
          duration: kRulerSettleDuration,
          curve: Curves.easeOutCubic,
        )
        .whenComplete(() {
          // A run that was interrupted is not the run that is under way.
          if (_settleToken == token) _isSettling = false;
        });
  }

  // ── Scrubbing ──────────────────────────────────────────────────────────

  void _onScroll() {
    // Tracked even through a run the ruler was sent on, so the first tick of
    // the next scrub is measured from where the ruler actually is.
    final tick = (_controller.offset / kRulerTickSpacing).round();
    final crossed = tick != _lastTick;
    _lastTick = tick;

    // A ruler running to a value it was given has nothing to report: echoing
    // the frames of that run back would fight whatever set it.
    if (_isSettling) return;

    // Only under a finger: a ruler running to a value the stepper set should
    // not buzz its way there.
    if (crossed && _isScrubbing && widget.enableFeedback) {
      HapticFeedback.selectionClick();
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
      _settleToken++;
      _isSettling = false;
      if (widget.enabled) _focusNode.requestFocus();
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
    if (isScrubbing) widget.onChangeStart?.call(_valueOf(_controller.offset));
    setState(() => _isScrubbing = isScrubbing);
  }

  // ── Keyboard and semantics ─────────────────────────────────────────────

  String _spoken(double value) =>
      widget.formatValue?.call(value) ?? value.toStringAsFixed(2);

  /// One press of an arrow key, or of the accessibility increase/decrease
  /// action.
  double get _nudge => widget.step ?? (_span * kRulerKeyNudgeFraction);

  void _nudgeBy(double delta) => _moveTo(widget.value + delta);

  void _moveTo(double target) {
    final value = _snap(target).clamp(widget.min, widget.max);
    if (value == widget.value) return;

    widget.onChanged(value);
    widget.onChangeEnd?.call(value);
  }

  /// Puts a value the keyboard asked for onto the grid the scrub reports on,
  /// so a nudge cannot land somewhere a drag never could.
  double _snap(double value) {
    final step = widget.step;
    if (step == null || step <= 0) return value;
    return widget.min + ((value - widget.min) / step).round() * step;
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (!widget.enabled) return KeyEventResult.ignored;
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }

    final stride = _nudge * kRulerPageNudgeMultiple;
    switch (event.logicalKey) {
      case LogicalKeyboardKey.arrowLeft || LogicalKeyboardKey.arrowDown:
        _nudgeBy(-_nudge);
      case LogicalKeyboardKey.arrowRight || LogicalKeyboardKey.arrowUp:
        _nudgeBy(_nudge);
      case LogicalKeyboardKey.pageDown:
        _nudgeBy(-stride);
      case LogicalKeyboardKey.pageUp:
        _nudgeBy(stride);
      case LogicalKeyboardKey.home:
        _moveTo(widget.min);
      case LogicalKeyboardKey.end:
        _moveTo(widget.max);
      default:
        return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  // ── Build ──────────────────────────────────────────────────────────────

  /// How tall the ruler strip is. Numbering it hangs a row of labels below the
  /// ruler rather than moving the ruler up, so the needle stays where it was.
  double get _stripHeight => widget.labelFormat == null
      ? kRulerStripHeight
      : kRulerStripHeight + kRulerLabelGap + kRulerLabelHeight;

  @override
  Widget build(BuildContext context) {
    final style =
        widget.style ??
        RulerScrubberTheme.maybeOf(context) ??
        RulerScrubberStyle.fromTheme(Theme.of(context));

    final borderColor = switch ((_isScrubbing, _isFocused)) {
      (true, _) => style.activeBorderColor,
      (_, true) => style.focusedBorderColor ?? style.activeBorderColor,
      _ => style.borderColor,
    };

    Widget scrubber = _RulerCard(
      isActive: _isScrubbing,
      borderColor: borderColor,
      style: style,
      child: SizedBox(
        height: _stripHeight,
        child: LayoutBuilder(
          builder: (context, constraints) => Stack(
            // Top rather than centre: the labels grow the strip downwards, and
            // the needle should not drift down with them.
            alignment: .topCenter,
            children: [
              RulerTicks(
                scroll: _controller,
                travel: _travel,
                minorColor: style.minorTickColor,
                majorColor: style.majorTickColor,
                labelFormat: widget.labelFormat,
                labelEvery: widget.labelEvery,
                labelStyle: style.labelStyle,
                minValue: widget.min,
                tickStep: _tickStep,
                textDirection: Directionality.of(context),
              ),
              _Needle(
                color: _isScrubbing
                    ? style.activeBorderColor
                    : style.needleColor,
                isActive: _isScrubbing,
                activeShadows: style.activeNeedleShadows,
              ),
              // Last, so it takes the touches: the ruler is scrubbed by
              // dragging anywhere across the card.
              IgnorePointer(
                ignoring: !widget.enabled,
                child: _RulerGestureLayer(
                  controller: _controller,
                  travel: _travel,
                  height: _stripHeight,
                  viewportWidth: constraints.maxWidth,
                  physics: widget.enabled
                      ? widget.physics ?? const ClampingScrollPhysics()
                      : const NeverScrollableScrollPhysics(),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    // Only when it is off, so the ordinary case costs no saved layer.
    if (!widget.enabled) {
      scrubber = Opacity(opacity: kRulerDisabledOpacity, child: scrubber);
    }

    return Semantics(
      slider: true,
      enabled: widget.enabled,
      label: widget.semanticLabel,
      value: _spoken(widget.value),
      increasedValue: _spoken(math.min(widget.max, widget.value + _nudge)),
      decreasedValue: _spoken(math.max(widget.min, widget.value - _nudge)),
      onIncrease: widget.enabled ? () => _nudgeBy(_nudge) : null,
      onDecrease: widget.enabled ? () => _nudgeBy(-_nudge) : null,
      child: Focus(
        focusNode: _focusNode,
        autofocus: widget.autofocus,
        canRequestFocus: widget.enabled,
        onKeyEvent: _onKey,
        onFocusChange: (hasFocus) => setState(() => _isFocused = hasFocus),
        child: NotificationListener<ScrollNotification>(
          onNotification: (notification) {
            _onScrollNotification(notification);
            return false;
          },
          child: scrubber,
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
    required this.height,
    required this.viewportWidth,
    required this.physics,
  });

  final ScrollController controller;
  final double travel;
  final double height;
  final double viewportWidth;
  final ScrollPhysics physics;

  @override
  Widget build(BuildContext context) {
    // A number line runs from small to large left to right in every locale, so
    // the ruler is pinned to that direction rather than mirrored with the text
    // around it — which also keeps the offsets the painter reads meaning the
    // same thing as the offsets this produces.
    return Directionality(
      textDirection: TextDirection.ltr,
      child: SingleChildScrollView(
        controller: controller,
        scrollDirection: .horizontal,
        physics: physics,
        // Half a viewport of air at each end is what lets the first and last
        // values sit under the needle in the middle rather than at an edge.
        padding: .symmetric(horizontal: viewportWidth / 2),
        child: SizedBox(width: travel, height: height),
      ),
    );
  }
}

/// The bordered card the ruler runs inside, which takes the primary border
/// and lifts while it is being scrubbed.
class _RulerCard extends StatelessWidget {
  const _RulerCard({
    required this.isActive,
    required this.borderColor,
    required this.style,
    required this.child,
  });

  final bool isActive;
  final Color borderColor;
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
          side: style.borderless
              ? BorderSide.none
              : style.shape.side.copyWith(color: borderColor),
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
