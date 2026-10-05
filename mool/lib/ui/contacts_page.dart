import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/safety/sos_service.dart';
import '../services/safety/trusted_contacts.dart';
import 'widgets/common.dart';

class ContactsPage extends StatelessWidget {
  const ContactsPage({super.key});

  Future<void> _pick(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final c = await TrustedContacts.instance.pickFromPhone();
    if (c == null) return;
    final ok = await TrustedContacts.instance.add(c);
    messenger.showSnackBar(SnackBar(
      content: Text(ok ? '${c.name} added.' : 'You can add up to ${TrustedContacts.max} people.'),
    ));
  }

  Future<void> _manual(BuildContext context) async {
    final name = TextEditingController();
    final phone = TextEditingController();
    final result = await showDialog<TrustedContact>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add a person'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: phone,
              keyboardType: TextInputType.phone,
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9+ ]'))],
              decoration: const InputDecoration(labelText: 'Mobile number'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              if (name.text.trim().isEmpty || phone.text.replaceAll(RegExp(r'\D'), '').length < 10) return;
              Navigator.pop(ctx, TrustedContact(name: name.text.trim(), phone: phone.text.trim()));
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
    // Controllers are not disposed here: the dialog's closing animation still
    // uses them for a moment, and disposing early throws.
    if (result == null || !context.mounted) return;
    final ok = await TrustedContacts.instance.add(result);
    if (context.mounted) {
      showQuietSnack(context, ok ? '${result.name} added.' : 'You can add up to ${TrustedContacts.max} people.');
    }
  }

  Future<void> _test(BuildContext context, TrustedContact c) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await SosService.instance.sendTestMessage(c);
    messenger.showSnackBar(SnackBar(
      content: Text(ok
          ? 'Test message sent to ${c.name}.'
          : "The message couldn't be sent. Check that SMS is allowed for Mool and you have signal."),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('People I trust')),
      body: ListenableBuilder(
        listenable: TrustedContacts.instance,
        builder: (context, _) {
          final list = TrustedContacts.instance.all;
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
              Text(
                "When you press \"I'm in danger\", these people get an SMS with your location. "
                'Send each person a test message so they know, and so you know it works.',
                style: t.bodyLarge,
              ),
              const SizedBox(height: 20),
              if (list.isEmpty)
                Text('No one added yet.', style: t.bodySmall)
              else
                Card(
                  child: Column(
                    children: [
                      for (final c in list)
                        ListTile(
                          title: Text(c.name),
                          subtitle: Text(c.phone),
                          trailing: PopupMenuButton<String>(
                            tooltip: 'Options',
                            onSelected: (v) {
                              if (v == 'test') _test(context, c);
                              if (v == 'remove') TrustedContacts.instance.remove(c);
                            },
                            itemBuilder: (_) => const [
                              PopupMenuItem(value: 'test', child: Text('Send a test message')),
                              PopupMenuItem(value: 'remove', child: Text('Remove')),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              const SizedBox(height: 20),
              if (list.length < TrustedContacts.max) ...[
                FilledButton.icon(
                  icon: const Icon(Icons.contacts_outlined),
                  label: const Text('Choose from my contacts'),
                  onPressed: () => _pick(context),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  icon: const Icon(Icons.dialpad),
                  label: const Text('Type a number'),
                  onPressed: () => _manual(context),
                ),
              ] else
                Text('You have added the most people Mool allows (${TrustedContacts.max}).', style: t.bodySmall),
            ],
          );
        },
      ),
    );
  }
}
