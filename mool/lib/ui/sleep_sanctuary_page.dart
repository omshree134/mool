import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../app/theme.dart';
import 'widgets/common.dart';

/// Sleep Sanctuary & Body Release
///
/// Designed specifically for trauma victims experiencing hypervigilance,
/// nocturnal panic, and sleep disturbances after atrocity incidents.
class SleepSanctuaryPage extends StatefulWidget {
  const SleepSanctuaryPage({super.key});

  @override
  State<SleepSanctuaryPage> createState() => _SleepSanctuaryPageState();
}

class _SleepSanctuaryPageState extends State<SleepSanctuaryPage> {
  int _activeTab = 0; // 0: Muscle Relaxation, 1: Ambient Sounds, 2: Night Routine

  // PMR State
  int _pmrStep = 0;
  bool _pmrRunning = false;
  int _pmrCountdown = 10;
  Timer? _pmrTimer;

  static const _pmrSteps = [
    _PmrStep('Feet & Toes', 'Curl your toes inward tightly. Notice the tension. Hold... now completely release and let warmth flow through your feet.'),
    _PmrStep('Calves & Knees', 'Point your toes upward toward your knees. Feel your calf muscles tighten. Hold... now let the tension melt away completely.'),
    _PmrStep('Abdomen & Breath', 'Take a deep breath and gently hold your stomach muscles firm. Hold... now breathe out slowly, feeling your belly soften.'),
    _PmrStep('Shoulders & Neck', 'Raise your shoulders toward your ears. Hold the tension in your upper back... now drop them completely. Feel the heavy relief.'),
    _PmrStep('Jaw & Face', 'Clench your jaw lightly and close your eyes tight. Hold... now relax your forehead, unclench your jaw, and let your face soften.'),
    _PmrStep('Whole Body Rest', 'Feel your entire body supported by the bed. Every muscle is safe to let go of guard. You are safe here tonight.'),
  ];

  // Ambient Sound State
  String? _playingSound;
  int _timerMinutes = 30;

  static const _soundscapes = [
    _Soundscape('Monsoon Rain', 'Gentle, steady raindrops on rooftop leaves', Icons.water_drop_outlined),
    _Soundscape('Night Crickets', 'Quiet evening sounds of an open village meadow', Icons.nature_people_outlined),
    _Soundscape('Mountain Stream', 'Soft flowing water washing away the day', Icons.waves_rounded),
    _Soundscape('Deep Calm Resonance', 'Warm low-frequency harmonic drone for deep rest', Icons.surround_sound_rounded),
  ];

  @override
  void dispose() {
    _pmrTimer?.cancel();
    super.dispose();
  }

  void _startPmr() {
    setState(() {
      _pmrRunning = true;
      _pmrCountdown = 10;
    });
    _pmrTimer?.cancel();
    _pmrTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_pmrCountdown > 1) {
        setState(() => _pmrCountdown--);
      } else {
        HapticFeedback.lightImpact();
        if (_pmrStep < _pmrSteps.length - 1) {
          setState(() {
            _pmrStep++;
            _pmrCountdown = 10;
          });
        } else {
          t.cancel();
          setState(() {
            _pmrRunning = false;
            _pmrStep = 0;
          });
        }
      }
    });
  }

  void _pausePmr() {
    _pmrTimer?.cancel();
    setState(() => _pmrRunning = false);
  }

  void _toggleSound(String title) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_playingSound == title) {
        _playingSound = null;
      } else {
        _playingSound = title;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sleep Sanctuary'),
        actions: const [GetHelpButton()],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 36),
        children: [
          // ── Header Banner ─────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: isDark ? MoolPalette.dusk.withValues(alpha: 0.3) : MoolPalette.duskSoft,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: MoolPalette.dusk.withValues(alpha: 0.3), width: 1.2),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: MoolPalette.dusk,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.nightlight_round, color: Colors.white, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Nighttime Body Calm',
                        style: GoogleFonts.inter(
                          fontSize: 16.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.2,
                          color: isDark ? scheme.onSurface : MoolPalette.duskDark,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Trauma often keeps the nervous system on high alert at night. These tools gently signal to your body that it is safe to rest.',
                        style: GoogleFonts.inter(
                          fontSize: 12.5,
                          height: 1.4,
                          color: isDark ? scheme.onSurfaceVariant : MoolPalette.slate,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 18),

          // Segmented Switcher
          SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 0, label: Text('Body Release'), icon: Icon(Icons.self_improvement_rounded)),
              ButtonSegment(value: 1, label: Text('Calm Sounds'), icon: Icon(Icons.graphic_eq_rounded)),
              ButtonSegment(value: 2, label: Text('Safety Check'), icon: Icon(Icons.shield_outlined)),
            ],
            selected: {_activeTab},
            onSelectionChanged: (s) => setState(() => _activeTab = s.first),
          ),

          const SizedBox(height: 20),

          // ── Tab 0: Progressive Muscle Relaxation ───────────────────
          if (_activeTab == 0) ...[
            SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Step ${_pmrStep + 1} of ${_pmrSteps.length}',
                        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: MoolPalette.moss),
                      ),
                      if (_pmrRunning)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: MoolPalette.mossSoft,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '$_pmrCountdown s',
                            style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: MoolPalette.mossDark),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _pmrSteps[_pmrStep].title,
                    style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, letterSpacing: -0.3),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _pmrSteps[_pmrStep].instruction,
                    style: GoogleFonts.inter(fontSize: 13.5, height: 1.5, color: scheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: _pmrRunning ? MoolPalette.dusk : MoolPalette.moss,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: Icon(_pmrRunning ? Icons.pause_rounded : Icons.play_arrow_rounded, size: 20),
                      label: Text(
                        _pmrRunning ? 'Pause Guided Release' : 'Begin Guided Bodily Release',
                        style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                      onPressed: _pmrRunning ? _pausePmr : _startPmr,
                    ),
                  ),
                ],
              ),
            ),
          ],

          // ── Tab 1: Ambient Soundscapes ────────────────────────────
          if (_activeTab == 1) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Sleep Timer',
                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold),
                ),
                DropdownButton<int>(
                  value: _timerMinutes,
                  underline: const SizedBox.shrink(),
                  items: const [
                    DropdownMenuItem(value: 15, child: Text('15 Minutes')),
                    DropdownMenuItem(value: 30, child: Text('30 Minutes')),
                    DropdownMenuItem(value: 60, child: Text('1 Hour')),
                    DropdownMenuItem(value: 0, child: Text('Continuous')),
                  ],
                  onChanged: (v) => setState(() => _timerMinutes = v ?? 30),
                ),
              ],
            ),
            const SizedBox(height: 10),
            for (final s in _soundscapes) ...[
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(
                    color: _playingSound == s.title
                        ? MoolPalette.dusk
                        : (isDark ? scheme.outlineVariant.withValues(alpha: 0.2) : MoolPalette.mist),
                    width: _playingSound == s.title ? 1.6 : 1,
                  ),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  leading: CircleAvatar(
                    backgroundColor: _playingSound == s.title ? MoolPalette.dusk : MoolPalette.duskSoft,
                    child: Icon(s.icon, color: _playingSound == s.title ? Colors.white : MoolPalette.dusk, size: 20),
                  ),
                  title: Text(s.title, style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14)),
                  subtitle: Text(s.subtitle, style: GoogleFonts.inter(fontSize: 11.5, color: scheme.onSurfaceVariant)),
                  trailing: Icon(
                    _playingSound == s.title ? Icons.stop_circle_rounded : Icons.play_circle_fill_rounded,
                    color: _playingSound == s.title ? MoolPalette.dusk : MoolPalette.moss,
                    size: 32,
                  ),
                  onTap: () => _toggleSound(s.title),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ],

          // ── Tab 2: Nighttime Safety Check ────────────────────────
          if (_activeTab == 2) ...[
            SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Reassuring Your Space Before Sleep',
                    style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: -0.2),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'When hypervigilance keeps you awake, consciously acknowledging safety helps your nervous system stand down:',
                    style: GoogleFonts.inter(fontSize: 12, color: scheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 14),
                  const _SafetyAffirmationRow(
                    icon: Icons.lock_outline_rounded,
                    title: 'Physical Boundaries',
                    desc: 'Doors and windows are latched and confirmed secure.',
                  ),
                  const Divider(height: 18),
                  const _SafetyAffirmationRow(
                    icon: Icons.phone_android_rounded,
                    title: 'Emergency Ready',
                    desc: 'Your phone is charged and the 112 SOS trigger is active.',
                  ),
                  const Divider(height: 18),
                  const _SafetyAffirmationRow(
                    icon: Icons.hotel_rounded,
                    title: 'Permission to Rest',
                    desc: 'You do not have to stand guard tonight. It is safe to close your eyes.',
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PmrStep {
  const _PmrStep(this.title, this.instruction);
  final String title;
  final String instruction;
}

class _Soundscape {
  const _Soundscape(this.title, this.subtitle, this.icon);
  final String title;
  final String subtitle;
  final IconData icon;
}

class _SafetyAffirmationRow extends StatelessWidget {
  const _SafetyAffirmationRow({
    required this.icon,
    required this.title,
    required this.desc,
  });

  final IconData icon;
  final String title;
  final String desc;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: MoolPalette.dusk),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold)),
              const SizedBox(height: 2),
              Text(desc, style: GoogleFonts.inter(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ],
          ),
        ),
      ],
    );
  }
}
