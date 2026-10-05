import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../app/theme.dart';
import '../core/local_store.dart';
import 'grounding_page.dart';
import 'widgets/common.dart';

/// Court Hearing Companion
///
/// Designed to alleviate acute fear and confusion surrounding Special Court appearances
/// under the SC/ST (Prevention of Atrocities) Act.
class CourtCompanionPage extends StatefulWidget {
  const CourtCompanionPage({super.key});

  @override
  State<CourtCompanionPage> createState() => _CourtCompanionPageState();
}

class _CourtCompanionPageState extends State<CourtCompanionPage> {
  static const _checkKey = 'court_checklist_items_v1';
  late Set<String> _checked;

  static const _checklist = [
    'Original Government ID (Aadhaar or Voter ID)',
    'Court summons copy received by post or police',
    'FIR and Charge Sheet copy (if provided by IO)',
    'Medical records or injury certificates',
    'Bus / train tickets or travel receipts (for TA/DA reimbursement)',
    'Trusted friend, family member, or social worker to accompany you',
    'Prescribed medicines, water bottle, and a light snack',
  ];

  @override
  void initState() {
    super.initState();
    final saved = LocalStore.instance.getStringList(_checkKey);
    _checked = saved.toSet();
  }

  Future<void> _toggle(String item) async {
    setState(() {
      if (_checked.contains(item)) {
        _checked.remove(item);
      } else {
        _checked.add(item);
      }
    });
    await LocalStore.instance.setStringList(_checkKey, _checked.toList());
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Court Hearing Companion'),
        actions: const [GetHelpButton()],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 36),
        children: [
          // ── Header Banner ─────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: isDark ? MoolPalette.dusk.withValues(alpha: 0.25) : MoolPalette.duskSoft,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: MoolPalette.dusk.withValues(alpha: 0.3),
                width: 1.2,
              ),
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
                  child: const Icon(Icons.gavel_rounded, color: Colors.white, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Navigating Your Hearing',
                        style: GoogleFonts.inter(
                          fontSize: 16.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.2,
                          color: isDark ? scheme.onSurface : MoolPalette.duskDark,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Under the SC/ST Act, Special Courts are mandated to conduct speedy trials with special protections for victims and witnesses.',
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

          const SizedBox(height: 16),

          // Quick Calming Button
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: MoolPalette.moss,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.air_rounded, size: 18),
              label: Text(
                'Calming Breath Before Entering Court',
                style: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.bold),
              ),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const GroundingPage()),
              ),
            ),
          ),

          const SizedBox(height: 24),

          // ── Section 1: Checklist ──────────────────────────────────
          const _SectionHeader(
            icon: Icons.checklist_rounded,
            title: 'Court Day Preparation Checklist',
            color: MoolPalette.dusk,
          ),
          const SizedBox(height: 10),
          SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Check off items as you gather them before your hearing date:',
                  style: GoogleFonts.inter(fontSize: 12, color: scheme.onSurfaceVariant),
                ),
                const SizedBox(height: 12),
                for (final item in _checklist)
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    activeColor: MoolPalette.dusk,
                    title: Text(
                      item,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        decoration: _checked.contains(item) ? TextDecoration.lineThrough : null,
                        color: _checked.contains(item)
                            ? scheme.onSurfaceVariant.withValues(alpha: 0.6)
                            : scheme.onSurface,
                      ),
                    ),
                    value: _checked.contains(item),
                    onChanged: (_) => _toggle(item),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // ── Section 2: Court Stages ───────────────────────────────
          const _SectionHeader(
            icon: Icons.timeline_rounded,
            title: 'What Happens During Your Hearing',
            color: MoolPalette.moss,
          ),
          const SizedBox(height: 10),
          const _InfoExpandCard(
            title: '1. Arriving & Finding Your Public Prosecutor',
            subtitle: 'First steps at the courtroom',
            content:
                '• Reach the Special Court 30 to 45 minutes before the scheduled time.\n'
                '• Meet the Special Public Prosecutor (SPP) assigned to your case. They represent you on behalf of the State.\n'
                '• You can request a separate, secure waiting room away from the accused and their associates.',
          ),
          const SizedBox(height: 8),
          const _InfoExpandCard(
            title: '2. Your Testimony (Examination-in-Chief)',
            subtitle: 'Telling your side of the events',
            content:
                '• You will stand in the witness box. An oath will be administered.\n'
                '• The Public Prosecutor will guide you through questions to recount what occurred.\n'
                '• Speak clearly and truthfully. You may speak in your mother tongue; a translator will be provided if needed.',
          ),
          const SizedBox(height: 8),
          const _InfoExpandCard(
            title: '3. Cross-Examination by Defence Counsel',
            subtitle: 'How to stay calm and grounded',
            content:
                '• The lawyer for the accused will question your testimony.\n'
                '• Rules to remember:\n'
                '  - Take a breath before answering every question.\n'
                '  - If a question is insulting or scandalous, your Prosecutor will object.\n'
                '  - If you do not remember a date or detail, simply say "I do not recall" rather than guessing.\n'
                '  - You have the right to request a glass of water or a brief pause if you feel faint or overwhelmed.',
          ),

          const SizedBox(height: 24),

          // ── Section 3: Statutory Rights (Section 15A) ─────────────
          const _SectionHeader(
            icon: Icons.shield_rounded,
            title: 'Your Rights & Protections (Section 15A)',
            color: MoolPalette.sandrose,
          ),
          const SizedBox(height: 10),
          const _InfoExpandCard(
            title: 'Screening & In-Camera Proceedings',
            subtitle: 'Protection from direct visual contact',
            content:
                'Under Section 15A(10) of the SC/ST Act, the Court can conduct proceedings in-camera (closed to the public) and install screens or partitions so you do not have to see the accused while giving testimony.',
          ),
          const SizedBox(height: 8),
          const _InfoExpandCard(
            title: 'Travel & Daily Allowance (TA/DA)',
            subtitle: 'Reimbursement for attending court',
            content:
                'Under Rule 11 of the SC/ST (PoA) Rules, victims and witnesses are legally entitled to reimbursement for travel expenses, maintenance, and daily allowance on the very day of attending court. Present your transport tickets to the court clerk.',
          ),
          const SizedBox(height: 8),
          const _InfoExpandCard(
            title: 'Protection from Intimidation & Harassment',
            subtitle: 'Police protection obligations',
            content:
                'It is the statutory duty of the State and Investigating Officer to protect you, your family, and your property from threats. If anyone threatens you or attempts to influence your testimony, report it immediately—witness intimidation is a non-bailable offence.',
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.color,
  });

  final IconData icon;
  final String title;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ],
    );
  }
}

class _InfoExpandCard extends StatelessWidget {
  const _InfoExpandCard({
    required this.title,
    required this.subtitle,
    required this.content,
  });

  final String title;
  final String subtitle;
  final String content;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: MoolPalette.mist),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        title: Text(
          title,
          style: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          subtitle,
          style: GoogleFonts.inter(fontSize: 11.5, color: scheme.onSurfaceVariant),
        ),
        children: [
          Text(
            content,
            style: GoogleFonts.inter(fontSize: 12.5, height: 1.5, color: scheme.onSurface),
          ),
        ],
      ),
    );
  }
}
