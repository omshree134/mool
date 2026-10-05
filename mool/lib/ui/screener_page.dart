import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/screener.dart';
import '../services/daily_pipeline.dart';
import '../services/repository.dart';
import 'widgets/common.dart';

class ScreenerPage extends StatefulWidget {
  const ScreenerPage({super.key, required this.definition});
  final ScreenerDefinition definition;

  @override
  State<ScreenerPage> createState() => _ScreenerPageState();
}

class _ScreenerPageState extends State<ScreenerPage> {
  late final List<int?> _answers = List<int?>.filled(widget.definition.items.length, null);
  final Set<int> _seen = {};
  int _index = -1; // -1 = intro
  bool _finished = false;

  /// One id per sitting, so saving early (after question 9) and again at
  /// the end updates the same record instead of creating two.
  late final String _id = Repo.instance.newId();

  ScreenerDefinition get d => widget.definition;

  Future<void> _save() async {
    if (_seen.isEmpty) return;
    await Repo.instance.saveScreener(ScreenerResult(
      id: _id,
      type: d.type,
      at: DateTime.now(),
      answers: List<int?>.of(_answers),
    ));
    unawaited(DailyPipeline.instance.run());
  }

  Future<void> _answer(int? value) async {
    setState(() {
      _answers[_index] = value;
      _seen.add(_index);
    });
    // PHQ-9 question 9: offer support straight away, then carry on.
    if (d.type == ScreenerType.phq9 && _index == 8 && (value ?? 0) > 0) {
      await _save(); // make sure the counsellor hears about this even if they close now
      if (!mounted) return;
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (ctx) => const _SelfHarmSupportSheet(),
      );
    }
    if (!mounted) return;
    if (_index < d.items.length - 1) {
      setState(() => _index++);
    } else {
      await _save();
      if (mounted) setState(() => _finished = true);
    }
  }

  Future<void> _close() async {
    await _save(); // partial answers still help
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _close();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(icon: const Icon(Icons.close), tooltip: 'Close', onPressed: _close),
          title: _index >= 0 && !_finished
              ? Semantics(
                  label: 'Question ${_index + 1} of ${d.items.length}',
                  child: ExcludeSemantics(
                    child: LinearProgressIndicator(
                      value: (_index + 1) / d.items.length,
                      minHeight: 4,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                )
              : null,
        ),
        body: SafeArea(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: _finished
                ? _done(t)
                : _index < 0
                    ? _intro(t)
                    : _item(t),
          ),
        ),
      ),
    );
  }

  Widget _intro(TextTheme t) => ListView(
        key: const ValueKey('intro'),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        children: [
          Text(d.friendlyTitle, style: t.headlineSmall),
          const SizedBox(height: 12),
          Text(d.intro, style: t.bodyLarge),
          const SizedBox(height: 28),
          FilledButton(onPressed: () => setState(() => _index = 0), child: const Text('Start')),
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Not now')),
        ],
      );

  Widget _item(TextTheme t) => ListView(
        key: ValueKey(_index),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        children: [
          Text(d.stem, style: t.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
          const SizedBox(height: 8),
          Text(d.items[_index], style: t.titleLarge),
          const SizedBox(height: 24),
          for (final o in d.options)
            AnswerOption(label: o.label, selected: _answers[_index] == o.value, onTap: () => _answer(o.value)),
          Row(
            children: [
              if (_index > 0) TextButton(onPressed: () => setState(() => _index--), child: const Text('Back')),
              const Spacer(),
              TextButton(onPressed: () => _answer(null), child: const Text('Prefer not to answer')),
            ],
          ),
        ],
      );

  Widget _done(TextTheme t) => ListView(
        key: const ValueKey('done'),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        children: [
          Text('Thank you', style: t.headlineSmall),
          const SizedBox(height: 12),
          Text(
            'Your answers are saved. Your counsellor can go through them with you, '
            'and you can talk about anything that stood out.',
            style: t.bodyLarge,
          ),
          const SizedBox(height: 28),
          FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Done')),
        ],
      );
}

class _SelfHarmSupportSheet extends StatelessWidget {
  const _SelfHarmSupportSheet();

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Thank you for telling us', style: t.titleLarge),
            const SizedBox(height: 10),
            Text(
              'Your counsellor will be told, so they can reach out to you. '
              'If you might act on these thoughts, please talk to someone now. '
              'Tele-MANAS is free, confidential and open all day and night.',
              style: t.bodyLarge,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              icon: const Icon(Icons.call),
              label: const Text('Call Tele-MANAS (14416)'),
              onPressed: () => launchUrl(Uri(scheme: 'tel', path: '14416')),
            ),
            const SizedBox(height: 8),
            OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('Continue the questions')),
          ],
        ),
      ),
    );
  }
}
