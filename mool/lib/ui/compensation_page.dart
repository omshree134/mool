import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../app/theme.dart';
import '../core/local_store.dart';
import 'widgets/common.dart';

/// Compensation & Relief Navigator
///
/// Plain-language guide and milestone tracker for statutory financial relief
/// provided under the Scheduled Castes and Scheduled Tribes (Prevention of Atrocities)
/// Amendment Rules.
class CompensationPage extends StatefulWidget {
  const CompensationPage({super.key});

  @override
  State<CompensationPage> createState() => _CompensationPageState();
}

class _CompensationPageState extends State<CompensationPage> {
  static const _docKey = 'relief_doc_checklist_v1';
  static const _stageKey = 'relief_stage_status_v1';

  late Set<String> _docs;
  late Set<String> _stages;

  static const _docList = [
    'Copy of FIR (First Information Report)',
    'Valid SC or ST Community Certificate',
    'Bank Passbook / Cancelled Cheque (Aadhaar Linked)',
    'Government Photo ID (Aadhaar Card / Voter ID)',
    'Medical Report / Medico-Legal Injury Certificate (if applicable)',
    'Copy of Charge Sheet (filed by police for Stage 2)',
  ];

  @override
  void initState() {
    super.initState();
    _docs = LocalStore.instance.getStringList(_docKey).toSet();
    _stages = LocalStore.instance.getStringList(_stageKey).toSet();
  }

  Future<void> _toggleDoc(String item) async {
    setState(() {
      if (_docs.contains(item)) {
        _docs.remove(item);
      } else {
        _docs.add(item);
      }
    });
    await LocalStore.instance.setStringList(_docKey, _docs.toList());
  }

  Future<void> _toggleStage(String stageId) async {
    setState(() {
      if (_stages.contains(stageId)) {
        _stages.remove(stageId);
      } else {
        _stages.add(stageId);
      }
    });
    await LocalStore.instance.setStringList(_stageKey, _stages.toList());
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Compensation & Relief Guide'),
        actions: const [GetHelpButton()],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 36),
        children: [
          // ── Header Banner ─────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: isDark ? MoolPalette.sandrose.withValues(alpha: 0.25) : MoolPalette.sandroseSoft,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: MoolPalette.sandrose.withValues(alpha: 0.35),
                width: 1.2,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: MoolPalette.sandrose,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.account_balance_wallet_rounded, color: Colors.white, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Statutory Relief Rights',
                        style: GoogleFonts.inter(
                          fontSize: 16.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.2,
                          color: isDark ? scheme.onSurface : MoolPalette.ink,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Victims of atrocities are legally entitled to mandatory financial compensation from the Government under the SC/ST (PoA) Rules.',
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

          const SizedBox(height: 24),

          // ── Section 1: Three Stage Milestone Tracker ──────────────
          const _HeaderRow(
            icon: Icons.payments_rounded,
            title: '3-Stage Relief Disbursement Schedule',
            color: MoolPalette.sandrose,
          ),
          const SizedBox(height: 12),

          _MilestoneCard(
            stageNumber: 'Stage 1',
            percentage: '25% of Relief',
            title: 'Upon Registration of FIR',
            description:
                'Mandated to be disbursed within 7 days of FIR registration and medical examination by the District Magistrate.',
            isReceived: _stages.contains('stage_1'),
            onToggle: () => _toggleStage('stage_1'),
          ),
          const SizedBox(height: 10),

          _MilestoneCard(
            stageNumber: 'Stage 2',
            percentage: '50% of Relief',
            title: 'Upon Filing of Charge Sheet',
            description:
                'Disbursed when police complete investigation and submit the Charge Sheet (Challan) to the Special Court.',
            isReceived: _stages.contains('stage_2'),
            onToggle: () => _toggleStage('stage_2'),
          ),
          const SizedBox(height: 10),

          _MilestoneCard(
            stageNumber: 'Stage 3',
            percentage: '25% of Relief',
            title: 'Upon Conclusion of Trial',
            description:
                'Disbursed at the conclusion of trial in the Special Court, regardless of conviction or acquittal.',
            isReceived: _stages.contains('stage_3'),
            onToggle: () => _toggleStage('stage_3'),
          ),

          const SizedBox(height: 24),

          // ── Section 2: Document Checklist ─────────────────────────
          const _HeaderRow(
            icon: Icons.folder_shared_rounded,
            title: 'Required Claim Documents',
            color: MoolPalette.dusk,
          ),
          const SizedBox(height: 10),

          SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Documents needed by the District Social Welfare Department (DSWO):',
                  style: GoogleFonts.inter(fontSize: 12, color: scheme.onSurfaceVariant),
                ),
                const SizedBox(height: 12),
                for (final item in _docList)
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    activeColor: MoolPalette.sandrose,
                    title: Text(
                      item,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        decoration: _docs.contains(item) ? TextDecoration.lineThrough : null,
                        color: _docs.contains(item)
                            ? scheme.onSurfaceVariant.withValues(alpha: 0.6)
                            : scheme.onSurface,
                      ),
                    ),
                    value: _docs.contains(item),
                    onChanged: (_) => _toggleDoc(item),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // ── Section 3: How to Claim ───────────────────────────────
          const _HeaderRow(
            icon: Icons.info_outline_rounded,
            title: 'How Relief is Processed',
            color: MoolPalette.moss,
          ),
          const SizedBox(height: 10),

          const SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ProcessStep(
                  step: '1',
                  title: 'Police Intimation',
                  desc: 'The Investigating Officer (DSP rank) sends FIR copy to the District Magistrate & District Social Welfare Officer.',
                ),
                Divider(height: 20),
                _ProcessStep(
                  step: '2',
                  title: 'Direct Bank Transfer',
                  desc: 'Funds are transferred directly via DBT to your linked bank account. No intermediaries or cash payments are permitted.',
                ),
                Divider(height: 20),
                _ProcessStep(
                  step: '3',
                  title: 'Escalation if Delayed',
                  desc: 'If relief is delayed beyond 7 days, file a representation with the District Collector or call National Helpline 14566.',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderRow extends StatelessWidget {
  const _HeaderRow({
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

class _MilestoneCard extends StatelessWidget {
  const _MilestoneCard({
    required this.stageNumber,
    required this.percentage,
    required this.title,
    required this.description,
    required this.isReceived,
    required this.onToggle,
  });

  final String stageNumber;
  final String percentage;
  final String title;
  final String description;
  final bool isReceived;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: isReceived
              ? MoolPalette.moss
              : (isDark ? scheme.outlineVariant.withValues(alpha: 0.3) : MoolPalette.mist),
          width: isReceived ? 1.5 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: MoolPalette.sandrose.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        stageNumber,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: MoolPalette.sandrose,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      percentage,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                TextButton.icon(
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    foregroundColor: isReceived ? MoolPalette.moss : scheme.onSurfaceVariant,
                  ),
                  icon: Icon(
                    isReceived ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
                    size: 16,
                  ),
                  label: Text(
                    isReceived ? 'Received' : 'Mark Received',
                    style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.bold),
                  ),
                  onPressed: onToggle,
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              title,
              style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: scheme.onSurface),
            ),
            const SizedBox(height: 4),
            Text(
              description,
              style: GoogleFonts.inter(fontSize: 12, height: 1.4, color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProcessStep extends StatelessWidget {
  const _ProcessStep({
    required this.step,
    required this.title,
    required this.desc,
  });

  final String step;
  final String title;
  final String desc;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 12,
          backgroundColor: MoolPalette.mossSoft,
          child: Text(
            step,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: MoolPalette.mossDark),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold)),
              const SizedBox(height: 2),
              Text(desc, style: GoogleFonts.inter(fontSize: 11.5, height: 1.35, color: scheme.onSurfaceVariant)),
            ],
          ),
        ),
      ],
    );
  }
}
