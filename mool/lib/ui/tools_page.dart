import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../app/theme.dart';
import '../models/screener.dart';
import 'compensation_page.dart';
import 'court_companion_page.dart';
import 'evidence_vault_page.dart';
import 'grounding_page.dart';
import 'help_page.dart';
import 'ivrs_simulator_page.dart';
import 'report_page.dart';
import 'rights_guide_page.dart';
import 'safety_plan_page.dart';
import 'screener_page.dart';
import 'sleep_sanctuary_page.dart';
import 'widgets/common.dart';

class ToolsPage extends StatelessWidget {
  const ToolsPage({super.key});

  void _open(BuildContext context, Widget page) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));

  Future<void> _chooseQuestionnaire(BuildContext context) async {
    final def = await showModalBottomSheet<ScreenerDefinition>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 14),
                child: Text(
                  'Select a Screener',
                  style: GoogleFonts.inter(
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                    color: MoolPalette.ink,
                  ),
                ),
              ),
              for (final d in ScreenerDefinition.all)
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                  leading: const CircleAvatar(
                    radius: 18,
                    backgroundColor: MoolPalette.sandroseSoft,
                    child: Icon(Icons.assignment_outlined, size: 18, color: MoolPalette.sandrose),
                  ),
                  title: Text(
                    d.friendlyTitle,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  subtitle: Text(
                    '${d.items.length} questions • Private & confidential',
                    style: const TextStyle(fontSize: 12),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded, size: 20),
                  onTap: () => Navigator.pop(ctx, d),
                ),
            ],
          ),
        ),
      ),
    );
    if (def != null && context.mounted) {
      await Navigator.of(context).push(
        MaterialPageRoute(fullscreenDialog: true, builder: (_) => ScreenerPage(definition: def)),
      );
    }
  }

  Widget _sectionTitle(BuildContext context, String title, {String? subtitle}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 22, 4, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : MoolPalette.ink,
              letterSpacing: -0.2,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: isDark ? const Color(0xFFA5ABA3) : MoolPalette.slate,
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tools & Support'),
        actions: const [GetHelpButton()],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 36),
        children: [
          // ── 1. Daily Mind & Sleep Recovery ────────────────────────
          _sectionTitle(
            context,
            'Mind & Daily Recovery',
            subtitle: 'Gentle grounding, evening sanctuary, and clinical wellbeing checks',
          ),
          ToolTile(
            icon: Icons.air_rounded,
            title: 'Breathe and Ground',
            subtitle: '5-4-3-2-1 sensory grounding and guided calming breaths',
            onTap: () => _open(context, const GroundingPage()),
          ),
          ToolTile(
            icon: Icons.nightlight_round,
            title: 'Sleep Sanctuary',
            subtitle: 'Progressive muscle relaxation, night soundscapes & affirmations',
            onTap: () => _open(context, const SleepSanctuaryPage()),
          ),
          ToolTile(
            icon: Icons.assignment_outlined,
            title: 'Clinical Wellbeing Screeners',
            subtitle: 'Validated assessments for anxiety, depression, insomnia, and trauma',
            onTap: () => _chooseQuestionnaire(context),
          ),

          // ── 2. Helplines & Voice Careline ─────────────────────────
          _sectionTitle(
            context,
            'Helplines & Voice Support',
            subtitle: '24/7 toll-free crisis desks and automated voice check-in',
          ),
          ToolTile(
            icon: Icons.phone_in_talk_rounded,
            title: 'Helplines & Emergency Numbers',
            subtitle: 'Tele-MANAS (14416), NHAA Atrocity Helpline (14566), and 112',
            tag: '24/7 Free',
            iconColor: MoolPalette.signal,
            onTap: () => _open(context, const HelpPage()),
          ),
          ToolTile(
            icon: Icons.dialpad_rounded,
            title: 'Toll-Free Voice Careline',
            subtitle: 'Dial 1800-MOOL-CARE for automated check-in and voice reflection',
            tag: '1800 Free',
            onTap: () => _open(context, const IvrsSimulatorPage()),
          ),

          // ── 3. Safety & Evidence Protection ───────────────────────
          _sectionTitle(
            context,
            'Safety & Protection',
            subtitle: 'Confidential action plans and tamper-evident incident logging',
          ),
          ToolTile(
            icon: Icons.shield_outlined,
            title: 'My Safety Plan',
            subtitle: 'Action steps, designated safe spaces, and trusted people',
            onTap: () => _open(context, const SafetyPlanPage()),
          ),
          ToolTile(
            icon: Icons.lock_clock_outlined,
            title: 'Evidence & Incident Vault',
            subtitle: 'Log intimidation, threats, or stalking with encrypted export',
            tag: 'Encrypted',
            onTap: () => _open(context, const EvidenceVaultPage()),
          ),
          ToolTile(
            icon: Icons.notification_important_outlined,
            title: 'Report What Happened',
            subtitle: 'Submit an incident report for immediate responder assistance',
            onTap: () => _open(context, const ReportPage()),
          ),

          // ── 4. Legal Rights & Statutory Relief ────────────────────
          _sectionTitle(
            context,
            'Rights & Judicial Milestones',
            subtitle: 'Statutory Section 15A protection, court dates, and financial relief',
          ),
          ToolTile(
            icon: Icons.verified_user_outlined,
            title: 'Know Your Rights (Section 15A)',
            subtitle: 'Victim rights charter under SC/ST Act, free legal aid & protection',
            onTap: () => _open(context, const RightsGuidePage()),
          ),
          ToolTile(
            icon: Icons.balance_rounded,
            title: 'Court Hearing Companion',
            subtitle: 'Preparation checklist, Special Court stages & trial rights',
            onTap: () => _open(context, const CourtCompanionPage()),
          ),
          ToolTile(
            icon: Icons.account_balance_wallet_outlined,
            title: 'Compensation & Relief Guide',
            subtitle: '3-Stage statutory financial assistance under PoA Act Rule 12(4)',
            onTap: () => _open(context, const CompensationPage()),
          ),
        ],
      ),
    );
  }
}
