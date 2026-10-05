import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/settings.dart';
import '../services/member_profile.dart';
import '../services/repository.dart';
import '../services/safety/sos_service.dart';
import '../services/safety/trusted_contacts.dart';
import 'contacts_page.dart';
import 'grounding_page.dart';
import 'link_page.dart';
import 'report_page.dart';
import 'safety_plan_page.dart';
import 'sos_pages.dart';
import 'widgets/common.dart';

Future<void> dial(String number) => launchUrl(Uri(scheme: 'tel', path: number));

const helplines = [
  ('Emergency', '112'),
  ('Tele-MANAS: mental health support, free, day and night', '14416'),
  ('National Helpline Against Atrocities', '14566'),
  ('Free legal aid (NALSA)', '15100'),
];

class HelpPage extends StatelessWidget {
  const HelpPage({super.key});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Get help')),
      body: ListenableBuilder(
        listenable: Listenable.merge([SosService.instance, TrustedContacts.instance]),
        builder: (context, _) {
          final contacts = TrustedContacts.instance.all;
          final call112 = Settings.instance.call112OnSos;
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
              Text("If you're in danger", style: t.titleLarge),
              const SizedBox(height: 6),
              Text(
                contacts.isEmpty
                    ? (call112 ? 'Mool will call 112.' : 'Add trusted people so Mool can message them.')
                    : 'Mool will message your trusted people with your location'
                        '${call112 ? ' and call 112' : ''}. You get 5 seconds to cancel.',
                style: t.bodyMedium,
              ),
              const SizedBox(height: 16),
              if (SosService.instance.active)
                FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SosActivePage())),
                  child: const Text('Emergency help is active. See status'),
                )
              else
                HoldToConfirm(
                  label: "I'm in danger",
                  onConfirmed: () => Navigator.of(context).push(MaterialPageRoute(
                    fullscreenDialog: true,
                    builder: (_) => const SosCountdownPage(reason: 'Help button', seconds: 5),
                  )),
                ),
              if (contacts.isEmpty) ...[
                const SizedBox(height: 8),
                TextButton.icon(
                  icon: const Icon(Icons.person_add_alt),
                  label: const Text('Add people I trust'),
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ContactsPage())),
                ),
              ],
              const SizedBox(height: 28),
              ToolTile(
                icon: Icons.favorite_border,
                title: "I'm not okay",
                subtitle: 'Calm down, talk to someone, or ask your counsellor to call',
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SupportPage())),
              ),
              ToolTile(
                icon: Icons.edit_note,
                title: 'Report something that happened',
                subtitle: 'Threats, pressure, being followed',
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ReportPage())),
              ),
              const SizedBox(height: 16),
              Text('Helplines', style: t.titleMedium),
              const SizedBox(height: 8),
              Card(
                child: Column(
                  children: [
                    for (final (name, number) in helplines)
                      ListTile(
                        title: Text(name),
                        subtitle: Text(number),
                        trailing: const Icon(Icons.call_outlined),
                        onTap: () => dial(number),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              TextButton.icon(
                icon: const Icon(Icons.exit_to_app),
                label: const Text('Close Mool quickly'),
                onPressed: () => SystemNavigator.pop(),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// "I'm not okay". Never an alarm; a menu of things that help.
class SupportPage extends StatelessWidget {
  const SupportPage({super.key, this.afterCrisisAnswer = false});
  final bool afterCrisisAnswer;

  Future<void> _callSomeone(BuildContext context) async {
    final contacts = TrustedContacts.instance.all;
    if (contacts.isEmpty) {
      await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ContactsPage()));
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final c in contacts)
              ListTile(
                leading: const Icon(Icons.call_outlined),
                title: Text(c.name),
                subtitle: Text(c.phone),
                onTap: () {
                  Navigator.pop(ctx);
                  dial(c.phone);
                },
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final linked = MemberProfile.instance.linked;
    return Scaffold(
      appBar: AppBar(title: const Text("When you're not okay")),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          if (afterCrisisAnswer)
            SectionCard(
              tint: scheme.secondaryContainer,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Thank you for telling us', style: t.titleLarge),
                  const SizedBox(height: 8),
                  Text(
                    'That took courage. Your counsellor will be told so they can reach out to you. '
                    'If you might act on these thoughts, please call Tele-MANAS on 14416 now, '
                    'or 112 if you are in immediate danger.',
                    style: t.bodyLarge,
                  ),
                  const SizedBox(height: 14),
                  FilledButton.icon(
                    icon: const Icon(Icons.call),
                    label: const Text('Call Tele-MANAS (14416)'),
                    onPressed: () => dial('14416'),
                  ),
                ],
              ),
            )
          else ...[
            Text("You don't have to carry this alone.", style: t.headlineSmall),
            const SizedBox(height: 8),
            Text('Choose whatever feels right now.', style: t.bodyLarge),
          ],
          const SizedBox(height: 20),
          ToolTile(
            icon: Icons.air,
            title: 'Breathe with me',
            subtitle: 'A few minutes to slow things down',
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const GroundingPage())),
          ),
          ToolTile(
            icon: Icons.shield_outlined,
            title: 'My safety plan',
            subtitle: 'The steps you wrote down for hard moments',
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SafetyPlanPage())),
          ),
          ToolTile(
            icon: Icons.phone_callback_outlined,
            title: 'Ask my counsellor to call me',
            subtitle: linked ? 'They will get a request to call you' : 'Connect with your counsellor first',
            onTap: () {
              if (!linked) {
                Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LinkPage()));
                return;
              }
              Repo.instance.requestCallback(reason: afterCrisisAnswer ? 'crisis-support' : 'not-okay');
              showQuietSnack(context, 'Your counsellor has been asked to call you.');
            },
          ),
          ToolTile(
            icon: Icons.support_agent,
            title: 'Talk to someone now',
            subtitle: 'Tele-MANAS 14416, free and confidential',
            onTap: () => dial('14416'),
          ),
          ToolTile(
            icon: Icons.people_outline,
            title: 'Call someone I trust',
            subtitle: 'From your trusted people',
            onTap: () => _callSomeone(context),
          ),
        ],
      ),
    );
  }
}
