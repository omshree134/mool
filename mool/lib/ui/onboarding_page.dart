import 'package:flutter/material.dart';

import '../core/local_store.dart';
import '../core/permissions.dart';
import '../core/settings.dart';
import '../services/repository.dart';
import 'contacts_page.dart';
import 'link_page.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final _pages = PageController();
  final _name = TextEditingController();
  int _step = 0;
  bool _activity = false;
  bool _followWatch = false;
  bool _audio = false;
  bool _busy = false;

  static const _stepCount = 5;

  @override
  void dispose() {
    _pages.dispose();
    _name.dispose();
    super.dispose();
  }

  void _next() {
    FocusScope.of(context).unfocus();
    if (_step < _stepCount - 1) {
      setState(() => _step++);
      _pages.animateToPage(_step, duration: const Duration(milliseconds: 280), curve: Curves.easeOut);
    }
  }

  void _back() {
    if (_step == 0) return;
    setState(() => _step--);
    _pages.animateToPage(_step, duration: const Duration(milliseconds: 280), curve: Curves.easeOut);
  }

  Future<void> _saveChoices() async {
    setState(() => _busy = true);
    // Ask for permissions only for what the person turned on.
    if (_activity) _activity = await Perms.requestAll(Perms.passiveSensing);
    if (_followWatch) _followWatch = await Perms.requestAll(Perms.followWatch);
    if (_audio) _audio = await Perms.requestAll(Perms.audio);
    final s = LocalStore.instance;
    await s.setBool(SettingKeys.passiveSensing, _activity);
    await s.setBool(SettingKeys.followWatch, _followWatch);
    await s.setBool(SettingKeys.recordAudioOnSos, _audio);
    if (!mounted) return;
    setState(() => _busy = false);
    _next();
  }

  Future<void> _finish() async {
    final s = Settings.instance;
    await LocalStore.instance.setString(SettingKeys.name, _name.text.trim());
    if (s.memberSince == null) {
      await LocalStore.instance.setString(SettingKeys.memberSince, DateTime.now().toIso8601String());
    }
    await Repo.instance.upsertProfile();
    await s.setBool(SettingKeys.onboarded, true); // notifies the gate
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: _step == 0 ? null : IconButton(icon: const Icon(Icons.arrow_back), onPressed: _back, tooltip: 'Back'),
        title: Semantics(
          label: 'Step ${_step + 1} of $_stepCount',
          child: ExcludeSemantics(
            child: LinearProgressIndicator(
              value: (_step + 1) / _stepCount,
              minHeight: 4,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: PageView(
          controller: _pages,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _welcome(context),
            _nameStep(context),
            _sharingStep(context),
            _choicesStep(context),
            _supportStep(context),
          ],
        ),
      ),
    );
  }

  Widget _frame(BuildContext context, {required String title, String? body, required List<Widget> children}) {
    final t = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      children: [
        Text(title, style: t.headlineSmall),
        if (body != null) ...[const SizedBox(height: 10), Text(body, style: t.bodyLarge)],
        const SizedBox(height: 24),
        ...children,
      ],
    );
  }

  Widget _welcome(BuildContext context) => _frame(
        context,
        title: 'Welcome to Mool',
        body: 'Mool is a quiet place to notice how you are, day by day. If things get hard, '
            'it helps the people supporting you know when to reach out.\n\n'
            'You decide what Mool can see, and you can change your mind at any time.',
        children: [FilledButton(onPressed: _next, child: const Text('Begin'))],
      );

  Widget _nameStep(BuildContext context) => _frame(
        context,
        title: 'What would you like to be called?',
        body: 'A nickname is fine.',
        children: [
          TextField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Your name'),
            onSubmitted: (_) => _next(),
          ),
          const SizedBox(height: 16),
          FilledButton(onPressed: _next, child: const Text('Continue')),
        ],
      );

  Widget _sharingStep(BuildContext context) {
    final t = Theme.of(context).textTheme;
    Widget line(IconData icon, String text) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(icon, size: 22, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(child: Text(text, style: t.bodyLarge)),
          ]),
        );
    return _frame(
      context,
      title: 'What your counsellor sees',
      body: 'Once you connect with your counsellor, they can see:',
      children: [
        line(Icons.check, 'Your daily check-in answers, and notes you choose to share'),
        line(Icons.check, 'Longer questionnaires you fill in'),
        line(Icons.check, 'A summary of how things seem to be going, so they know when to call'),
        line(Icons.check, 'When you ask for help'),
        const SizedBox(height: 8),
        Text('They never see', style: t.titleMedium),
        const SizedBox(height: 12),
        line(Icons.block, 'Notes you keep private'),
        line(Icons.block, 'Where you go'),
        line(Icons.block, 'Your contacts, messages or photos'),
        const SizedBox(height: 8),
        Text(
          'If you tell Mool you are thinking about ending your life, your counsellor is always told, '
          'so they can reach you.',
          style: t.bodyMedium,
        ),
        const SizedBox(height: 24),
        FilledButton(onPressed: _next, child: const Text('I understand')),
      ],
    );
  }

  Widget _choicesStep(BuildContext context) => _frame(
        context,
        title: 'Choose what Mool can do',
        body: 'All of these are off unless you turn them on. You can change them later in Me.',
        children: [
          _Choice(
            title: 'Notice my daily activity',
            body: 'Counts steps and time spent outside your home, on your phone. Only daily totals are shared, '
                'never where you went. Shows a small "Running quietly" notification.',
            value: _activity,
            onChanged: (v) => setState(() => _activity = v),
          ),
          _Choice(
            title: 'Watch for devices following me',
            body: 'Looks for a Bluetooth device, like a tracker tag, that keeps appearing wherever you go. '
                'It asks you first; it never raises an alarm on its own.',
            value: _followWatch,
            onChanged: (v) => setState(() => _followWatch = v),
          ),
          _Choice(
            title: 'Record audio in an emergency',
            body: 'When you press "I\'m in danger", Mool records sound as evidence. Recordings are sealed so '
                'they can be shown to be unaltered.',
            value: _audio,
            onChanged: (v) => setState(() => _audio = v),
          ),
          const SizedBox(height: 16),
          FilledButton(onPressed: _busy ? null : _saveChoices, child: const Text('Continue')),
        ],
      );

  Widget _supportStep(BuildContext context) => _frame(
        context,
        title: 'Your support',
        body: 'Two things you can set up now, or later from Me.',
        children: [
          OutlinedButton.icon(
            icon: const Icon(Icons.people_outline),
            label: const Text('Add people I trust'),
            onPressed: () async {
              await Perms.requestAll(Perms.emergency);
              if (!context.mounted) return;
              await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ContactsPage()));
            },
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            icon: const Icon(Icons.qr_code_scanner),
            label: const Text('Connect with my counsellor'),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LinkPage())),
          ),
          const SizedBox(height: 24),
          FilledButton(onPressed: _finish, child: const Text('Done')),
        ],
      );
}

class _Choice extends StatelessWidget {
  const _Choice({required this.title, required this.body, required this.value, required this.onChanged});
  final String title;
  final String body;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        child: SwitchListTile(
          contentPadding: const EdgeInsets.fromLTRB(20, 8, 12, 8),
          title: Text(title, style: Theme.of(context).textTheme.titleMedium),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(body, style: Theme.of(context).textTheme.bodySmall),
          ),
          value: value,
          onChanged: onChanged,
        ),
      ),
    );
  }
}
