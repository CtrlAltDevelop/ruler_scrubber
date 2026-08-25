import 'package:flutter/material.dart';
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('ruler_scrubber'),
        actions: [
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
                  caption: _settledPrice == null
                      ? 'Scrub the ruler to set a price.'
                      : 'Settled on £${_settledPrice!.toStringAsFixed(2)}.',
                  child: RulerScrubber(
                    value: _price,
                    min: 0,
                    max: 100,
                    step: 0.01,
                    tickStep: 0.02,
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
                  caption: 'Snapped to whole percent.',
                  child: RulerScrubber(
                    value: _percent,
                    min: 0,
                    max: 100,
                    step: 1,
                    tickStep: 1,
                    semanticLabel: 'Deposit percentage',
                    formatValue: (value) => '${value.round()} percent',
                    onChanged: (value) => setState(() => _percent = value),
                  ),
                ),

                // Styled from design-system tokens rather than from the theme.
                _Field(
                  label: 'Temperature',
                  readout: '${_temperature.toStringAsFixed(1)}°C',
                  caption: 'Drawn with an explicit RulerScrubberStyle.',
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
                      backgroundColor: theme.colorScheme.surfaceContainerLowest,
                      borderColor: theme.colorScheme.outlineVariant,
                      activeBorderColor: const Color(0xFFE1663B),
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
