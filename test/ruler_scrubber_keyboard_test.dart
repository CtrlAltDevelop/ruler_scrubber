import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:ruler_scrubber/ruler_scrubber.dart';

void main() {
  group('keyboard', () {
    testWidgets('arrow keys nudge by step', (tester) async {
      final values = <double>[];

      await tester.pumpWidget(
        _harness(value: 0.5, tickStep: 0.01, step: 0.05, onChanged: values.add),
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      expect(values.last, closeTo(0.55, 1e-9));

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      expect(values.last, closeTo(0.45, 1e-9));
    });

    testWidgets('up and down nudge the same way as right and left', (
      tester,
    ) async {
      final values = <double>[];

      await tester.pumpWidget(
        _harness(value: 0.5, tickStep: 0.01, step: 0.05, onChanged: values.add),
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      expect(values.last, closeTo(0.55, 1e-9));

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      expect(values.last, closeTo(0.45, 1e-9));
    });

    testWidgets('without a step, a nudge moves a fraction of the range', (
      tester,
    ) async {
      final values = <double>[];

      await tester.pumpWidget(
        _harness(value: 0.5, tickStep: 0.01, onChanged: values.add),
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);

      expect(values.last, closeTo(0.5 + kRulerKeyNudgeFraction, 1e-9));
    });

    testWidgets('page keys move in strides', (tester) async {
      final values = <double>[];

      await tester.pumpWidget(
        _harness(value: 0.5, tickStep: 0.01, step: 0.01, onChanged: values.add),
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.pageUp);
      expect(values.last, closeTo(0.5 + 0.01 * kRulerPageNudgeMultiple, 1e-9));

      await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);
      expect(values.last, closeTo(0.5 - 0.01 * kRulerPageNudgeMultiple, 1e-9));
    });

    testWidgets('home and end run to either end of the range', (tester) async {
      final values = <double>[];

      await tester.pumpWidget(
        _harness(
          value: 0.5,
          tickStep: 0.01,
          min: 2,
          max: 8,
          onChanged: (v) {
            values.add(v);
          },
        ),
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.home);
      expect(values.last, 2);

      await tester.sendKeyEvent(LogicalKeyboardKey.end);
      expect(values.last, 8);
    });

    testWidgets('a nudge is clamped to the range', (tester) async {
      final values = <double>[];

      await tester.pumpWidget(
        _harness(value: 1, tickStep: 0.01, step: 0.05, onChanged: values.add),
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);

      expect(values, isEmpty, reason: 'already at max');
    });

    testWidgets('a nudge lands on the same grid a scrub reports on', (
      tester,
    ) async {
      final values = <double>[];

      // A value off the step grid is snapped onto it rather than moved by a
      // step and left off it.
      await tester.pumpWidget(
        _harness(
          value: 0.51,
          tickStep: 0.01,
          step: 0.05,
          onChanged: values.add,
        ),
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);

      expect(
        values.last * 20,
        closeTo((values.last * 20).roundToDouble(), 1e-9),
      );
    });

    testWidgets('a key reports the end of the change as well', (tester) async {
      final ended = <double>[];

      await tester.pumpWidget(
        _harness(
          value: 0.5,
          tickStep: 0.01,
          step: 0.05,
          onChanged: (_) {},
          onChangeEnd: ended.add,
        ),
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);

      expect(ended, [closeTo(0.55, 1e-9)]);
    });

    testWidgets('an unhandled key is left for the rest of the app', (
      tester,
    ) async {
      final values = <double>[];

      await tester.pumpWidget(
        _harness(value: 0.5, tickStep: 0.01, step: 0.05, onChanged: values.add),
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.keyA);

      expect(values, isEmpty);
    });

    testWidgets('a disabled scrubber ignores the keyboard', (tester) async {
      final values = <double>[];

      await tester.pumpWidget(
        _harness(
          value: 0.5,
          tickStep: 0.01,
          step: 0.05,
          enabled: false,
          onChanged: values.add,
        ),
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);

      expect(values, isEmpty);
    });
  });

  group('focus', () {
    testWidgets('takes the focused border colour while focused', (
      tester,
    ) async {
      const style = RulerScrubberStyle(
        backgroundColor: Color(0xFF101010),
        borderColor: Color(0xFF202020),
        activeBorderColor: Color(0xFF303030),
        focusedBorderColor: Color(0xFF404040),
        minorTickColor: Color(0xFF505050),
        majorTickColor: Color(0xFF606060),
        needleColor: Color(0xFF707070),
      );

      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);

      await tester.pumpWidget(
        _harness(
          value: 0.5,
          tickStep: 0.01,
          style: style,
          focusNode: focusNode,
          autofocus: false,
          onChanged: (_) {},
        ),
      );

      expect(_cardShape(tester).side.color, const Color(0xFF202020));

      focusNode.requestFocus();
      await tester.pumpAndSettle();

      expect(_cardShape(tester).side.color, const Color(0xFF404040));
    });

    testWidgets('falls back to the active colour when none is given', (
      tester,
    ) async {
      const style = RulerScrubberStyle(
        backgroundColor: Color(0xFF101010),
        borderColor: Color(0xFF202020),
        activeBorderColor: Color(0xFF303030),
        minorTickColor: Color(0xFF505050),
        majorTickColor: Color(0xFF606060),
        needleColor: Color(0xFF707070),
      );

      await tester.pumpWidget(
        _harness(value: 0.5, tickStep: 0.01, style: style, onChanged: (_) {}),
      );
      await tester.pumpAndSettle();

      expect(_cardShape(tester).side.color, const Color(0xFF303030));
    });

    testWidgets('a disabled scrubber cannot take focus', (tester) async {
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);

      await tester.pumpWidget(
        _harness(
          value: 0.5,
          tickStep: 0.01,
          enabled: false,
          focusNode: focusNode,
          autofocus: false,
          onChanged: (_) {},
        ),
      );

      focusNode.requestFocus();
      await tester.pumpAndSettle();

      expect(focusNode.hasFocus, isFalse);
    });

    testWidgets('a scrub takes focus', (tester) async {
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);

      await tester.pumpWidget(
        _harness(
          value: 0.5,
          tickStep: 0.01,
          focusNode: focusNode,
          autofocus: false,
          onChanged: (_) {},
        ),
      );

      await _scrub(tester, const Offset(-60, 0));

      expect(focusNode.hasFocus, isTrue);
    });

    testWidgets('an external focus node outlives the scrubber', (tester) async {
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);

      await tester.pumpWidget(
        _harness(
          value: 0.5,
          tickStep: 0.01,
          focusNode: focusNode,
          autofocus: false,
          onChanged: (_) {},
        ),
      );
      await tester.pumpWidget(const SizedBox());

      // Disposing a node the scrubber does not own would throw here.
      expect(focusNode.hasFocus, isFalse);
    });
  });
}

/// The outline the card is actually painted with.
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
  required double tickStep,
  required ValueChanged<double> onChanged,
  double min = 0,
  double max = 1,
  double? step,
  bool enabled = true,
  bool autofocus = true,
  FocusNode? focusNode,
  ValueChanged<double>? onChangeEnd,
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
            enabled: enabled,
            autofocus: autofocus,
            focusNode: focusNode,
            semanticLabel: 'Price',
            style: style,
            onChanged: onChanged,
            onChangeEnd: onChangeEnd,
          ),
        ),
      ),
    ),
  );
}

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
