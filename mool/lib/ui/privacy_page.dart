import 'package:flutter/material.dart';

import '../core/settings.dart';
import '../services/repository.dart';

class PrivacyPage extends StatelessWidget {
  const PrivacyPage({super.key});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    Widget line(IconData icon, String text) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(icon, size: 20, color: scheme.primary),
            const SizedBox(width: 12),
            Expanded(child: Text(text, style: t.bodyMedium)),
          ]),
        );

    return Scaffold(
      appBar: AppBar(title: const Text('Privacy and sharing')),
      body: ListenableBuilder(
        listenable: Settings.instance,
        builder: (context, _) {
          final s = Settings.instance;
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
              Text('Your counsellor can see', style: t.titleMedium),
              const SizedBox(height: 10),
              line(Icons.check, 'Your check-in answers'),
              line(Icons.check, 'Notes you choose to share'),
              line(Icons.check, 'Longer questionnaires'),
              line(Icons.check,
                  'A summary of how things seem to be going, worked out on your phone from the above'
                  '${s.passiveSensing ? ' and your daily step and time-outside totals' : ''}'),
              line(Icons.check, 'Reports you make, and when you use the emergency button'),
              if (s.shareLocationOnSos) line(Icons.check, 'Your location, only during an emergency'),
              const SizedBox(height: 12),
              Text('Your counsellor never sees', style: t.titleMedium),
              const SizedBox(height: 10),
              line(Icons.block, 'Notes you keep private. Only a general "tone" is used from them.'),
              line(Icons.block, 'Where you go day to day, or where your home is'),
              line(Icons.block, 'Your contacts, messages, photos or other apps'),
              line(Icons.block, 'Any sound from your phone, except recordings you choose to make'),
              const SizedBox(height: 12),
              Text('Always shared for your safety', style: t.titleMedium),
              const SizedBox(height: 10),
              line(Icons.info_outline,
                  'If you tell Mool you are thinking about ending your life, your counsellor is told so they can reach you.'),
              const Divider(height: 32),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Share my check-in notes by default'),
                subtitle: Text('You can still change this for each note.', style: t.bodySmall),
                value: s.shareNotesByDefault,
                onChanged: (v) async {
                  await s.setBool(SettingKeys.shareNotes, v);
                  await Repo.instance.upsertProfile();
                },
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Show updates about my case'),
                subtitle: Text('Court dates and news your counsellor adds.', style: t.bodySmall),
                value: s.showCaseUpdates,
                onChanged: (v) => s.setBool(SettingKeys.showCaseUpdates, v),
              ),
              const SizedBox(height: 16),
              Text(
                'To delete your account and everything stored about you, ask your counsellor. '
                'It will be removed from Mool\'s servers.',
                style: t.bodySmall,
              ),
            ],
          );
        },
      ),
    );
  }
}
