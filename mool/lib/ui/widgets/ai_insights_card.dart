import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../app/theme.dart';
import '../../models/distress.dart';
import '../ai_chat_page.dart';
import '../grounding_page.dart';
import '../help_page.dart';
import '../sleep_sanctuary_page.dart';
import 'common.dart';

/// Clean, concise wellbeing reflection card for the Today page.
///
/// Designed with trauma-informed sensitivity:
/// - Distinct, visible card edge matching all other SectionCards.
/// - Harmonious, unified color scheme (no clashing rainbow palette).
/// - High-contrast, scannable visual pillars: Sleep, Movement, Mind.
/// - Tactile, premium action buttons with depth and clear hierarchy.
/// - Zero emojis; clean, professional vector iconography.
class AiInsightsCard extends StatelessWidget {
  const AiInsightsCard({super.key, this.result});
  final DistressResult? result;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final state = _resolveState(result);
    final accentColor = isDark ? state.darkColor : state.color;
    final isElevated = result != null &&
        (result!.tier == Tier.urgent ||
            result!.tier == Tier.crisis ||
            result!.tier == Tier.outreach);

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header Row ──────────────────────────────────────────
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: isDark
                      ? accentColor.withValues(alpha: 0.22)
                      : state.softBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: accentColor.withValues(alpha: isDark ? 0.55 : 0.4),
                    width: 1.2,
                  ),
                ),
                child: Center(
                  child: Icon(state.icon, size: 20, color: accentColor),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Today’s Reflection',
                      style: GoogleFonts.inter(
                        fontSize: 16.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                        color: isDark ? Colors.white : MoolPalette.ink,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      'Personal wellbeing check',
                      style: GoogleFonts.inter(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                        color: isDark ? const Color(0xFFA5ABA3) : MoolPalette.slate,
                      ),
                    ),
                  ],
                ),
              ),
              // Compact status chip with visible contrast
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: isDark
                      ? accentColor.withValues(alpha: 0.2)
                      : state.softBg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: accentColor.withValues(alpha: isDark ? 0.6 : 0.45),
                    width: 1.1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: accentColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      state.tag,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: accentColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // ── Concise 1-Sentence Reflection ────────────────────────
          Text(
            state.summary,
            style: GoogleFonts.inter(
              fontSize: 13.5,
              height: 1.45,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white : MoolPalette.ink,
            ),
          ),

          const SizedBox(height: 16),

          // ── 3-Column Scannable Pillars (Cohesive Theme, High Contrast) ──
          Row(
            children: [
              Expanded(
                child: _PillarBadge(
                  icon: Icons.nightlight_round,
                  label: 'Sleep',
                  value: _sleepLabel(result),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SleepSanctuaryPage()),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _PillarBadge(
                  icon: Icons.directions_walk_rounded,
                  label: 'Movement',
                  value: _movementLabel(result),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _PillarBadge(
                  icon: Icons.self_improvement_rounded,
                  label: 'Mind Space',
                  value: _mindLabel(result),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const GroundingPage()),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          // ── Tactile Action Buttons (Cohesive Mool Brand Hierarchy) ──
          Row(
            children: [
              Expanded(
                child: Material(
                  color: isDark ? const Color(0xFF262C25) : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  elevation: 1,
                  shadowColor: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const GroundingPage()),
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12.5),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isDark
                              ? const Color(0xFF6B8E6A)
                              : const Color(0xFF5F7A5E),
                          width: 1.4,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.air_rounded,
                            size: 18,
                            color: isDark ? const Color(0xFFA5CCA4) : const Color(0xFF3B563A),
                          ),
                          const SizedBox(width: 7),
                          Text(
                            'Breathe',
                            style: GoogleFonts.inter(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: isDark ? const Color(0xFFA5CCA4) : const Color(0xFF3B563A),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Material(
                  color: MoolPalette.moss,
                  borderRadius: BorderRadius.circular(14),
                  elevation: 2,
                  shadowColor: MoolPalette.moss.withValues(alpha: 0.35),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const AiChatPage()),
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12.5),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isDark
                              ? const Color(0xFF7A9E78)
                              : const Color(0xFF4E674D),
                          width: 1.2,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.chat_bubble_rounded,
                            size: 17,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 7),
                          Text(
                            'Talk to Mool',
                            style: GoogleFonts.inter(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),

          // High Priority Support Button (only when distress is elevated)
          if (isElevated) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  backgroundColor: MoolPalette.signal,
                  foregroundColor: Colors.white,
                  elevation: 0,
                ),
                icon: const Icon(Icons.support_agent_rounded, size: 18, color: Colors.white),
                label: Text(
                  'Reach Counsellor & Support',
                  style: GoogleFonts.inter(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const HelpPage()),
                ),
              ),
            ),
          ],

          const SizedBox(height: 14),

          // ── Privacy Footer ───────────────────────────────────────
          Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.lock_outline_rounded,
                  size: 13,
                  color: isDark ? const Color(0xFFA5ABA3) : MoolPalette.slate,
                ),
                const SizedBox(width: 5),
                Text(
                  'Private on this device • Never graded or judged',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: isDark ? const Color(0xFFA5ABA3) : MoolPalette.slate,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  _ReflectionState _resolveState(DistressResult? r) {
    if (r == null) {
      return const _ReflectionState(
        tag: 'Steady rhythm',
        summary:
            'Your daily rhythm is flowing smoothly. Take quiet pauses today and honor your steady progress.',
        color: MoolPalette.moss,
        darkColor: Color(0xFFA5CCA4),
        softBg: MoolPalette.mossSoft,
        icon: Icons.wb_twilight_rounded,
      );
    }
    switch (r.tier) {
      case Tier.crisis:
      case Tier.urgent:
        return const _ReflectionState(
          tag: 'Support close by',
          summary:
              'Things feel heavy right now. Take small, slow breaths—your safety and peace are what matter most.',
          color: MoolPalette.signal,
          darkColor: Color(0xFFF48F7C),
          softBg: MoolPalette.signalSoft,
          icon: Icons.favorite_rounded,
        );
      case Tier.outreach:
        return const _ReflectionState(
          tag: 'Gentle care',
          summary:
              'Recent days have asked a lot from you. Give yourself permission to pause and take things at your own pace.',
          color: Color(0xFF5A7A58),
          darkColor: Color(0xFFA5CCA4),
          softBg: MoolPalette.mossSoft,
          icon: Icons.wb_cloudy_outlined,
        );
      case Tier.watch:
        return const _ReflectionState(
          tag: 'One step at a time',
          summary:
              'Some moments may feel unsettled. A quiet pause or grounding breath can bring gentle relief.',
          color: Color(0xFF527450),
          darkColor: Color(0xFFA5CCA4),
          softBg: MoolPalette.mossSoft,
          icon: Icons.spa_outlined,
        );
      case Tier.stable:
      case Tier.insufficientData:
        return const _ReflectionState(
          tag: 'Steady rhythm',
          summary:
              'Your daily rhythm is flowing smoothly. Honor each small moment of peace and steady progress.',
          color: MoolPalette.moss,
          darkColor: Color(0xFFA5CCA4),
          softBg: MoolPalette.mossSoft,
          icon: Icons.wb_twilight_rounded,
        );
    }
  }

  String _sleepLabel(DistressResult? r) {
    if (r == null) return 'Not logged';
    final s = r.components['selfReport'];
    if (s == null) return 'Not logged';
    if (s > 0.6) return 'Light rest';
    if (s < 0.35) return 'Restful';
    return 'Moderate';
  }

  String _movementLabel(DistressResult? r) {
    if (r == null) return 'Gentle pace';
    final b = r.components['behaviour'];
    if (b == null) return 'Gentle pace';
    if (b > 0.6) return 'Quiet day';
    return 'Steady';
  }

  String _mindLabel(DistressResult? r) {
    if (r == null) return 'Grounded';
    switch (r.tier) {
      case Tier.crisis:
      case Tier.urgent:
        return 'Needs care';
      case Tier.outreach:
        return 'Tender';
      case Tier.watch:
        return 'Uneasy';
      case Tier.stable:
      case Tier.insufficientData:
        return 'Grounded';
    }
  }
}

class _ReflectionState {
  const _ReflectionState({
    required this.tag,
    required this.summary,
    required this.color,
    required this.darkColor,
    required this.softBg,
    required this.icon,
  });

  final String tag;
  final String summary;
  final Color color;
  final Color darkColor;
  final Color softBg;
  final IconData icon;
}

/// Compact pillar tile that displays a single wellbeing dimension scannably.
class _PillarBadge extends StatelessWidget {
  const _PillarBadge({
    required this.icon,
    required this.label,
    required this.value,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bg = isDark ? const Color(0xFF262C25) : const Color(0xFFF4F7F3);
    final border = isDark ? const Color(0xFF3B453A) : const Color(0xFFD4DFD2);
    final iconColor = isDark ? const Color(0xFFA2CCA1) : const Color(0xFF436542);
    final labelColor = isDark ? const Color(0xFFA5ABA3) : const Color(0xFF5A6358);
    final valueColor = isDark ? Colors.white : const Color(0xFF1E261D);

    Widget content = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: border,
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 15, color: iconColor),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: labelColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: valueColor,
            ),
          ),
        ],
      ),
    );

    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: content,
        ),
      );
    }

    return content;
  }
}
