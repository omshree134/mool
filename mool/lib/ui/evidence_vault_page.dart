import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../app/theme.dart';
import '../core/local_store.dart';
import 'widgets/common.dart';

/// Secure Evidence & Incident Vault
///
/// Enables atrocity victims to securely record, log, and organize threats,
/// stalking encounters, and witness intimidation attempts.
class EvidenceVaultPage extends StatefulWidget {
  const EvidenceVaultPage({super.key});

  @override
  State<EvidenceVaultPage> createState() => _EvidenceVaultPageState();
}

class _EvidenceVaultPageState extends State<EvidenceVaultPage> {
  static const _vaultKey = 'evidence_vault_entries_v1';
  late List<_EvidenceEntry> _entries;

  final _descController = TextEditingController();
  final _whoController = TextEditingController();
  String _selectedType = 'Verbal Threat / Intimidation';

  @override
  void initState() {
    super.initState();
    _loadEntries();
  }

  @override
  void dispose() {
    _descController.dispose();
    _whoController.dispose();
    super.dispose();
  }

  void _loadEntries() {
    final raw = LocalStore.instance.getStringList(_vaultKey);
    _entries = raw.map((e) {
      final map = jsonDecode(e) as Map<String, dynamic>;
      return _EvidenceEntry.fromMap(map);
    }).toList();
  }

  Future<void> _saveEntries() async {
    final list = _entries.map((e) => jsonEncode(e.toMap())).toList();
    await LocalStore.instance.setStringList(_vaultKey, list);
  }

  Future<void> _addEntry() async {
    final who = _whoController.text.trim();
    final desc = _descController.text.trim();
    if (desc.isEmpty) return;

    final entry = _EvidenceEntry(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: _selectedType,
      who: who.isEmpty ? 'Unknown / Accused associate' : who,
      description: desc,
      timestamp: DateTime.now(),
    );

    setState(() {
      _entries.insert(0, entry);
      _descController.clear();
      _whoController.clear();
    });
    await _saveEntries();
    if (mounted) {
      Navigator.pop(context);
      showQuietSnack(context, 'Evidence logged safely in on-device vault.');
    }
  }

  void _showAddDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Log Threat or Incident', style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w700, letterSpacing: -0.2)),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                ],
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _selectedType,
                decoration: const InputDecoration(labelText: 'Incident Type', border: OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(value: 'Verbal Threat / Intimidation', child: Text('Verbal Threat / Intimidation')),
                  DropdownMenuItem(value: 'Being Followed / Stalked', child: Text('Being Followed / Stalked')),
                  DropdownMenuItem(value: 'Witness Tampering Pressure', child: Text('Witness Tampering Pressure')),
                  DropdownMenuItem(value: 'Social Boycott / Denial of Access', child: Text('Social Boycott / Denial')),
                  DropdownMenuItem(value: 'Property Damage / Trespass', child: Text('Property Damage / Trespass')),
                ],
                onChanged: (v) => setModalState(() => _selectedType = v ?? _selectedType),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _whoController,
                decoration: const InputDecoration(
                  labelText: 'Who was involved? (Names, descriptions, vehicle numbers)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _descController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'What happened? (Date, time, exact words spoken)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: MoolPalette.signal,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.lock_rounded, size: 18),
                  label: const Text('Save to Secure Vault', style: TextStyle(fontWeight: FontWeight.bold)),
                  onPressed: _addEntry,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Evidence & Incident Vault'),
        actions: const [GetHelpButton()],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: MoolPalette.signal,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_moderator_rounded),
        label: const Text('Log Incident'),
        onPressed: _showAddDialog,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 90),
        children: [
          // ── Header Banner ─────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: isDark ? MoolPalette.signal.withValues(alpha: 0.22) : MoolPalette.signalSoft,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: MoolPalette.signal.withValues(alpha: 0.35), width: 1.2),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: MoolPalette.signal,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.security_rounded, color: Colors.white, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Secure Intimidation Log',
                        style: GoogleFonts.inter(
                          fontSize: 16.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.2,
                          color: isDark ? scheme.onSurface : MoolPalette.signal,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Record timestamps, names, and words used during threats or intimidation. Entries are stored on your device to share with your legal team.',
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

          // ── Entries List ──────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Logged Evidence (${_entries.length})',
                style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              if (_entries.isNotEmpty)
                TextButton.icon(
                  icon: const Icon(Icons.copy_rounded, size: 16),
                  label: const Text('Copy Summary'),
                  onPressed: () {
                    final summary = _entries.map((e) => e.toFormattedString()).join('\n\n---\n\n');
                    Clipboard.setData(ClipboardData(text: summary));
                    showQuietSnack(context, 'Evidence log copied to clipboard.');
                  },
                ),
            ],
          ),
          const SizedBox(height: 10),

          if (_entries.isEmpty) ...[
            SectionCard(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Column(
                    children: [
                      Icon(Icons.verified_user_outlined, size: 44, color: scheme.onSurfaceVariant.withValues(alpha: 0.5)),
                      const SizedBox(height: 12),
                      Text('No incidents logged yet', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14)),
                      const SizedBox(height: 4),
                      Text(
                        'If anyone threatens, intimidates, or follows you, tap "Log Incident" below to record it immediately.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(fontSize: 12, color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ] else ...[
            for (final entry in _entries) ...[
              Card(
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
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: MoolPalette.signal.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              entry.type,
                              style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: MoolPalette.signal),
                            ),
                          ),
                          Text(
                            entry.formattedDate,
                            style: GoogleFonts.inter(fontSize: 11, color: scheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text('Involved: ${entry.who}', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      Text(entry.description, style: GoogleFonts.inter(fontSize: 12.5, height: 1.4)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ],

          const SizedBox(height: 20),

          // Legal note on evidence
          SectionCard(
            tint: isDark ? scheme.surfaceContainerHighest : const Color(0xFFF9F7F2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline_rounded, size: 18, color: MoolPalette.dusk),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Under Section 15A of the SC/ST Act, witness intimidation or coercion is a cognizable and non-bailable offence punishable with mandatory imprisonment.',
                    style: GoogleFonts.inter(fontSize: 11.5, height: 1.4, color: scheme.onSurfaceVariant),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EvidenceEntry {
  _EvidenceEntry({
    required this.id,
    required this.type,
    required this.who,
    required this.description,
    required this.timestamp,
  });

  final String id;
  final String type;
  final String who;
  final String description;
  final DateTime timestamp;

  String get formattedDate =>
      '${timestamp.day}/${timestamp.month}/${timestamp.year} at ${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';

  String toFormattedString() =>
      'Incident Type: $type\nDate & Time: $formattedDate\nInvolved: $who\nDetails: $description';

  Map<String, dynamic> toMap() => {
        'id': id,
        'type': type,
        'who': who,
        'description': description,
        'timestamp': timestamp.toIso8601String(),
      };

  factory _EvidenceEntry.fromMap(Map<String, dynamic> m) => _EvidenceEntry(
        id: m['id'] as String,
        type: m['type'] as String,
        who: m['who'] as String,
        description: m['description'] as String,
        timestamp: DateTime.parse(m['timestamp'] as String),
      );
}
