# Changelog

## 1.2.0

- `RulerScrubberStyle.borderless` draws the card without its border, keeping
  the corner, background and padding.
- Dartdoc on the remaining undocumented public members.
- The borderless screenshots are listed on pub.dev.
- CI moved to the shared reusable workflow in CtrlAltDevelop/ci-workflows:
  formatting, `analyze --fatal-infos`, the tests, the example, a changelog
  entry per version, and a pana score with no points lost — the same gate
  across every package here.
- Dependency bounds are explicit ranges rather than carets — a floor that
  resolves on the supported SDK, the next major as the ceiling — so a consumer
  already on an older version in the same major is not forced to move.
- The README carries the pub, pub points, CI and licence badges the other
  packages here carry.

## 1.1.0

Everything here is additive: a 1.0.0 scrubber compiles and behaves as it did.

### Keyboard and focus

- The scrubber is now reachable without a finger. Give it focus and the arrow
  keys nudge it by `step` (or a twentieth of the range when there is no step),
  Page Up and Page Down move it in strides of ten of those, and Home and End
  run it to either end of the range.
- `focusNode` and `autofocus` let the scrubber take part in an existing focus
  traversal, and a scrub takes focus so the keyboard picks up where the finger
  left off.
- `RulerScrubberStyle.focusedBorderColor` lights the card while it holds focus
  but is not being scrubbed. It falls back to `activeBorderColor`, so a style
  written against 1.0.0 shows focus without being changed.

### Numbered rulers

- `labelFormat` prints a number under labelled ticks; `labelEvery` sets how far
  apart they are. Labels are laid out once per number per step of the end fade
  and then reused, so numbering a ruler keeps text layout off the path of a
  scrub.
- Labels hang below the ruler rather than moving it, so the needle stays where
  it was and turning them on grows the scrubber by a known amount.
- `RulerScrubberStyle.labelStyle` sets the type. Only colour, size, weight,
  family and features are used — the strip is a fixed height, so a row of
  scrubbers cannot end up at different heights because one counts in a taller
  font.

### More control over the scrub

- `onChangeStart` reports the value a scrub began at, alongside the existing
  `onChangeEnd`.
- `enabled` draws the scrubber dimmed and inert, still readable and still a
  slider to assistive technology.
- `enableFeedback` turns off the per-tick haptics for a screen that has several
  scrubbers on it.
- `physics` overrides the scroll physics. The default is unchanged and still
  `ClampingScrollPhysics`: a ruler that bounced off its ends would report
  values it does not have.

### Wider SDK support

- The floor drops to Dart 3.12 and Flutter 3.44, matching what `material_ui`
  itself requires rather than sitting above it.

### Theming

- `RulerScrubberTheme` supplies a style to every scrubber beneath it, so an app
  sets its treatment once instead of threading it through every call site. A
  scrubber given a `style` of its own still wins.
- `RulerScrubberStyle.lerp` interpolates between two styles, for animating a
  scrubber between design states.

## 1.0.0

Initial release.

- `RulerScrubber`: a ruler-style numeric input that scrolls under a stationary
  needle, with platform scroll physics, flick-to-coast and per-tick haptics.
- `RulerScrubberStyle`: design-system colours, card shape and shadows, derived
  from the ambient `ThemeData` when omitted. `shape` takes any
  `OutlinedBorder`, so the card's corner is the caller's choice; its border is
  drawn with the shape's own side in the scrubber's border colour.
- Accessibility: the control exposes itself as a slider, with spoken label and
  value and working increase/decrease actions.
- Ticks are painted from the scroll offset rather than laid out, so the cost of
  a frame is set by the viewport instead of by the size of the range.
- Built on `material_ui`, the official Material Design library extracted from
  `package:flutter/material.dart`, rather than on the copy still inside the
  Flutter SDK.
