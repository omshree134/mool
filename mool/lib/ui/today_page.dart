import 'dart:async';

import 'package:flutter/material.dart';
import '../app/theme.dart';
import '../core/dates.dart';
import '../core/settings.dart';
import '../models/checkin.dart';
import '../models/screener.dart';
import '../services/daily_pipeline.dart';
import '../services/member_profile.dart';
import '../services/repository.dart';
import '../services/safety/intimidation_watch.dart';
import '../services/safety/sos_service.dart';
import 'checkin_page.dart';
import 'ivrs_simulator_page.dart';
import 'link_page.dart';
import 'report_page.dart';
import 'screener_page.dart';
import 'sos_pages.dart';
import 'widgets/common.dart';
import 'widgets/mood_journey.dart';
import 'widgets/ai_insights_card.dart';

class TodayPage extends StatelessWidget {
  const TodayPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        Repo.instance,
        MemberProfile.instance,
        IntimidationWatch.instance,
        Settings.instance,
        SosService.instance,
      ]),
      builder: (context, _) {
        final t = Theme.of(context).textTheme;
        final now = DateTime.now();
        final name = Settings.instance.displayName.trim();
        final profile = MemberProfile.instance;
        final due = Repo.instance.dueScreener();
        final hearing = profile.nextHearing;
        final showCase = Settings.instance.showCaseUpdates &&
            ((hearing != null && calendarDaysBetween(now, hearing) >= 0) ||
                profile.caseStage != null ||
                profile.caseUpdates.isNotEmpty);

        return Scaffold(
          appBar: AppBar(title: const Text('Today'), actions: const [GetHelpButton()]),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
            children: [
              Text(name.isEmpty ? greetingFor(now) : '${greetingFor(now)}, $name', style: t.headlineMedium),
              if (Settings.instance.hasGuardian) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.shield_rounded, size: 14, color: MoolPalette.moss),
                    const SizedBox(width: 6),
                    Text(
                      'Linked with ${Settings.instance.guardianName}',
                      style: t.bodySmall?.copyWith(color: MoolPalette.moss, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 18),
              if (SosService.instance.active) ...[const _SosBanner(), const SizedBox(height: 16)],
              for (final a in IntimidationWatch.instance.alerts) ...[_FollowAlert(device: a), const SizedBox(height: 16)],
              _CheckInCard(today: Repo.instance.todaysCheckIn()),
              if (due != null) ...[const SizedBox(height: 16), _ScreenerCard(def: due)],
              if (showCase) ...[const SizedBox(height: 16), const _CaseCard()],
              if (!profile.linked) ...[
                const SizedBox(height: 16),
                ToolTile(
                  icon: Icons.handshake_outlined,
                  title: 'Connect with your counsellor',
                  subtitle: 'Use the code they gave you',
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LinkPage())),
                ),
              ],
              const SizedBox(height: 16),
              SectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Your mood, last two weeks', style: t.titleMedium),
                    const SizedBox(height: 12),
                    MoodJourney(checkIns: Repo.instance.localCheckIns()),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // AI Explainable Insights Card
              Builder(
                builder: (context) {
                  final history = Repo.instance.localDailyResults();
                  return AiInsightsCard(result: history.isEmpty ? null : history.values.last);
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }
}

class _CheckInCard extends StatelessWidget {
  const _CheckInCard({required this.today});
  final CheckIn? today;

  void _open(BuildContext context) =>
      Navigator.of(context).push(MaterialPageRoute(fullscreenDialog: true, builder: (_) => const CheckInPage()));

  Future<void> _notToday(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    await Repo.instance.saveCheckIn(CheckIn.skipped(Repo.instance.newId(), DateTime.now()));
    unawaited(DailyPipeline.instance.run());
    messenger.showSnackBar(const SnackBar(content: Text("That's fine. See you tomorrow.")));
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final c = today;

    if (c == null) {
      return SectionCard(
        tint: scheme.secondaryContainer,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('How are you feeling today?', style: t.titleLarge),
            const SizedBox(height: 6),
            Text('Check in privately with 4 short questions, or call our toll-free voice careline.', style: t.bodyMedium),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: () => _open(context),
                    child: const Text('Daily Check-in'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: MoolPalette.dusk.withValues(alpha: 0.4)),
                    ),
                    icon: const Icon(Icons.phone_in_talk_rounded, size: 16),
                    label: const Text('Voice Check-in'),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const IvrsSimulatorPage()),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(onPressed: () => _notToday(context), child: const Text('Skip for today')),
            ),
          ],
        ),
      );
    }

    return SectionCard(
      child: Row(
        children: [
          Icon(c.skipped ? Icons.nightlight_outlined : Icons.check_circle_outline, color: scheme.primary, size: 30),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(c.skipped ? 'Taking today off is okay.' : 'Thank you for checking in today.', style: t.titleMedium),
                const SizedBox(height: 2),
                Text('If something changes, you can check in again.', style: t.bodySmall),
              ],
            ),
          ),
          TextButton(onPressed: () => _open(context), child: const Text('Again')),
        ],
      ),
    );
  }
}

class _ScreenerCard extends StatelessWidget {
  const _ScreenerCard({required this.def});
  final ScreenerDefinition def;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(def.friendlyTitle, style: t.titleMedium),
          const SizedBox(height: 4),
          Text('A few longer questions, about ${def.items.length < 6 ? 2 : 3} minutes.', style: t.bodySmall),
          const SizedBox(height: 14),
          Row(
            children: [
              FilledButton.tonal(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(fullscreenDialog: true, builder: (_) => ScreenerPage(definition: def)),
                ),
                child: const Text('Start'),
              ),
              const SizedBox(width: 12),
              TextButton(onPressed: Repo.instance.snoozeScreener, child: const Text('Later')),
            ],
          ),
        ],
      ),
    );
  }
}

class _CaseCard extends StatelessWidget {
  const _CaseCard();

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final p = MemberProfile.instance;
    final hearing = p.nextHearing;
    final days = hearing == null ? null : calendarDaysBetween(DateTime.now(), hearing);
    final latest = p.caseUpdates.isEmpty ? null : p.caseUpdates.last;
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Your case', style: t.titleMedium),
          const SizedBox(height: 8),
          if (hearing != null && days != null && days >= 0)
            Text(
              'Next court date: ${friendlyDate(hearing)} '
              '(${days == 0 ? 'today' : days == 1 ? 'tomorrow' : 'in $days days'})',
              style: t.bodyLarge,
            ),
          if (p.caseStage != null) Text('Stage: ${p.caseStage}', style: t.bodyMedium),
          if (latest != null) ...[
            const SizedBox(height: 8),
            Text(latest.text, style: t.bodyMedium),
          ],
          if (days != null && days >= 0 && days <= 7) ...[
            const SizedBox(height: 8),
            Text('Court days can feel heavy. Your counsellor can help you prepare.', style: t.bodySmall),
          ],
        ],
      ),
    );
  }
}

class _SosBanner extends StatelessWidget {
  const _SosBanner();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SectionCard(
      tint: scheme.errorContainer,
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SosActivePage())),
      child: Row(
        children: [
          Icon(Icons.emergency_outlined, color: scheme.onErrorContainer),
          const SizedBox(width: 12),
          Expanded(
            child: Text('Emergency help is active. Tap to see what has been sent.',
                style: TextStyle(color: scheme.onErrorContainer, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

class _FollowAlert extends StatelessWidget {
  const _FollowAlert({required this.device});
  final SuspiciousDevice device;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('A device keeps turning up near you', style: t.titleMedium),
          const SizedBox(height: 6),
          Text(
            'A Bluetooth device has been near you in ${device.places} different places over the last '
            '${device.minutes} minutes.${device.tracker ? ' It looks like a tracker tag.' : ''} '
            'It may belong to someone you know. If you feel unsafe right now, use Get help.',
            style: t.bodyMedium,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              FilledButton.tonal(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => ReportPage(
                    prefill: 'A Bluetooth device${device.tracker ? ' (possibly a tracker tag)' : ''} '
                        'followed me to ${device.places} places over ${device.minutes} minutes.',
                  ),
                )),
                child: const Text('Report this'),
              ),
              TextButton(
                onPressed: () => IntimidationWatch.instance.markAsKnown(device.id),
                child: const Text("It's mine or someone I know"),
              ),
              TextButton(onPressed: () => IntimidationWatch.instance.dismiss(device.id), child: const Text('Dismiss')),
            ],
          ),
        ],
      ),
    );
  }
}
