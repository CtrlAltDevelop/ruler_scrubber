# Changelog

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
