import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ruler_scrubber/ruler_scrubber.dart';

void main() {
  group('scrubbing', () {
    testWidgets('reports values scrubbed under the needle', (tester) async {
      final values = <double>[];

      await tester.pumpWidget(
        _harness(value: 0, tickStep: 0.01, step: 0.1, onChanged: values.add),
      );

      await tester.drag(find.byType(RulerScrubber), const Offset(-175, 0));
      await tester.pumpAndSettle();

      expect(values.last, closeTo(0.3, 0.02));
    });

    testWidgets('snaps reported values to step', (tester) async {
      final values = <double>[];

      await tester.pumpWidget(
        _harness(value: 0, tickStep: 0.01, step: 0.05, onChanged: values.add),
      );

      await _scrub(tester, const Offset(-200, 0));

      expect(values, isNotEmpty);
      for (final value in values) {
        expect(value * 20, closeTo((value * 20).roundToDouble(), 1e-9));
      }
    });

    testWidgets('reports continuously when step is null', (tester) async {
      final values = <double>[];

      await tester.pumpWidget(
        _harness(value: 0, tickStep: 0.01, onChanged: values.add),
      );

      await _scrub(tester, const Offset(-120, 0));

      // A continuous scrub lands somewhere no step would have allowed.
      expect(values.any((v) => (v * 1000) % 1 != 0), isTrue);
    });

    testWidgets('never reports outside the range', (tester) async {
      final values = <double>[];

      await tester.pumpWidget(
        _harness(value: 0.5, tickStep: 0.01, onChanged: values.add),
      );

      await _scrub(tester, const Offset(-4000, 0));
      await _scrub(tester, const Offset(4000, 0));

      expect(values, isNotEmpty);
      expect(values.every((v) => v >= 0 && v <= 1), isTrue);
    });

    testWidgets('onChangeEnd reports once, when the ruler stops', (
      tester,
    ) async {
      final changed = <double>[];
      final ended = <double>[];

      await tester.pumpWidget(
        _harness(
          value: 0,
          tickStep: 0.01,
          onChanged: changed.add,
          onChangeEnd: ended.add,
        ),
      );

      await _scrub(tester, const Offset(-120, 0));

      expect(changed.length, greaterThan(1));
      expect(ended, hasLength(1));
      expect(ended.single, closeTo(changed.last, 1e-9));
    });

    testWidgets('clicks once per tick rather than once per frame', (
      tester,
    ) async {
      var clicks = 0;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'HapticFeedback.vibrate') clicks++;
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
        _harness(value: 0, tickStep: 0.01, onChanged: (_) {}),
      );

      // Ten ticks of ruler, crossed a pixel at a time: a click per frame would
      // be seventy of them.
      await _scrub(tester, const Offset(-70, 0), steps: 70);

      expect(clicks, greaterThan(0));
      expect(clicks, lessThanOrEqualTo(12));
    });
  });

  group('externally set values', () {
    testWidgets('runs the ruler to a value it is given', (tester) async {
      final reported = <double>[];

      await tester.pumpWidget(
        _harness(value: 0.2, tickStep: 0.01, onChanged: reported.add),
      );
      await tester.pumpAndSettle();
      reported.clear();

      await tester.pumpWidget(
        _harness(value: 0.8, tickStep: 0.01, onChanged: reported.add),
      );
      await tester.pumpAndSettle();

      // The run is the parent's own change arriving back, so it is not echoed.
      expect(reported, isEmpty);

      // The ruler did move: scrubbing on from here starts near 0.8.
      final after = <double>[];
      await tester.pumpWidget(
        _harness(value: 0.8, tickStep: 0.01, onChanged: after.add),
      );
      await _scrub(tester, const Offset(-14, 0));
      expect(after.first, closeTo(0.8, 0.02));
    });

    testWidgets(
      'a new tickStep places the value rather than travelling to it',
      (tester) async {
        final reported = <double>[];

        await tester.pumpWidget(
          _harness(value: 0.5, tickStep: 0.01, onChanged: reported.add),
        );
        await tester.pumpAndSettle();
        reported.clear();

        // A coarser scale is a different ruler: the same value sits at a
        // different offset on it, so there is nothing to animate between.
        await tester.pumpWidget(
          _harness(value: 0.5, tickStep: 0.1, onChanged: reported.add),
        );
        await tester.pump();

        expect(reported, isEmpty);
        expect(tester.takeException(), isNull);
      },
    );
  });

  group('degenerate ranges', () {
    testWidgets('an empty range reports min and does not throw', (
      tester,
    ) async {
      final values = <double>[];

      await tester.pumpWidget(
        _harness(
          value: 5,
          min: 5,
          max: 5,
          tickStep: 0.01,
          onChanged: values.add,
        ),
      );
      await _scrub(tester, const Offset(-120, 0));

      expect(tester.takeException(), isNull);
      expect(values.every((v) => v == 5), isTrue);
    });
  });

  group('semantics', () {
    testWidgets('presents itself as a labelled slider', (tester) async {
      final handle = tester.ensureSemantics();

      await tester.pumpWidget(
        _harness(
          value: 0.5,
          tickStep: 0.01,
          step: 0.1,
          onChanged: (_) {},
          formatValue: (v) => '${(v * 100).round()} percent',
        ),
      );

      final node = tester.getSemantics(find.byType(RulerScrubber));

      expect(node.label, 'Price');
      expect(node.value, '50 percent');
      expect(node.increasedValue, '60 percent');
      expect(node.decreasedValue, '40 percent');
      final data = node.getSemanticsData();
      expect(data.flagsCollection.isSlider, isTrue);
      expect(data.hasAction(SemanticsAction.increase), isTrue);
      expect(data.hasAction(SemanticsAction.decrease), isTrue);

      handle.dispose();
    });

    testWidgets('increase and decrease nudge by step', (tester) async {
      final handle = tester.ensureSemantics();
      final changed = <double>[];
      final ended = <double>[];

      await tester.pumpWidget(
        _harness(
          value: 0.5,
          tickStep: 0.01,
          step: 0.1,
          onChanged: changed.add,
          onChangeEnd: ended.add,
        ),
      );

      tester.semantics.increase(find.semantics.byLabel('Price'));
      await tester.pumpAndSettle();
      expect(changed.single, closeTo(0.6, 1e-9));
      expect(ended.single, closeTo(0.6, 1e-9));

      changed.clear();
      ended.clear();
      tester.semantics.decrease(find.semantics.byLabel('Price'));
      await tester.pumpAndSettle();
      expect(changed.single, closeTo(0.4, 1e-9));

      handle.dispose();
    });

    testWidgets('a nudge at the end of the range reports nothing', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final changed = <double>[];

      await tester.pumpWidget(
        _harness(value: 1, tickStep: 0.01, step: 0.1, onChanged: changed.add),
      );

      tester.semantics.increase(find.semantics.byLabel('Price'));
      await tester.pumpAndSettle();

      expect(changed, isEmpty);
      handle.dispose();
    });
  });

  group('style', () {
    testWidgets('falls back to the ambient theme', (tester) async {
      await tester.pumpWidget(
        _harness(value: 0.5, tickStep: 0.01, onChanged: (_) {}),
      );

      expect(tester.takeException(), isNull);
      expect(find.byType(RulerTicks), findsOneWidget);
    });

    testWidgets('takes the colours it is given', (tester) async {
      const style = RulerScrubberStyle(
        backgroundColor: Color(0xFF101010),
        borderColor: Color(0xFF202020),
        activeBorderColor: Color(0xFF303030),
        minorTickColor: Color(0xFF404040),
        majorTickColor: Color(0xFF505050),
        needleColor: Color(0xFF606060),
      );

      await tester.pumpWidget(
        _harness(value: 0.5, tickStep: 0.01, style: style, onChanged: (_) {}),
      );

      final ticks = tester.widget<RulerTicks>(find.byType(RulerTicks));
      expect(ticks.minorColor, style.minorTickColor);
      expect(ticks.majorColor, style.majorTickColor);
    });

    testWidgets('RulerScrubberStyle.fromTheme uses the colour scheme', (
      tester,
    ) async {
      final theme = ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF3B5BFD)),
      );
      final style = RulerScrubberStyle.fromTheme(theme);

      expect(style.backgroundColor, theme.colorScheme.surface);
      expect(style.activeBorderColor, theme.colorScheme.primary);
      expect(style.needleColor, theme.colorScheme.onSurfaceVariant);
    });
  });
}

/// A scrubber of a fixed width, so a drag in pixels means the same thing in
/// every test.
Widget _harness({
  required double value,
  required double tickStep,
  required ValueChanged<double> onChanged,
  double min = 0,
  double max = 1,
  double? step,
  ValueChanged<double>? onChangeEnd,
  String Function(double)? formatValue,
  RulerScrubberStyle? style,
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
            semanticLabel: 'Price',
            formatValue: formatValue,
            style: style,
            onChanged: onChanged,
            onChangeEnd: onChangeEnd,
          ),
        ),
      ),
    ),
  );
}

/// Drags the ruler and lets it come to rest, without the fling a single-shot
/// [WidgetTester.drag] would throw in.
Future<void> _scrub(
  WidgetTester tester,
  Offset offset, {
  int steps = 12,
}) async {
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
