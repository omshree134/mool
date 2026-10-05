import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app/theme.dart';
import 'widgets/common.dart';

/// Know Your Rights & Entitlements
///
/// Comprehensive guide to statutory victim rights under Section 15A
/// and government rehabilitation entitlements under the SC/ST (PoA) Act.
class RightsGuidePage extends StatelessWidget {
  const RightsGuidePage({super.key});

  Future<void> _call(String number) async {
    final uri = Uri.parse('tel:$number');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Know Your Rights'),
        actions: const [GetHelpButton()],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 36),
        children: [
          // ── Header Banner ─────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: isDark ? MoolPalette.moss.withValues(alpha: 0.22) : MoolPalette.mossSoft,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: MoolPalette.moss.withValues(alpha: 0.35), width: 1.2),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: MoolPalette.moss,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.menu_book_rounded, color: Colors.white, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Section 15A Victim Charter',
                        style: GoogleFonts.inter(
                          fontSize: 16.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.2,
                          color: isDark ? scheme.onSurface : MoolPalette.mossDark,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'The law gives you enforceable legal rights throughout the investigation, bail hearings, trial, and rehabilitation process.',
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

          const SizedBox(height: 20),

          // ── Section 1: Core Statutory Rights ──────────────────────
          const _TitleRow(icon: Icons.shield_rounded, title: 'Your Rights During the Case', color: MoolPalette.moss),
          const SizedBox(height: 10),

          const _RightTile(
            title: 'Right to Be Heard on Bail Applications',
            subtitle: 'Section 15A(3)',
            description:
                'You have the legal right to reasonable notice of any bail proceeding filed by the accused. The court cannot grant bail without hearing your or your lawyer’s say.',
          ),
          const SizedBox(height: 8),

          const _RightTile(
            title: 'Right to Case Information & Documents',
            subtitle: 'Section 15A(2)',
            description:
                'You are entitled to receive free copies of the FIR, Charge Sheet, statements recorded under Section 161/164, and any other relevant case records.',
          ),
          const SizedBox(height: 8),

          const _RightTile(
            title: 'Right to Special Public Prosecutor of Choice',
            subtitle: 'Section 15(3) & State Rules',
            description:
                'If you do not feel confident in the regular prosecutor, you can apply to the District Magistrate to engage an experienced senior advocate of your choice, whose fees are paid by the State.',
          ),
          const SizedBox(height: 8),

          const _RightTile(
            title: 'Protection from Social Boycott & Discrimination',
            subtitle: 'Section 3(1)(zc)',
            description:
                'Imposing or threatening a social or economic boycott against you, your family, or your community is a separate, punishable atrocity offence with mandatory jail time.',
          ),

          const SizedBox(height: 24),

          // ── Section 2: Rehabilitation Entitlements ────────────────
          const _TitleRow(icon: Icons.handshake_rounded, title: 'Rehabilitation & Welfare Entitlements', color: MoolPalette.sandrose),
          const SizedBox(height: 10),

          const SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _EntitlementRow(
                  icon: Icons.school_outlined,
                  title: 'Education & Children Support',
                  desc: 'Children of victims are entitled to free education, books, uniforms, and hostel facilities in government institutions.',
                ),
                Divider(height: 20),
                _EntitlementRow(
                  icon: Icons.home_work_outlined,
                  title: 'Safe Housing & Relocation',
                  desc: 'If staying in your village is unsafe, the District Administration is obligated to provide safe alternative accommodation or a house plot.',
                ),
                Divider(height: 20),
                _EntitlementRow(
                  icon: Icons.work_outline_rounded,
                  title: 'Livelihood & Employment Assistance',
                  desc: 'State rules provide for vocational training, agricultural loan waivers, or government employment for eligible dependents in severe cases.',
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // ── Section 3: Free Legal Aid Contacts ────────────────────
          const _TitleRow(icon: Icons.phone_in_talk_rounded, title: 'Free Legal Aid & Grievance Numbers', color: MoolPalette.dusk),
          const SizedBox(height: 10),

          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: const BorderSide(color: MoolPalette.mist),
            ),
            child: ListTile(
              leading: const CircleAvatar(
                backgroundColor: MoolPalette.duskSoft,
                child: Icon(Icons.balance_rounded, color: MoolPalette.dusk),
              ),
              title: Text('NALSA Free Legal Aid', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
              subtitle: const Text('24/7 National Legal Services Authority (Toll-Free 15100)'),
              trailing: FilledButton(
                style: FilledButton.styleFrom(backgroundColor: MoolPalette.dusk),
                onPressed: () => _call('15100'),
                child: const Text('Call'),
              ),
            ),
          ),
          const SizedBox(height: 8),

          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: const BorderSide(color: MoolPalette.mist),
            ),
            child: ListTile(
              leading: const CircleAvatar(
                backgroundColor: MoolPalette.mossSoft,
                child: Icon(Icons.support_agent_rounded, color: MoolPalette.moss),
              ),
              title: Text('NHAA National Helpline', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
              subtitle: const Text('Atrocities Against SC/STs Portal & Helpline (14566)'),
              trailing: FilledButton(
                style: FilledButton.styleFrom(backgroundColor: MoolPalette.moss),
                onPressed: () => _call('14566'),
                child: const Text('Call'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TitleRow extends StatelessWidget {
  const _TitleRow({
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

class _RightTile extends StatelessWidget {
  const _RightTile({
    required this.title,
    required this.subtitle,
    required this.description,
  });

  final String title;
  final String subtitle;
  final String description;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: MoolPalette.mist),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(title, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: MoolPalette.mossSoft,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    subtitle,
                    style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.bold, color: MoolPalette.mossDark),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(description, style: GoogleFonts.inter(fontSize: 12.5, height: 1.45, color: scheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}

class _EntitlementRow extends StatelessWidget {
  const _EntitlementRow({
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
        Icon(icon, size: 20, color: MoolPalette.sandrose),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold)),
              const SizedBox(height: 2),
              Text(desc, style: GoogleFonts.inter(fontSize: 12, height: 1.4, color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ],
          ),
        ),
      ],
    );
  }
}
