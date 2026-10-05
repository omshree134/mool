import 'dart:async';

import 'package:flutter/material.dart';

import '../core/settings.dart';
import '../models/checkin.dart';
import '../services/daily_pipeline.dart';
import '../services/repository.dart';
import '../services/text_signals.dart';
import 'help_page.dart';
import 'widgets/common.dart';

class _Question {
  const _Question(this.key, this.title, this.options);
  final String key;
  final String title;
  final List<(int, String, String?)> options; // value, label, emoji
}

const _questions = [
  _Question('mood', 'How is your mood today?', [
    (5, 'Very good', '😊'),
    (4, 'Good', '🙂'),
    (3, 'Okay', '😐'),
    (2, 'Low', '🙁'),
    (1, 'Very low', '😞'),
  ]),
  _Question('sleep', 'How did you sleep last night?', [
    (5, 'Very well', null),
    (4, 'Well', null),
    (3, 'Okay', null),
    (2, 'Badly', null),
    (1, 'Very badly', null),
  ]),
  _Question('safety', 'How safe do you feel today?', [
    (5, 'Very safe', null),
    (4, 'Safe', null),
    (3, 'Somewhat safe', null),
    (2, 'A bit unsafe', null),
    (1, 'Not safe at all', null),
  ]),
  _Question('coping', 'How much could you manage today?', [
    (5, 'Everything I wanted', null),
    (4, 'Most things', null),
    (3, 'Some things', null),
    (2, 'A little', null),
    (1, 'Almost nothing', null),
  ]),
];

enum _CrisisAnswer { yes, no, ratherNotSay }

class CheckInPage extends StatefulWidget {
  const CheckInPage({super.key});

  @override
  State<CheckInPage> createState() => _CheckInPageState();
}

class _CheckInPageState extends State<CheckInPage> {
  final _pages = PageController();
  final _note = TextEditingController();
  final Map<String, int?> _answers = {};
  late bool _shareNote = Settings.instance.shareNotesByDefault;
  int _index = 0;
  bool _saving = false;

  int get _total => _questions.length + 1;

  @override
  void dispose() {
    _pages.dispose();
    _note.dispose();
    super.dispose();
  }

  void _go(int i) {
    FocusScope.of(context).unfocus();
    setState(() => _index = i);
    _pages.animateToPage(i, duration: const Duration(milliseconds: 260), curve: Curves.easeOut);
  }

  void _answer(String key, int? value) {
    setState(() => _answers[key] = value);
    Future<void>.delayed(const Duration(milliseconds: 220), () {
      if (mounted && _index < _total - 1) _go(_index + 1);
    });
  }

  Future<_CrisisAnswer> _askDirectly() async {
    final result = await showDialog<_CrisisAnswer>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Thank you for sharing that'),
        content: const Text(
          'Something you wrote made us want to ask you directly, because we care how you are.\n\n'
          'Are you having thoughts of ending your life?',
        ),
        actionsAlignment: MainAxisAlignment.start,
        actionsOverflowDirection: VerticalDirection.down,
        actionsOverflowButtonSpacing: 4,
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, _CrisisAnswer.yes), child: const Text('Yes')),
          TextButton(onPressed: () => Navigator.pop(ctx, _CrisisAnswer.no), child: const Text('No')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, _CrisisAnswer.ratherNotSay),
            child: const Text("I'd rather not say"),
          ),
        ],
      ),
    );
    return result ?? _CrisisAnswer.ratherNotSay;
  }

  Future<void> _finish() async {
    if (_saving) return;
    setState(() => _saving = true);
    final note = _note.text.trim();

    var possible = false;
    _CrisisAnswer? crisis;
    if (note.isNotEmpty && TextSignals.mightExpressCrisis(note)) {
      possible = true;
      crisis = await _askDirectly();
    }

    final checkIn = CheckIn(
      id: Repo.instance.newId(),
      at: DateTime.now(),
      mood: _answers['mood'],
      sleep: _answers['sleep'],
      safety: _answers['safety'],
      coping: _answers['coping'],
      note: note.isEmpty ? null : note,
      noteShared: _shareNote,
      noteNegativity: note.isEmpty ? null : TextSignals.negativity(note),
      possibleCrisisLanguage: possible,
      crisisConfirmed: crisis == _CrisisAnswer.yes,
      crisisUnclear: crisis == _CrisisAnswer.ratherNotSay,
    );
    await Repo.instance.saveCheckIn(checkIn);
    unawaited(DailyPipeline.instance.run());
    if (!mounted) return;

    final nav = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    if (crisis == _CrisisAnswer.yes || crisis == _CrisisAnswer.ratherNotSay) {
      nav.pushReplacement(MaterialPageRoute(
        builder: (_) => SupportPage(afterCrisisAnswer: crisis == _CrisisAnswer.yes),
      ));
      return;
    }

    if (_answers['safety'] == 1) {
      final show = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text("You said you don't feel safe today"),
          content: const Text('Would you like to see ways to get help?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Not now')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Show me')),
          ],
        ),
      );
      if (show == true) {
        nav.pushReplacement(MaterialPageRoute(builder: (_) => const HelpPage()));
        return;
      }
    }

    nav.pop();
    messenger.showSnackBar(const SnackBar(content: Text("Thank you. That's today's check-in done.")));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.close), tooltip: 'Close', onPressed: () => Navigator.pop(context)),
        title: Semantics(
          label: 'Question ${_index + 1} of $_total',
          child: ExcludeSemantics(
            child: LinearProgressIndicator(
              value: (_index + 1) / _total,
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
            for (final q in _questions) _questionPage(context, q),
            _notePage(context),
          ],
        ),
      ),
    );
  }

  Widget _questionPage(BuildContext context, _Question q) {
    final t = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        Text(q.title, style: t.headlineSmall),
        const SizedBox(height: 24),
        for (final (value, label, emoji) in q.options)
          AnswerOption(
            label: label,
            leading: emoji,
            selected: _answers[q.key] == value,
            onTap: () => _answer(q.key, value),
          ),
        const SizedBox(height: 8),
        Row(
          children: [
            if (_index > 0) TextButton(onPressed: () => _go(_index - 1), child: const Text('Back')),
            const Spacer(),
            TextButton(onPressed: () => _answer(q.key, null), child: const Text('Skip this question')),
          ],
        ),
      ],
    );
  }

  Widget _notePage(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        Text("Anything you'd like to add?", style: t.headlineSmall),
        const SizedBox(height: 8),
        Text('This is optional.', style: t.bodySmall),
        const SizedBox(height: 20),
        TextField(
          controller: _note,
          minLines: 4,
          maxLines: 8,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(hintText: 'What happened today, how you feel, anything at all'),
        ),
        const SizedBox(height: 8),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Let my counsellor read this note'),
          subtitle: Text(_shareNote ? 'Your counsellor can read it.' : 'Only you can read it.', style: t.bodySmall),
          value: _shareNote,
          onChanged: (v) => setState(() => _shareNote = v),
        ),
        const SizedBox(height: 16),
        FilledButton(onPressed: _saving ? null : _finish, child: const Text('Done')),
        const SizedBox(height: 4),
        TextButton(onPressed: () => _go(_index - 1), child: const Text('Back')),
      ],
    );
  }
}
