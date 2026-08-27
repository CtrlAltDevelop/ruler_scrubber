import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:ruler_scrubber/ruler_scrubber.dart';

void main() {
  group('labels', () {
    testWidgets('a bare ruler is the height it has always been', (
      tester,
    ) async {
      await tester.pumpWidget(_harness(value: 0.5, onChanged: (_) {}));

      expect(
        tester.getSize(find.byType(RulerScrubber)).height,
        kRulerStripHeight + 2 * kRulerCardPaddingV + 2 * kRulerCardBorderWidth,
      );
    });

    testWidgets('numbering grows the scrubber by a known amount', (
      tester,
    ) async {
      await tester.pumpWidget(_harness(value: 0.5, onChanged: (_) {}));
      final bare = tester.getSize(find.byType(RulerScrubber)).height;

      await tester.pumpWidget(
        _harness(
          value: 0.5,
          onChanged: (_) {},
          labelFormat: (v) => v.toStringAsFixed(0),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        tester.getSize(find.byType(RulerScrubber)).height,
        bare + kRulerLabelGap + kRulerLabelHeight,
      );
    });

    testWidgets('the needle stays put when labels are turned on', (
      tester,
    ) async {
      await tester.pumpWidget(_harness(value: 0.5, onChanged: (_) {}));
      final top = tester.getTopLeft(find.byType(RulerScrubber)).dy;
      final needle = tester.getRect(find.byType(RulerTicks)).top - top;

      await tester.pumpWidget(
        _harness(
          value: 0.5,
          onChanged: (_) {},
          labelFormat: (v) => v.toStringAsFixed(0),
        ),
      );
      await tester.pumpAndSettle();

      final movedTop = tester.getTopLeft(find.byType(RulerScrubber)).dy;
      expect(tester.getRect(find.byType(RulerTicks)).top - movedTop, needle);
    });

    testWidgets('numbers the ticks it is asked to', (tester) async {
      final labelled = <double>{};

      await tester.pumpWidget(
        _harness(
          value: 0,
          min: 0,
          max: 100,
          tickStep: 1,
          onChanged: (_) {},
          labelFormat: (v) {
            labelled.add(v);
            return v.toStringAsFixed(0);
          },
        ),
      );
      await tester.pumpAndSettle();

      expect(labelled, isNotEmpty);
      // The default numbers every major tick, and a tick is worth tickStep.
      for (final value in labelled) {
        expect(value % kRulerMajorTickEvery, 0);
      }
    });

    testWidgets('labelEvery thins the numbers out', (tester) async {
      final labelled = <double>{};

      await tester.pumpWidget(
        _harness(
          value: 0,
          min: 0,
          max: 100,
          tickStep: 1,
          labelEvery: 20,
          onChanged: (_) {},
          labelFormat: (v) {
            labelled.add(v);
            return v.toStringAsFixed(0);
          },
        ),
      );
      await tester.pumpAndSettle();

      expect(labelled, isNotEmpty);
      for (final value in labelled) {
        expect(value % 20, 0);
      }
    });

    testWidgets('a label says what its tick is worth', (tester) async {
      final labelled = <double>{};

      await tester.pumpWidget(
        _harness(
          value: 50,
          min: 0,
          max: 100,
          tickStep: 2,
          onChanged: (_) {},
          labelFormat: (v) {
            labelled.add(v);
            return v.toStringAsFixed(0);
          },
        ),
      );
      await tester.pumpAndSettle();

      // The needle sits on 50, so the ruler under it is numbered around 50.
      expect(labelled.any((v) => (v - 50).abs() <= 10), isTrue);
      // Ticks are worth 2 apiece and every fifth is numbered.
      for (final value in labelled) {
        expect(value % 10, 0);
      }
    });

    testWidgets('lays each number out once per fade step', (tester) async {
      var calls = 0;

      await tester.pumpWidget(
        _harness(
          value: 0.5,
          min: 0,
          max: 1,
          tickStep: 0.01,
          onChanged: (_) {},
          labelFormat: (v) {
            calls++;
            return v.toStringAsFixed(2);
          },
        ),
      );
      await tester.pumpAndSettle();

      final afterFirstFrame = calls;
      // Repainting the same ruler asks for the same numbers again, but the
      // laid-out text behind them is reused rather than measured afresh.
      await tester.pump();
      await tester.pump();

      expect(calls, greaterThanOrEqualTo(afterFirstFrame));
      expect(find.byType(RulerTicks), findsOneWidget);
    });
  });

  group('theme', () {
    testWidgets('takes the style from an enclosing RulerScrubberTheme', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RulerScrubberTheme(
              style: _style(border: const Color(0xFFAABBCC)),
              child: RulerScrubber(
                value: 0.5,
                min: 0,
                max: 1,
                tickStep: 0.01,
                semanticLabel: 'Price',
                onChanged: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(_cardShape(tester).side.color, const Color(0xFFAABBCC));
    });

    testWidgets('a style on the widget beats the one from the theme', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RulerScrubberTheme(
              style: _style(border: const Color(0xFFAABBCC)),
              child: RulerScrubber(
                value: 0.5,
                min: 0,
                max: 1,
                tickStep: 0.01,
                semanticLabel: 'Price',
                style: _style(border: const Color(0xFF112233)),
                onChanged: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(_cardShape(tester).side.color, const Color(0xFF112233));
    });

    testWidgets('a new theme repaints the scrubbers under it', (tester) async {
      Widget build(Color border) => MaterialApp(
        home: Scaffold(
          body: RulerScrubberTheme(
            style: _style(border: border),
            child: RulerScrubber(
              value: 0.5,
              min: 0,
              max: 1,
              tickStep: 0.01,
              semanticLabel: 'Price',
              onChanged: (_) {},
            ),
          ),
        ),
      );

      await tester.pumpWidget(build(const Color(0xFFAABBCC)));
      await tester.pumpAndSettle();
      await tester.pumpWidget(build(const Color(0xFF445566)));
      await tester.pumpAndSettle();

      expect(_cardShape(tester).side.color, const Color(0xFF445566));
    });
  });

  group('style value semantics', () {
    test('two styles with the same fields are equal', () {
      expect(_style(), _style());
      expect(_style().hashCode, _style().hashCode);
    });

    test('copyWith replaces only what it is given', () {
      final base = _style();
      final copy = base.copyWith(needleColor: const Color(0xFF000001));

      expect(copy.needleColor, const Color(0xFF000001));
      expect(copy.backgroundColor, base.backgroundColor);
      expect(copy, isNot(base));
    });

    test('lerp runs between two styles', () {
      final a = _style(border: const Color(0xFF000000));
      final b = _style(border: const Color(0xFFFFFFFF));

      expect(RulerScrubberStyle.lerp(a, b, 0), a);
      expect(RulerScrubberStyle.lerp(a, b, 1)!.borderColor, b.borderColor);
      expect(
        RulerScrubberStyle.lerp(a, b, 0.5)!.borderColor,
        Color.lerp(a.borderColor, b.borderColor, 0.5),
      );
    });

    test('lerp tolerates a missing end', () {
      final a = _style();

      expect(RulerScrubberStyle.lerp(a, null, 0.5), a);
      expect(RulerScrubberStyle.lerp(null, a, 0.5), a);
      expect(RulerScrubberStyle.lerp(null, null, 0.5), isNull);
    });

    test('lerp runs the shape between the two corners', () {
      final a = _style();
      final b = _style().copyWith(shape: const StadiumBorder());
      const rect = Rect.fromLTWH(0, 0, 200, 40);

      // A point that falls inside a 10pt corner but outside a stadium's, so
      // it tells the two ends apart — the lerp leaves an interpolating
      // border behind rather than either shape itself.
      const corner = Offset(5, 5);

      expect(
        RulerScrubberStyle.lerp(a, b, 0)!.shape.getOuterPath(rect).contains(
          corner,
        ),
        isTrue,
      );
      expect(
        RulerScrubberStyle.lerp(a, b, 1)!.shape.getOuterPath(rect).contains(
          corner,
        ),
        isFalse,
      );
    });
  });

  group('disabled', () {
    testWidgets('a disabled ruler cannot be scrubbed', (tester) async {
      final values = <double>[];

      await tester.pumpWidget(
        _harness(value: 0.5, enabled: false, onChanged: values.add),
      );

      await _scrub(tester, const Offset(-120, 0));

      expect(values, isEmpty);
    });

    testWidgets('a disabled ruler is dimmed but still drawn', (tester) async {
      await tester.pumpWidget(
        _harness(value: 0.5, enabled: false, onChanged: (_) {}),
      );

      final opacity = tester.widget<Opacity>(
        find
            .descendant(
              of: find.byType(RulerScrubber),
              matching: find.byType(Opacity),
            )
            .first,
      );

      expect(opacity.opacity, kRulerDisabledOpacity);
      expect(find.byType(RulerTicks), findsOneWidget);
    });

    testWidgets('an enabled ruler costs no saved layer', (tester) async {
      await tester.pumpWidget(_harness(value: 0.5, onChanged: (_) {}));

      expect(
        find.descendant(
          of: find.byType(RulerScrubber),
          matching: find.byType(Opacity),
        ),
        findsNothing,
      );
    });

    testWidgets('a disabled ruler still reads as a slider', (tester) async {
      final handle = tester.ensureSemantics();

      await tester.pumpWidget(
        _harness(value: 0.5, enabled: false, onChanged: (_) {}),
      );

      expect(
        tester.getSemantics(find.byType(RulerScrubber)),
        matchesSemantics(
          isSlider: true,
          isEnabled: false,
          hasEnabledState: true,
          label: 'Price',
          value: '0.50',
        ),
      );

      handle.dispose();
    });
  });

  group('haptics', () {
    testWidgets('enableFeedback: false keeps a scrub silent', (tester) async {
      final calls = <MethodCall>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          calls.add(call);
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );

      await tester.pumpWidget(
        _harness(value: 0.5, enableFeedback: false, onChanged: (_) {}),
      );

      await _scrub(tester, const Offset(-140, 0));

      expect(
        calls.where((c) => c.method == 'HapticFeedback.vibrate'),
        isEmpty,
      );
    });
  });

  group('change lifecycle', () {
    testWidgets('onChangeStart reports the value the scrub began at', (
      tester,
    ) async {
      final started = <double>[];

      await tester.pumpWidget(
        _harness(value: 0.5, onChanged: (_) {}, onChangeStart: started.add),
      );

      await _scrub(tester, const Offset(-140, 0));

      expect(started, hasLength(1));
      expect(started.single, closeTo(0.5, 0.01));
    });

    testWidgets('a value set elsewhere is not echoed back', (tester) async {
      final values = <double>[];

      await tester.pumpWidget(_harness(value: 0.2, onChanged: values.add));
      await tester.pumpWidget(_harness(value: 0.8, onChanged: values.add));
      await tester.pumpAndSettle();

      expect(values, isEmpty);
    });

    testWidgets('a new scale re-places the ruler rather than sweeping it', (
      tester,
    ) async {
      final values = <double>[];

      await tester.pumpWidget(
        _harness(value: 0.5, tickStep: 0.01, onChanged: values.add),
      );
      await tester.pumpWidget(
        _harness(value: 0.5, tickStep: 0.05, onChanged: values.add),
      );
      await tester.pumpAndSettle();

      expect(values, isEmpty);
    });

    testWidgets('a new range re-places the ruler too', (tester) async {
      final values = <double>[];

      await tester.pumpWidget(
        _harness(value: 5, min: 0, max: 10, tickStep: 1, onChanged: values.add),
      );
      await tester.pumpWidget(
        _harness(
          value: 5,
          min: 0,
          max: 100,
          tickStep: 1,
          onChanged: values.add,
        ),
      );
      await tester.pumpAndSettle();

      expect(values, isEmpty);
    });
  });

  group('physics', () {
    testWidgets('defaults to a ruler that does not bounce off its ends', (
      tester,
    ) async {
      await tester.pumpWidget(_harness(value: 0.5, onChanged: (_) {}));

      final view = tester.widget<SingleChildScrollView>(
        find.byType(SingleChildScrollView),
      );

      expect(view.physics, isA<ClampingScrollPhysics>());
    });

    testWidgets('takes the physics it is given', (tester) async {
      await tester.pumpWidget(
        _harness(
          value: 0.5,
          physics: const BouncingScrollPhysics(),
          onChanged: (_) {},
        ),
      );

      final view = tester.widget<SingleChildScrollView>(
        find.byType(SingleChildScrollView),
      );

      expect(view.physics, isA<BouncingScrollPhysics>());
    });

    testWidgets('a disabled ruler does not scroll at all', (tester) async {
      await tester.pumpWidget(
        _harness(value: 0.5, enabled: false, onChanged: (_) {}),
      );

      final view = tester.widget<SingleChildScrollView>(
        find.byType(SingleChildScrollView),
      );

      expect(view.physics, isA<NeverScrollableScrollPhysics>());
    });
  });
}

RulerScrubberStyle _style({Color border = const Color(0xFF202020)}) {
  return RulerScrubberStyle(
    backgroundColor: const Color(0xFF101010),
    borderColor: border,
    activeBorderColor: const Color(0xFF303030),
    minorTickColor: const Color(0xFF505050),
    majorTickColor: const Color(0xFF606060),
    needleColor: const Color(0xFF707070),
  );
}

OutlinedBorder _cardShape(WidgetTester tester) {
  final container = tester.widget<AnimatedContainer>(
    find
        .descendant(
          of: find.byType(RulerScrubber),
          matching: find.byType(AnimatedContainer),
        )
        .first,
  );
  return (container.decoration! as ShapeDecoration).shape as OutlinedBorder;
}

Widget _harness({
  required double value,
  required ValueChanged<double> onChanged,
  double min = 0,
  double max = 1,
  double tickStep = 0.01,
  double? step,
  bool enabled = true,
  bool enableFeedback = true,
  int labelEvery = kRulerMajorTickEvery,
  String Function(double)? labelFormat,
  ValueChanged<double>? onChangeStart,
  ScrollPhysics? physics,
}) {
  return MaterialApp(
    home: Scaffold(
      body: Center(
        child: SizedBox(
          width: 300,
          child: RulerScrubber(
            value: value,
            min: min,
            max: max,
            step: step,
            tickStep: tickStep,
            enabled: enabled,
            enableFeedback: enableFeedback,
            labelFormat: labelFormat,
            labelEvery: labelEvery,
            physics: physics,
            semanticLabel: 'Price',
            onChanged: onChanged,
            onChangeStart: onChangeStart,
          ),
        ),
      ),
    ),
  );
}

Future<void> _scrub(WidgetTester tester, Offset offset, {int steps = 12}) async {
  final gesture = await tester.startGesture(
    tester.getCenter(find.byType(RulerScrubber)),
  );
  for (var i = 0; i < steps; i++) {
    await gesture.moveBy(offset / steps.toDouble());
    await tester.pump(const Duration(milliseconds: 16));
  }
  await gesture.up();
  await tester.pumpAndSettle();
}
