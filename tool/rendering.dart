// Shared plumbing for the tools that render the package's pictures: getting a
// real font into the test environment, and getting pixels back out of it.
//
// Both live here rather than in one of the tools because the still shots and
// the animation need exactly the same two things, and a font list that drifts
// between them would make the pictures disagree.

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Real text is the whole point of a screenshot, and the test environment
/// draws with a font whose every glyph is a box. These are the system faces
/// to try, best first.
const fontCandidates = <String, List<String>>{
  'SF Pro': ['/System/Library/Fonts/SFNS.ttf'],
  'Helvetica Neue': ['/System/Library/Fonts/HelveticaNeue.ttc'],
  'Arial': [
    '/System/Library/Fonts/Supplemental/Arial.ttf',
    '/System/Library/Fonts/Supplemental/Arial Bold.ttf',
  ],
};

/// Loads the first font in [fontCandidates] that this machine actually has and
/// returns the family it was registered under, or fails the test if there is
/// none — a picture of boxes is worse than no picture.
Future<String> loadRenderFont() async {
  for (final MapEntry(key: family, value: paths) in fontCandidates.entries) {
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

  fail(
    'No system font found to render with. Tried:\n'
    '${fontCandidates.values.expand((p) => p).join('\n')}',
  );
}

/// The pixels of one captured frame, and how wide and tall they are — a raw
/// buffer says neither on its own.
typedef Frame = ({Uint8List bytes, int width, int height});

/// Grabs the boundary [key] is on, without waiting for anything.
///
/// [RenderRepaintBoundary.toImage] is asynchronous, and awaiting it once per
/// frame means entering [WidgetTester.runAsync] once per frame — which
/// deadlocks a test that is also driving a gesture and pumping frames, because
/// the two run on different clocks. Grabbing synchronously keeps the whole
/// capture loop on the test's own clock; the pixels are read out afterwards,
/// in one go, by [drain].
ui.Image grab(GlobalKey key, {required double pixelRatio}) {
  final boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  return boundary.toImageSync(pixelRatio: pixelRatio);
}

/// Reads the pixels out of images collected by [grab], and disposes them.
///
/// One [WidgetTester.runAsync] for the lot, after the gesture is over and
/// there is nothing left to deadlock against.
Future<List<Frame>> drain(
  WidgetTester tester,
  List<ui.Image> images, {
  ui.ImageByteFormat format = ui.ImageByteFormat.png,
}) async {
  final frames = <Frame>[];
  await tester.runAsync(() async {
    for (final image in images) {
      try {
        final data = await image.toByteData(format: format);
        frames.add((
          bytes: data!.buffer.asUint8List(),
          width: image.width,
          height: image.height,
        ));
      } finally {
        image.dispose();
      }
    }
  });
  return frames;
}

/// Grabs one frame and reads it straight back — the still-screenshot case,
/// where there is only ever one and nothing is being driven around it.
Future<Frame> capture(
  WidgetTester tester,
  GlobalKey key, {
  required double pixelRatio,
  ui.ImageByteFormat format = ui.ImageByteFormat.png,
}) async {
  final frames = await drain(tester, [
    grab(key, pixelRatio: pixelRatio),
  ], format: format);
  return frames.single;
}

/// Writes [bytes] to `path`, creating the directory if it is not there, and
/// says so — these are tools, and the path is their output.
void writeOutput(String path, Uint8List bytes) {
  final file = File(path);
  file.parent.createSync(recursive: true);
  file.writeAsBytesSync(bytes);
  // ignore: avoid_print
  print('Wrote $path (${(bytes.length / 1024).round()} KB)');
}
