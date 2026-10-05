import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/native_bridge.dart';
import '../services/safety/sos_service.dart';
import '../services/safety/trusted_contacts.dart';
import 'help_page.dart';
import 'widgets/common.dart';

/// A cancellable countdown before any emergency message is sent.
class SosCountdownPage extends StatefulWidget {
  const SosCountdownPage({super.key, required this.reason, this.seconds = 5});
  final String reason;
  final int seconds;

  @override
  State<SosCountdownPage> createState() => _SosCountdownPageState();
}

class _SosCountdownPageState extends State<SosCountdownPage> {
  late int _remaining = widget.seconds;
  Timer? _timer;
  bool _sent = false;

  @override
  void initState() {
    super.initState();
    if (SosService.instance.active) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _openActive());
      return;
    }
    HapticFeedback.heavyImpact();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _remaining--);
      if (_remaining <= 0) {
        _send();
      } else {
        HapticFeedback.heavyImpact();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _send() {
    if (_sent) return;
    _sent = true;
    _timer?.cancel();
    HapticFeedback.vibrate();
    unawaited(SosService.instance.trigger(reason: widget.reason));
    _openActive();
  }

  void _openActive() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const SosActivePage()));
  }

  @override
  Widget build(BuildContext context) {
    final red = Theme.of(context).colorScheme.error;
    return Scaffold(
      backgroundColor: Color.lerp(red, Colors.black, 0.35),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Spacer(),
              const Text('Sending help in', style: TextStyle(color: Colors.white, fontSize: 22)),
              const SizedBox(height: 8),
              Semantics(
                liveRegion: true,
                label: '$_remaining seconds',
                child: ExcludeSemantics(
                  child: Text('$_remaining',
                      style: const TextStyle(color: Colors.white, fontSize: 120, fontWeight: FontWeight.w800)),
                ),
              ),
              Text(
                widget.reason == 'Help button'
                    ? "Started from 'Get Help'."
                    : "Started by 'I'm in danger'.",
                style: const TextStyle(color: Colors.white70, fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 72,
                child: FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: red),
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: _send,
                child: const Text('Send now', style: TextStyle(color: Colors.white, fontSize: 16)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shows exactly what has and hasn't been sent, so the person can act on it.
class SosActivePage extends StatelessWidget {
  const SosActivePage({super.key});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return ListenableBuilder(
      listenable: SosService.instance,
      builder: (context, _) {
        final sos = SosService.instance;
        return Scaffold(
          appBar: AppBar(title: Text(sos.active ? 'Getting you help' : 'Emergency ended')),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
              if (!sos.active) ...[
                Text('The emergency has ended.', style: t.bodyLarge),
                const SizedBox(height: 16),
                FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
              ] else ...[
                Card(
                  child: Column(
                    children: [for (final step in sos.steps) _StepRow(step: step)],
                  ),
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: scheme.error),
                  icon: const Icon(Icons.call),
                  label: const Text('Call 112'),
                  onPressed: () => NativeBridge.placeCall('112').catchError((Object _) => false),
                ),
                const SizedBox(height: 12),
                for (final c in TrustedContacts.instance.all.take(3))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.call_outlined),
                      label: Text('Call ${c.name}'),
                      onPressed: () => dial(c.phone),
                    ),
                  ),
                const SizedBox(height: 28),
                HoldToConfirm(
                  label: "I'm safe now",
                  hint: 'Press and hold to end the emergency',
                  color: scheme.primary,
                  onConfirmed: () async {
                    final nav = Navigator.of(context);
                    final messenger = ScaffoldMessenger.of(context);
                    await SosService.instance.end();
                    nav.pop();
                    messenger.showSnackBar(
                      const SnackBar(content: Text("Glad you're safe. Your support team has been updated.")),
                    );
                  },
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({required this.step});
  final SosStep step;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (Widget icon, String status) = switch (step.state) {
      SosStepState.pending => (Icon(Icons.schedule, color: scheme.onSurfaceVariant), 'Waiting'),
      SosStepState.running => (
          const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5)),
          'In progress'
        ),
      SosStepState.done => (Icon(Icons.check_circle, color: scheme.primary), 'Done'),
      SosStepState.failed => (Icon(Icons.error_outline, color: scheme.error), 'Not done'),
      SosStepState.skipped => (Icon(Icons.remove_circle_outline, color: scheme.onSurfaceVariant), 'Skipped'),
    };
    return ListTile(
      leading: icon,
      title: Text(step.label),
      subtitle: Text(step.note ?? status),
    );
  }
}
