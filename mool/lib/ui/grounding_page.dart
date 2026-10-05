import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/theme.dart';

class GroundingPage extends StatefulWidget {
  const GroundingPage({super.key});

  @override
  State<GroundingPage> createState() => _GroundingPageState();
}

class _GroundingPageState extends State<GroundingPage> {
  int _mode = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Breathe and ground')),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
              child: SegmentedButton<int>(
                segments: const [
                  ButtonSegment(value: 0, label: Text('Breathe'), icon: Icon(Icons.air)),
                  ButtonSegment(value: 1, label: Text('Notice'), icon: Icon(Icons.visibility_outlined)),
                ],
                selected: {_mode},
                onSelectionChanged: (s) => setState(() => _mode = s.first),
              ),
            ),
            Expanded(child: _mode == 0 ? const _BoxBreathing() : const _FiveFourThreeTwoOne()),
          ],
        ),
      ),
    );
  }
}

/// Box breathing: in 4, hold 4, out 4, hold 4.
class _BoxBreathing extends StatefulWidget {
  const _BoxBreathing();

  @override
  State<_BoxBreathing> createState() => _BoxBreathingState();
}

class _BoxBreathingState extends State<_BoxBreathing> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 16));
  int _lastPhase = -1;
  int _rounds = 0;

  static const _phases = ['Breathe in', 'Hold', 'Breathe out', 'Hold'];

  @override
  void initState() {
    super.initState();
    _c.addListener(() {
      final phase = (_c.value * 4).floor().clamp(0, 3);
      if (phase != _lastPhase) {
        if (phase == 0 && _lastPhase == 3) _rounds++;
        _lastPhase = phase;
        HapticFeedback.selectionClick();
      }
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() {
      if (_c.isAnimating) {
        _c.stop();
      } else {
        _c.repeat();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Expanded(
            child: AnimatedBuilder(
              animation: _c,
              builder: (context, _) {
                final v = _c.value;
                final phase = (v * 4).floor().clamp(0, 3);
                final within = (v * 4) - phase;
                final secondsLeft = 4 - (within * 4).floor();
                // Grow on "in", stay full on the first hold, shrink on "out".
                final grow = switch (phase) {
                  0 => within,
                  1 => 1.0,
                  2 => 1 - within,
                  _ => 0.0,
                };
                final size = reduceMotion ? 0.8 : 0.5 + 0.5 * Curves.easeInOut.transform(grow);
                return Center(
                  child: LayoutBuilder(
                    builder: (context, box) {
                      final max = box.biggest.shortestSide * 0.85;
                      return Container(
                        width: max * size,
                        height: max * size,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: MoolPalette.dusk.withValues(alpha: 0.18),
                          border: Border.all(color: MoolPalette.dusk, width: 3),
                        ),
                        alignment: Alignment.center,
                        child: Semantics(
                          liveRegion: true,
                          child: Text(
                            _c.isAnimating ? '${_phases[phase]}\n$secondsLeft' : 'Ready when you are',
                            textAlign: TextAlign.center,
                            style: t.titleLarge,
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
          Text(
            _rounds == 0 ? 'Follow the circle. Four counts each.' : '$_rounds round${_rounds == 1 ? '' : 's'}',
            style: t.bodyMedium,
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(onPressed: _toggle, child: Text(_c.isAnimating ? 'Pause' : 'Start')),
          ),
        ],
      ),
    );
  }
}

class _FiveFourThreeTwoOne extends StatefulWidget {
  const _FiveFourThreeTwoOne();

  @override
  State<_FiveFourThreeTwoOne> createState() => _FiveFourThreeTwoOneState();
}

class _FiveFourThreeTwoOneState extends State<_FiveFourThreeTwoOne> {
  int _step = 0;

  static const _steps = [
    (5, 'things you can see', 'Look around slowly. Name each one quietly to yourself.'),
    (4, 'things you can touch', 'Your clothes, the floor under your feet, something near you.'),
    (3, 'things you can hear', 'Near sounds and far sounds.'),
    (2, 'things you can smell', 'If nothing comes, think of two smells you like.'),
    (1, 'thing you can taste', 'Or one kind thing you can say to yourself.'),
  ];

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final finished = _step >= _steps.length;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Spacer(),
          if (finished) ...[
            Text('Take a moment', style: t.headlineSmall, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            Text('Notice how you feel now. You can do this again any time.',
                style: t.bodyLarge, textAlign: TextAlign.center),
          ] else ...[
            Text('${_steps[_step].$1}', style: t.headlineMedium?.copyWith(fontSize: 72), textAlign: TextAlign.center),
            Text(_steps[_step].$2, style: t.headlineSmall, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            Text(_steps[_step].$3, style: t.bodyLarge, textAlign: TextAlign.center),
          ],
          const Spacer(),
          FilledButton(
            onPressed: () => setState(() => _step = finished ? 0 : _step + 1),
            child: Text(finished ? 'Start again' : 'Next'),
          ),
          if (_step > 0 && !finished)
            TextButton(onPressed: () => setState(() => _step--), child: const Text('Back')),
        ],
      ),
    );
  }
}
