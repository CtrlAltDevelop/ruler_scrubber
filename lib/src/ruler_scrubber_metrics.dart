/// Fixed metrics of [RulerScrubber], taken from the design.
///
/// Kept in one place so the card, the ruler and the needle cannot drift apart
/// — the painter and the widget both derive their geometry from these.
library;

/// Corner radius of the card the ruler is drawn in.
const double kRulerCardRadius = 10;

/// Padding inside that card. Horizontal padding is what the ruler runs out
/// under, so the ticks are not cut off flush against the border.
const double kRulerCardPaddingH = 16;

/// Vertical padding inside the card.
const double kRulerCardPaddingV = 8;

/// Width of the card's border.
const double kRulerCardBorderWidth = 1;

/// Height of the ruler strip: the caret, the gap under it and the needle.
const double kRulerStripHeight =
    kRulerCaretHeight + kRulerCaretGap + kRulerNeedleHeight;

/// The triangle that caps the needle, marking the read-off point.
const double kRulerCaretWidth = 7;

/// Height of the triangle capping the needle. See [kRulerCaretWidth].
const double kRulerCaretHeight = 4;

/// Space between the caret and the needle under it.
const double kRulerCaretGap = 2;

/// The bar the ruler is read against, standing still in the middle of the
/// card while the ticks travel under it.
const double kRulerNeedleWidth = 2;

/// Height of the needle bar. See [kRulerNeedleWidth].
const double kRulerNeedleHeight = 20;

/// Corner radius of the needle, which makes its ends round.
const double kRulerNeedleRadius = 10;

/// Distance between two ticks. Close enough that the ruler reads as a scale
/// rather than as a row of marks that can be counted.
const double kRulerTickSpacing = 7;

/// Stroke width of one tick.
const double kRulerTickWidth = 1;

/// Height of a plain tick and of the taller one that punctuates the ruler.
/// Both sit well inside the needle's own height, so the needle reads as
/// standing over the ruler rather than as one more mark on it.
const double kRulerMinorTickHeight = 8;

/// Height of a tall tick.
const double kRulerMajorTickHeight = 14;

/// How far in from each end the ticks fade up to full strength.
///
/// The ruler runs past both edges of the card, and a column of them cut off
/// flush reads as a row of boxes. Fading the ends is what makes each one look
/// like a strip of something longer passing through.
const double kRulerFadeWidth = 44;

/// How many ticks apart the tall ones are.
const int kRulerMajorTickEvery = 5;

/// How far the ruler may sit from a value before it is run there — half a
/// pixel, which is below what either the eye or the value can tell apart.
const double kRulerSettleTolerance = 0.5;

/// How long the ruler takes to run to a value set from somewhere other than
/// the finger — the stepper next to it, or the owning bloc.
const Duration kRulerSettleDuration = Duration(milliseconds: 260);

/// How long the card and the needle take to pick up their scrubbing colours.
const Duration kRulerActiveDuration = Duration(milliseconds: 160);

/// Height of the strip the tick labels are drawn in, and the gap between it
/// and the ruler above it. Fixed rather than measured, so turning labels on
/// changes the scrubber's height by a known amount and a row of them stays
/// aligned whatever they say.
const double kRulerLabelHeight = 14;

/// Space between the ticks and the labels under them.
const double kRulerLabelGap = 4;

/// Font size of a tick label when the style carries no [TextStyle] of its own.
const double kRulerLabelFontSize = 10;

/// How far one press of an arrow key moves a focused ruler, as a fraction of
/// the range, when there is no `step` to move by instead.
const double kRulerKeyNudgeFraction = 1 / 20;

/// How far Page Up and Page Down move a focused ruler, relative to one press
/// of an arrow key.
const int kRulerPageNudgeMultiple = 10;

/// Opacity a disabled scrubber is drawn at.
const double kRulerDisabledOpacity = 0.38;
