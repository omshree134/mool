import 'package:flutter/material.dart';

import '../core/local_store.dart';
import '../core/settings.dart';
import '../services/repository.dart';

class _Section {
  const _Section(this.key, this.title, this.prompt, [this.defaults = const []]);
  final String key;
  final String title;
  final String prompt;
  final List<String> defaults;
}

/// Based on the Stanley–Brown Safety Planning Intervention: a short plan,
/// written in the person's own words while calm, to use in a hard moment.
const _sections = [
  _Section('warningSigns', 'Signs a hard time is starting',
      'Thoughts, feelings, places or situations that tell you things are getting difficult.'),
  _Section('onMyOwn', 'Things I can do on my own', 'What takes your mind off things, even a little?'),
  _Section('peoplePlaces', 'People and places that help', 'Who or where helps you feel a bit better or less alone?'),
  _Section('askForHelp', 'People I can ask for help', 'Who could you tell that you are struggling?'),
  _Section('professionals', 'Services I can call', 'Counsellors, doctors and helplines.',
      ['Tele-MANAS: 14416', 'Emergency: 112']),
  _Section('saferSurroundings', 'Making my surroundings safer',
      'Things you can move away or give to someone to keep for now.'),
  _Section('reasons', 'What matters to me', 'People, hopes or reasons that keep you going.'),
];

class SafetyPlanPage extends StatefulWidget {
  const SafetyPlanPage({super.key});

  @override
  State<SafetyPlanPage> createState() => _SafetyPlanPageState();
}

class _SafetyPlanPageState extends State<SafetyPlanPage> {
  static const _key = 'safetyPlan.v1';
  late Map<String, List<String>> _plan = _load();

  Map<String, List<String>> _load() {
    final raw = LocalStore.instance.getJson(_key);
    return {
      for (final s in _sections)
        s.key: raw.containsKey(s.key) ? List<String>.from(raw[s.key] as List) : List<String>.of(s.defaults),
    };
  }

  Future<void> _save() async {
    await LocalStore.instance.setJson(_key, _plan);
    if (Settings.instance.shareSafetyPlan) Repo.instance.saveSharedSafetyPlan(_plan);
  }

  Future<void> _add(_Section s) async {
    final text = await _edit(context, s.title, '');
    if (text == null || text.isEmpty) return;
    setState(() => _plan = {..._plan, s.key: [..._plan[s.key]!, text]});
    await _save();
  }

  Future<void> _change(_Section s, int i) async {
    final text = await _edit(context, s.title, _plan[s.key]![i]);
    if (text == null) return;
    final items = [..._plan[s.key]!];
    if (text.isEmpty) {
      items.removeAt(i);
    } else {
      items[i] = text;
    }
    setState(() => _plan = {..._plan, s.key: items});
    await _save();
  }

  Future<String?> _edit(BuildContext context, String title, String initial) {
    final controller = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          minLines: 1,
          maxLines: 4,
          textCapitalization: TextCapitalization.sentences,
        ),
        actions: [
          if (initial.isNotEmpty) TextButton(onPressed: () => Navigator.pop(ctx, ''), child: const Text('Remove')),
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, controller.text.trim()), child: const Text('Save')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('My safety plan')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Text(
            'Write this when you feel calm, in your own words. When things get hard, go through it from the top.',
            style: t.bodyLarge,
          ),
          const SizedBox(height: 8),
          ListenableBuilder(
            listenable: Settings.instance,
            builder: (context, _) => SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Share my plan with my counsellor'),
              subtitle: Text(
                Settings.instance.shareSafetyPlan ? 'Your counsellor can read it.' : 'Only you can read it.',
                style: t.bodySmall,
              ),
              value: Settings.instance.shareSafetyPlan,
              onChanged: (v) async {
                await Settings.instance.setBool(SettingKeys.shareSafetyPlan, v);
                Repo.instance.saveSharedSafetyPlan(v ? _plan : null);
                await Repo.instance.upsertProfile();
              },
            ),
          ),
          const SizedBox(height: 8),
          for (var n = 0; n < _sections.length; n++) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 14,
                          backgroundColor: scheme.secondaryContainer,
                          child: Text('${n + 1}', style: t.bodySmall?.copyWith(fontWeight: FontWeight.w700)),
                        ),
                        const SizedBox(width: 10),
                        Expanded(child: Text(_sections[n].title, style: t.titleMedium)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(_sections[n].prompt, style: t.bodySmall),
                    for (var i = 0; i < _plan[_sections[n].key]!.length; i++)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(_plan[_sections[n].key]![i]),
                        trailing: const Icon(Icons.edit_outlined, size: 20),
                        onTap: () => _change(_sections[n], i),
                      ),
                    TextButton.icon(
                      icon: const Icon(Icons.add),
                      label: const Text('Add'),
                      onPressed: () => _add(_sections[n]),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}
