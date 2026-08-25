// Renders the animated demo README.md and pub.dev show.
//
//     flutter test tool/animation_test.dart
//
// A still cannot show what the widget is for. The point of a ruler is that the
// value moves under the finger at a rate you set, that a flick carries on
// scrolling, and that the card lights up for as long as either is happening —
// none of which a photograph of it holds.
//
// So the scrub is driven a frame at a time and each frame is captured: press,
// drag, release, and then let the flick coast to a stop on the platform's own
// physics. The value is held in state and echoed in the readout, so the digits
// count along with the ruler exactly as they would in an app.

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:ruler_scrubber/ruler_scrubber.dart';

import 'rendering.dart';

const _output = 'doc/scrubbing.gif';

/// 2x, matching the stills. A GIF pays for every pixel of every frame twice
/// over — once in the palette pass and once in the file — but the type is what
/// suffers first at 1x, and this is a picture of a control with numbers on it.
const _pixelRatio = 2.0;

/// One frame every 40ms — 25fps, which is smooth enough for a scroll and
/// leaves the file a size a README can carry.
const _frameDuration = Duration(milliseconds: 40);

/// Frames of the ruler sitting still, so the loop does not read as starting
/// mid-gesture.
const _idleFrames = 3;

/// Frames the finger is down for, and how far it travels in each. Two ticks a
/// frame is brisk enough to look like scrubbing rather than nudging.
const _dragFrames = 18;
const _dragPerFrame = Offset(-14, 0);

/// Frames captured after the finger lifts, for the flick to coast and the card
/// to give up its accent colour.
const _coastFrames = 14;

final _boundaryKey = GlobalKey();

void main() {
  // Loaded here rather than in the test body: reading the file is real I/O,
  // and awaiting real I/O inside testWidgets deadlocks against the fake clock
  // the test drives frames with. setUpAll runs outside it.
  late String fontFamily;
  setUpAll(() async => fontFamily = await loadRenderFont());

  testWidgets('scrubbing', timeout: const Timeout(Duration(minutes: 10)), (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_Demo(fontFamily: fontFamily));
    // Before capturing anything: a MaterialApp's text theme only gets its
    // geometry — the sizes and letter spacing — once localization has
    // resolved, and a theme captured before that renders its text at the
    // wrong size entirely.
    await tester.pumpAndSettle();

    final clock = Stopwatch()..start();

    // Grabbed synchronously and read out afterwards: see tool/rendering.dart
    // for why the pixels cannot be awaited a frame at a time.
    final shots = <ui.Image>[];
    void shoot() => shots.add(grab(_boundaryKey, pixelRatio: _pixelRatio));

    for (var i = 0; i < _idleFrames; i++) {
      await tester.pump(_frameDuration);
      shoot();
    }

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(RulerScrubber)),
    );
    for (var i = 0; i < _dragFrames; i++) {
      await gesture.moveBy(_dragPerFrame);
      await tester.pump(_frameDuration);
      shoot();
    }

    // Let go with the drag's own velocity, so what follows is the platform's
    // fling rather than anything this tool made up.
    await gesture.up();
    for (var i = 0; i < _coastFrames; i++) {
      await tester.pump(_frameDuration);
      shoot();
    }

    final frames = await drain(
      tester,
      shots,
      format: ui.ImageByteFormat.rawRgba,
    );
    // ignore: avoid_print
    print(
      '  captured ${frames.length} frames of '
      '${frames.first.width}x${frames.first.height} in ${clock.elapsed}',
    );
    writeOutput(_output, _encodeGif(frames));
    // ignore: avoid_print
    print('  total ${clock.elapsed}');

    // The loop is only worth having if it is one. Something has to have moved,
    // and the flick has to have finished moving by the last frame — a GIF that
    // cuts off mid-coast jumps when it repeats.
    expect(frames.first.bytes, isNot(equals(frames.last.bytes)));
    expect(frames.last.bytes, equals(frames[frames.length - 2].bytes));
    await tester.pumpAndSettle();
  });
}

/// Packs the captured frames into an animated GIF.
///
/// The encoder builds a palette and dithers once per frame, so which quantizer
/// it uses decides whether this takes seconds or gives up: the default neural
/// one costs minutes a frame at this size and buys nothing, because the scene
/// is a dozen flat colours rather than a photograph.
Uint8List _encodeGif(List<Frame> frames) {
  final encoder = img.GifEncoder(
    quantizerType: img.QuantizerType.octree,
    // Dithering flat fills is noise, and noise is the one thing GIF cannot
    // compress: it costs quality and file size at once.
    dither: img.DitherKernel.none,
    numColors: 256,
    repeat: 0,
  );

  final stopwatch = Stopwatch()..start();
  for (var i = 0; i < frames.length; i++) {
    final frame = frames[i];
    encoder.addFrame(
      img.Image.fromBytes(
        width: frame.width,
        height: frame.height,
        bytes: frame.bytes.buffer,
        numChannels: 4,
      ),
      duration: _frameDuration.inMilliseconds ~/ 10,
    );
    if (i % 10 == 9) {
      // ignore: avoid_print — a slow encode should say so rather than hang.
      print('  encoded ${i + 1}/${frames.length} (${stopwatch.elapsed})');
    }
  }

  return encoder.finish()!;
}

/// One scrubber, holding its own value so the readout counts along with the
/// ruler — which is the thing a still cannot show.
class _Demo extends StatefulWidget {
  const _Demo({required this.fontFamily});

  final String fontFamily;

  @override
  State<_Demo> createState() => _DemoState();
}

class _DemoState extends State<_Demo> {
  double _price = 24.50;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: widget.fontFamily,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF3B5BFD)),
      ),
      // The theme has to be read back out of the context rather than used as
      // it was written: a ThemeData only gets the sizes and letter spacing of
      // its text theme when Theme localizes it, so the copy handed to
      // MaterialApp has a text theme with no font sizes in it at all. Using
      // that copy directly renders every label at whatever size it inherits.
      home: Builder(
        builder: (context) {
          final theme = Theme.of(context);
          return Align(
            alignment: Alignment.topLeft,
            child: RepaintBoundary(
              key: _boundaryKey,
              child: Container(
                width: 640,
                padding: const EdgeInsets.all(40),
                color: const Color(0xFFF1F2F6),
                child: Container(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 22,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    spacing: 12,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            'Price',
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          Text(
                            '£${_price.toStringAsFixed(2)}',
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                        ],
                      ),
                      RulerScrubber(
                        value: _price,
                        min: 0,
                        max: 100,
                        step: 0.01,
                        tickStep: 0.02,
                        semanticLabel: 'Price',
                        onChanged: (value) => setState(() => _price = value),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
