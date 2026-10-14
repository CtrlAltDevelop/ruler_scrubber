import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:ruler_scrubber/ruler_scrubber.dart';

void main() {
  group('coming to rest', () {
    testWidgets('settles the needle onto the value it reported', (
      tester,
    ) async {
      var value = 0.0;

      await tester.pumpWidget(
        _app(
          (setState) => RulerScrubber(
            value: value,
            min: 0,
            max: 1,
            step: 0.1,
            tickStep: 0.01,
            semanticLabel: 'Price',
            onChanged: (v) => setState(() => value = v),
          ),
        ),
      );

      // 50px at 7px a tick lands the needle at 0.07, between 0.0 and 0.1.
      await _scrub(tester, const Offset(-50, 0));

      expect(value, closeTo(0.1, 1e-9));
      expect(_position(tester).pixels, closeTo(0.1 * 100 * 7, 0.5));
    });

    testWidgets('adopts a scale the parent moved to mid-scrub', (tester) async {
      var value = 0.4;

      await tester.pumpWidget(
        _app(
          (setState) => RulerScrubber(
            value: value,
            min: 0,
            max: 1,
            tickStep: value < 0.5 ? 0.01 : 0.05,
            semanticLabel: 'Price',
            onChanged: (v) => setState(() => value = v),
          ),
        ),
      );
      expect(_position(tester).maxScrollExtent, closeTo(700, 0.5));

      await _scrub(tester, const Offset(-160, 0));

      expect(value, greaterThan(0.5));
      // The coarser scale has 20 ticks to the range, not 100.
      expect(_position(tester).maxScrollExtent, closeTo(140, 0.5));
      expect(_position(tester).pixels, closeTo(value * 20 * 7, 0.5));
    });
  });

  group('majorTickEvery', () {
    testWidgets('must be positive', (tester) async {
      expect(
        () => RulerScrubber(
          value: 0,
          min: 0,
          max: 1,
          tickStep: 0.1,
          majorTickEvery: 0,
          semanticLabel: 'Price',
          onChanged: (_) {},
        ),
        throwsAssertionError,
      );
    });

    testWidgets('moves the tall marks', (tester) async {
      Future<RenderObject> ruler(int every) async {
        await tester.pumpWidget(
          _app(
            (_) => RulerScrubber(
              value: 0,
              min: 0,
              max: 1,
              tickStep: 0.01,
              majorTickEvery: every,
              semanticLabel: 'Price',
              onChanged: (_) {},
            ),
          ),
        );
        return tester.renderObject(
          find
              .descendant(
                of: find.byType(RulerScrubber),
                matching: find.byType(CustomPaint),
              )
              .first,
        );
      }

      // The fifth tick stands 35px right of the needle, which is 133px in; a
      // tall mark runs from y 9 to 23, a short one from 12 to 20.
      PaintPattern fifthTick(double top) => paints
        ..line()
        ..line()
        ..line()
        ..line()
        ..line()
        ..line(p1: Offset(168, top));

      expect(await ruler(5), fifthTick(9));
      expect(await ruler(10), fifthTick(12));
    });
  });

  group('semantics', () {
    testWidgets('speaks a value outside the range as the end it is drawn at', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();

      await tester.pumpWidget(
        _app(
          (_) => RulerScrubber(
            value: 7,
            min: 0,
            max: 1,
            tickStep: 0.01,
            step: 0.1,
            formatValue: (v) => v.toStringAsFixed(1),
            semanticLabel: 'Price',
            onChanged: (_) {},
          ),
        ),
      );

      expect(
        tester.getSemantics(find.byType(RulerScrubber)),
        matchesSemantics(
          isSlider: true,
          hasEnabledState: true,
          isEnabled: true,
          isFocusable: true,
          hasFocusAction: true,
          label: 'Price',
          value: '1.0',
          increasedValue: '1.0',
          decreasedValue: '0.9',
          hasIncreaseAction: true,
          hasDecreaseAction: true,
        ),
      );
      handle.dispose();
    });
  });
}

ScrollPosition _position(WidgetTester tester) =>
    tester.state<ScrollableState>(find.byType(Scrollable)).position;

/// Hosts [build] in a parent that can rebuild, so a scrub is echoed back the
/// way a real owner would.
Widget _app(Widget Function(StateSetter setState) build) {
  return MaterialApp(
    home: Scaffold(
      body: Center(
        child: SizedBox(
          width: 300,
          child: StatefulBuilder(
            builder: (context, setState) => build(setState),
          ),
        ),
      ),
    ),
  );
}

Future<void> _scrub(WidgetTester tester, Offset offset) async {
  final gesture = await tester.startGesture(
    tester.getCenter(find.byType(RulerScrubber)),
  );
  for (var i = 0; i < 12; i++) {
    await gesture.moveBy(offset / 12);
    await tester.pump(const Duration(milliseconds: 16));
  }
  await gesture.up();
  await tester.pumpAndSettle();
}
