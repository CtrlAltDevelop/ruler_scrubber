// Renders the screenshots that README.md and pub.dev show, so the pictures of
// the widget are regenerated from the widget rather than recaptured by hand
// and left to go stale.
//
//     flutter test tool/screenshot_test.dart
//
// It is a test so that it can use the framework's own renderer: there is no
// device, no window and no app, just the widget painted into an image. One
// scrubber in each shot is held mid-drag, because the lit-up state is half of
// what the control looks like and a still of the idle one hides it.

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ruler_scrubber/ruler_scrubber.dart';

/// Where the images are written, relative to the package root.
const _outputDirectory = 'doc';

/// Rendered at 2x, which is what a reader on a retina display needs and what
/// pub.dev's carousel scales down from.
const _pixelRatio = 2.0;

/// Real text is the whole point of a screenshot, and the test environment
/// draws with a font whose every glyph is a box. These are the system faces
/// to try, best first; the shot is skipped rather than made unreadable if
/// none of them are there.
const _fontCandidates = <String, List<String>>{
  'SF Pro': ['/System/Library/Fonts/SFNS.ttf'],
  'Helvetica Neue': ['/System/Library/Fonts/HelveticaNeue.ttc'],
  'Arial': [
    '/System/Library/Fonts/Supplemental/Arial.ttf',
    '/System/Library/Fonts/Supplemental/Arial Bold.ttf',
  ],
};

void main() {
  late String fontFamily;

  setUpAll(() async {
    final family = await _loadFirstAvailableFont();
    if (family == null) {
      fail(
        'No system font found to render the screenshots with. Tried:\n'
        '${_fontCandidates.values.expand((p) => p).join('\n')}',
      );
    }
    fontFamily = family;
  });

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
}

/// Loads the first font in [_fontCandidates] that this machine actually has,
/// and returns the family it was registered under.
Future<String?> _loadFirstAvailableFont() async {
  for (final MapEntry(key: family, value: paths) in _fontCandidates.entries) {
    final files = paths.map(File.new).where((f) => f.existsSync()).toList();
    if (files.isEmpty) continue;

    final loader = FontLoader(family);
    for (final file in files) {
      final bytes = await file.readAsBytes();
      loader.addFont(Future.value(ByteData.sublistView(bytes)));
    }
    await loader.load();
    return family;
  }
  return null;
}

final _boundaryKey = GlobalKey();

/// Paints the sample at [brightness] and writes it to `doc/[fileName]`.
Future<void> _capture(
  WidgetTester tester, {
  required String fontFamily,
  required Brightness brightness,
  required String fileName,
}) async {
  // Large enough to lay the sample out without constraining it — the image is
  // cropped to the sample itself, not to this.
  tester.view.physicalSize = const Size(1600, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    _Sample(fontFamily: fontFamily, brightness: brightness),
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

  await _writeBoundary(tester, fileName);

  // Let the gesture go, so the widget is not disposed mid-drag.
  await gesture.up();
  await tester.pumpAndSettle();
}

/// Writes the keyed boundary's pixels out as a PNG.
Future<void> _writeBoundary(WidgetTester tester, String fileName) async {
  final boundary =
      _boundaryKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;

  late Uint8List png;
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: _pixelRatio);
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      png = data!.buffer.asUint8List();
    } finally {
      image.dispose();
    }
  });

  final file = File('$_outputDirectory/$fileName');
  file.parent.createSync(recursive: true);
  file.writeAsBytesSync(png);

  // ignore: avoid_print — this is a tool; the path is its output.
  print('Wrote ${file.path} (${(png.length / 1024).round()} KB)');
}

/// The scene the screenshots show: three scrubbers on a card, sized to their
/// content so the captured image needs no cropping.
class _Sample extends StatelessWidget {
  const _Sample({required this.fontFamily, required this.brightness});

  final String fontFamily;
  final Brightness brightness;

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
                  ),
                  _ScrubberSample(
                    key: _ScrubberSample.activeKey,
                    label: 'Deposit',
                    readout: '45%',
                    value: 45,
                    min: 0,
                    max: 100,
                    tickStep: 1,
                  ),
                  _ScrubberSample(
                    label: 'Temperature',
                    readout: '21.5°C',
                    value: 21.5,
                    min: -10,
                    max: 40,
                    tickStep: 0.1,
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
  });

  /// The row the screenshot holds a finger on.
  static final activeKey = GlobalKey();

  final String label;
  final String readout;
  final double value;
  final double min;
  final double max;
  final double tickStep;

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
          onChanged: (_) {},
        ),
      ],
    );
  }
}
