# Changelog

## 0.1.0

Initial release.

- `RulerScrubber`: a ruler-style numeric input that scrolls under a stationary
  needle, with platform scroll physics, flick-to-coast and per-tick haptics.
- `RulerScrubberStyle`: design-system colours and shadows, derived from the
  ambient `ThemeData` when omitted.
- Accessibility: the control exposes itself as a slider, with spoken label and
  value and working increase/decrease actions.
- Ticks are painted from the scroll offset rather than laid out, so the cost of
  a frame is set by the viewport instead of by the size of the range.
