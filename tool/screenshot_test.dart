// Renders the still screenshots that README.md and pub.dev show, so the
// pictures of the widget are regenerated from the widget rather than
// recaptured by hand and left to go stale.
//
//     flutter test tool/screenshot_test.dart
//
// It is a test so that it can use the framework's own renderer: there is no
// device, no window and no app, just the widget painted into an image. One
// scrubber in each shot is held mid-drag, because the lit-up state is half of
// what the control looks like and a still of the idle one hides it.
//
// See tool/animation_test.dart for the moving version.

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ruler_scrubber/ruler_scrubber.dart';

import 'rendering.dart';

/// Where the images are written, relative to the package root.
const _outputDirectory = 'doc';

/// Rendered at 2x, which is what a reader on a retina display needs and what
/// pub.dev's carousel scales down from.
const _pixelRatio = 2.0;

void main() {
  late String fontFamily;

  setUpAll(() async => fontFamily = await loadRenderFont());

  testWidgets('light', (tester) async {
    await _capture(
      tester,
      fontFamily: fontFamily,
      brightness: Brightness.light,
      fileName: 'screenshot.png',
    );
  });

  testWidgets('dark', (tester) async {
    await _capture(
      tester,
      fontFamily: fontFamily,
      brightness: Brightness.dark,
      fileName: 'screenshot_dark.png',
    );
  });

  testWidgets('borderless light', (tester) async {
    await _capture(
      tester,
      fontFamily: fontFamily,
      brightness: Brightness.light,
      borderless: true,
      fileName: 'screenshot_borderless.png',
    );
  });

  testWidgets('borderless dark', (tester) async {
    await _capture(
      tester,
      fontFamily: fontFamily,
      brightness: Brightness.dark,
      borderless: true,
      fileName: 'screenshot_borderless_dark.png',
    );
  });
}

final _boundaryKey = GlobalKey();

/// Paints the sample at [brightness] and writes it to `doc/[fileName]`.
Future<void> _capture(
  WidgetTester tester, {
  required String fontFamily,
  required Brightness brightness,
  required String fileName,
  bool borderless = false,
}) async {
  // Large enough to lay the sample out without constraining it — the image is
  // cropped to the sample itself, not to this.
  tester.view.physicalSize = const Size(1600, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    _Sample(
      fontFamily: fontFamily,
      brightness: brightness,
      borderless: borderless,
    ),
  );

  // Put a finger on the middle scrubber and hold it there, so the shot catches
  // the card and needle in their scrubbing colours.
  final gesture = await tester.startGesture(
    tester.getCenter(
      find.descendant(
        of: find.byKey(_ScrubberSample.activeKey),
        matching: find.byType(RulerScrubber),
      ),
    ),
  );
  await gesture.moveBy(const Offset(-26, 0));
  await tester.pump();
  // Long enough for the border and needle to finish taking the accent colour.
  await tester.pump(kRulerActiveDuration);

  final frame = await capture(tester, _boundaryKey, pixelRatio: _pixelRatio);
  writeOutput('$_outputDirectory/$fileName', frame.bytes);

  // Let the gesture go, so the widget is not disposed mid-drag.
  await gesture.up();
  await tester.pumpAndSettle();
}

/// The scene the screenshots show: three scrubbers on a card, sized to their
/// content so the captured image needs no cropping.
class _Sample extends StatelessWidget {
  const _Sample({
    required this.fontFamily,
    required this.brightness,
    this.borderless = false,
  });

  final String fontFamily;
  final Brightness brightness;
  final bool borderless;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeData(
      fontFamily: fontFamily,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF3B5BFD),
        brightness: brightness,
      ),
    );
    final isDark = brightness == Brightness.dark;
    final baseStyle = borderless
        ? RulerScrubberStyle.fromTheme(theme).copyWith(borderless: true)
        : null;

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: theme,
      home: Align(
        alignment: Alignment.topLeft,
        child: RepaintBoundary(
          key: _boundaryKey,
          child: Container(
            width: 640,
            padding: const EdgeInsets.all(40),
            color: isDark ? const Color(0xFF07080B) : const Color(0xFFF1F2F6),
            child: Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    blurRadius: 28,
                    offset: const Offset(0, 8),
                    color: Color(isDark ? 0x38000000 : 0x14000000),
                  ),
                ],
              ),
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 30),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 28,
                children: [
                  _ScrubberSample(
                    label: 'Price',
                    readout: '£24.50',
                    value: 24.50,
                    min: 0,
                    max: 100,
                    tickStep: 0.02,
                    style: baseStyle,
                  ),
                  _ScrubberSample(
                    key: _ScrubberSample.activeKey,
                    label: 'Deposit',
                    readout: '45%',
                    value: 45,
                    min: 0,
                    max: 100,
                    tickStep: 1,
                    style: baseStyle,
                  ),
                  // A shape of its own, since the card's corner is the
                  // caller's to choose.
                  _ScrubberSample(
                    label: 'Temperature',
                    readout: '21.5°C',
                    value: 21.5,
                    min: -10,
                    max: 40,
                    tickStep: 0.1,
                    style: RulerScrubberStyle(
                      shape: const StadiumBorder(side: BorderSide(width: 1.5)),
                      backgroundColor: theme.colorScheme.surface,
                      borderColor: theme.colorScheme.outlineVariant,
                      activeBorderColor: theme.colorScheme.primary,
                      minorTickColor: theme.colorScheme.outlineVariant,
                      majorTickColor: theme.colorScheme.onSurfaceVariant,
                      needleColor: theme.colorScheme.onSurfaceVariant,
                      borderless: borderless,
                    ),
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

/// One labelled row of the sample.
class _ScrubberSample extends StatelessWidget {
  const _ScrubberSample({
    super.key,
    required this.label,
    required this.readout,
    required this.value,
    required this.min,
    required this.max,
    required this.tickStep,
    this.style,
  });

  /// The row the screenshot holds a finger on.
  static final activeKey = GlobalKey();

  final String label;
  final String readout;
  final double value;
  final double min;
  final double max;
  final double tickStep;
  final RulerScrubberStyle? style;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 10,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              label,
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            Text(readout, style: theme.textTheme.headlineSmall),
          ],
        ),
        RulerScrubber(
          value: value,
          min: min,
          max: max,
          tickStep: tickStep,
          semanticLabel: label,
          style: style,
          onChanged: (_) {},
        ),
      ],
    );
  }
}
