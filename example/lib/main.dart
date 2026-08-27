import 'package:material_ui/material_ui.dart';
import 'package:ruler_scrubber/ruler_scrubber.dart';

void main() => runApp(const ExampleApp());

class ExampleApp extends StatefulWidget {
  const ExampleApp({super.key});

  @override
  State<ExampleApp> createState() => _ExampleAppState();
}

class _ExampleAppState extends State<ExampleApp> {
  ThemeMode _mode = ThemeMode.light;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ruler_scrubber',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF3B5BFD)),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF3B5BFD),
          brightness: Brightness.dark,
        ),
      ),
      themeMode: _mode,
      home: ExamplePage(
        isDark: _mode == ThemeMode.dark,
        onBrightnessChanged: (isDark) =>
            setState(() => _mode = isDark ? ThemeMode.dark : ThemeMode.light),
      ),
    );
  }
}

class ExamplePage extends StatefulWidget {
  const ExamplePage({
    super.key,
    required this.isDark,
    required this.onBrightnessChanged,
  });

  final bool isDark;
  final ValueChanged<bool> onBrightnessChanged;

  @override
  State<ExamplePage> createState() => _ExamplePageState();
}

class _ExamplePageState extends State<ExamplePage> {
  double _price = 24.50;
  double _percent = 15;
  double _temperature = 21.5;

  /// The last value each scrubber came to rest on, so the difference between
  /// [RulerScrubber.onChanged] and [RulerScrubber.onChangeEnd] is visible.
  double? _settledPrice;

  /// Whether the price is locked, showing what a disabled scrubber looks
  /// like: dimmed and inert, but still readable and still a slider.
  bool _priceLocked = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('ruler_scrubber'),
        actions: [
          IconButton(
            tooltip: _priceLocked ? 'Unlock the price' : 'Lock the price',
            icon: Icon(_priceLocked ? Icons.lock : Icons.lock_open),
            onPressed: () => setState(() => _priceLocked = !_priceLocked),
          ),
          IconButton(
            tooltip: widget.isDark ? 'Light theme' : 'Dark theme',
            icon: Icon(widget.isDark ? Icons.light_mode : Icons.dark_mode),
            onPressed: () => widget.onBrightnessChanged(!widget.isDark),
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 32,
              children: [
                // Fine scrubbing over a wide range: two cents a tick, snapped
                // to the cent, so the ruler reaches £100 in a few flicks and
                // still lands on an exact price.
                _Field(
                  label: 'Price',
                  readout: '£${_price.toStringAsFixed(2)}',
                  caption: _priceLocked
                      ? 'Disabled: dimmed and inert, still a slider.'
                      : _settledPrice == null
                      ? 'Scrub it, or nudge it with the arrow keys.'
                      : 'Settled on £${_settledPrice!.toStringAsFixed(2)}.',
                  child: RulerScrubber(
                    value: _price,
                    min: 0,
                    max: 100,
                    step: 0.01,
                    tickStep: 0.02,
                    enabled: !_priceLocked,
                    // So the arrow keys, Page Up/Down and Home/End work
                    // without a click first on a desktop build.
                    autofocus: true,
                    semanticLabel: 'Price',
                    formatValue: (value) =>
                        '${value.toStringAsFixed(2)} pounds',
                    onChanged: (value) => setState(() => _price = value),
                    onChangeEnd: (value) =>
                        setState(() => _settledPrice = value),
                  ),
                ),

                // A coarse scale: one tick is one whole percent, so the ruler
                // cannot come to rest between two of them.
                _Field(
                  label: 'Deposit',
                  readout: '${_percent.round()}%',
                  caption: 'Snapped to whole percent, and numbered.',
                  child: RulerScrubber(
                    value: _percent,
                    min: 0,
                    max: 100,
                    step: 1,
                    tickStep: 1,
                    // A numbered ruler: every tenth tick carries its value,
                    // hung below the ruler so the needle stays put.
                    labelFormat: (value) => value.round().toString(),
                    labelEvery: 10,
                    semanticLabel: 'Deposit percentage',
                    formatValue: (value) => '${value.round()} percent',
                    onChanged: (value) => setState(() => _percent = value),
                  ),
                ),

                // Styled from design-system tokens rather than from the
                // theme, and given a shape of its own: the package has no
                // opinion about the corner, so a StadiumBorder is as
                // available as the default rounded rectangle.
                _Field(
                  label: 'Temperature',
                  readout: '${_temperature.toStringAsFixed(1)}°C',
                  caption: 'Explicit RulerScrubberStyle, with a pill shape.',
                  child: RulerScrubber(
                    value: _temperature,
                    min: -10,
                    max: 40,
                    step: 0.5,
                    tickStep: 0.1,
                    semanticLabel: 'Temperature',
                    formatValue: (value) =>
                        '${value.toStringAsFixed(1)} degrees',
                    style: RulerScrubberStyle(
                      shape: const StadiumBorder(side: BorderSide(width: 1.5)),
                      backgroundColor: theme.colorScheme.surfaceContainerLowest,
                      borderColor: theme.colorScheme.outlineVariant,
                      activeBorderColor: const Color(0xFFE1663B),
                      focusedBorderColor: const Color(0xFF8F9BB3),
                      minorTickColor: theme.colorScheme.outlineVariant,
                      majorTickColor: theme.colorScheme.onSurfaceVariant,
                      needleColor: theme.colorScheme.onSurfaceVariant,
                      activeShadows: const [
                        BoxShadow(blurRadius: 12, color: Color(0x22E1663B)),
                      ],
                      activeNeedleShadows: const [
                        BoxShadow(blurRadius: 6, color: Color(0x44E1663B)),
                      ],
                    ),
                    onChanged: (value) => setState(() => _temperature = value),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A labelled row: the name of the input, the value it currently holds, and
/// the ruler it is scrubbed with.
class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.readout,
    required this.caption,
    required this.child,
  });

  final String label;
  final String readout;
  final String caption;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 8,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(label, style: theme.textTheme.titleMedium),
            Text(
              readout,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
        child,
        Text(
          caption,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
