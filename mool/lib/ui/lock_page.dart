import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/settings.dart';

/// Shown above everything when the app returns after 30+ seconds away.
/// Emergency calling stays available without the PIN.
class LockPage extends StatefulWidget {
  const LockPage({super.key, required this.onUnlocked});
  final VoidCallback onUnlocked;

  @override
  State<LockPage> createState() => _LockPageState();
}

class _LockPageState extends State<LockPage> {
  String _entered = '';
  String? _message;
  int _wrong = 0;
  DateTime? _waitUntil;
  bool _confirmForgot = false;
  Timer? _tick;

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  bool get _waiting => _waitUntil != null && DateTime.now().isBefore(_waitUntil!);

  void _press(String digit) {
    if (_waiting || _entered.length >= 6) return;
    HapticFeedback.selectionClick();
    setState(() {
      _entered += digit;
      _message = null;
    });
    if (_entered.length >= 4 && Settings.instance.checkPin(_entered)) {
      widget.onUnlocked();
    } else if (_entered.length == 6) {
      _fail();
    }
  }

  void _submit() {
    if (_entered.length < 4) return;
    if (Settings.instance.checkPin(_entered)) {
      widget.onUnlocked();
    } else {
      _fail();
    }
  }

  void _fail() {
    HapticFeedback.mediumImpact();
    _wrong++;
    setState(() {
      _entered = '';
      if (_wrong >= 5) {
        _waitUntil = DateTime.now().add(const Duration(seconds: 30));
        _message = 'Too many tries. Wait 30 seconds.';
        _tick?.cancel();
        _tick = Timer(const Duration(seconds: 30), () {
          if (mounted) setState(() => _message = null);
        });
        _wrong = 0;
      } else {
        _message = "That PIN isn't right.";
      }
    });
  }

  Future<void> _forgot() async {
    await Settings.instance.removePin();
    await FirebaseAuth.instance.signOut();
    widget.onUnlocked();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  style: TextButton.styleFrom(foregroundColor: scheme.error),
                  onPressed: () => launchUrl(Uri(scheme: 'tel', path: '112')),
                  icon: const Icon(Icons.call),
                  label: const Text('Emergency call'),
                ),
              ),
              const Spacer(),
              Text('Enter your PIN', style: t.headlineSmall),
              const SizedBox(height: 20),
              Semantics(
                label: '${_entered.length} digits entered',
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    6,
                    (i) => Container(
                      margin: const EdgeInsets.symmetric(horizontal: 6),
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: i < _entered.length ? scheme.primary : Colors.transparent,
                        border: Border.all(color: i < 4 ? scheme.primary : scheme.outlineVariant, width: 2),
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(
                height: 40,
                child: Center(
                  child: Text(_message ?? '', style: TextStyle(color: scheme.error)),
                ),
              ),
              for (final row in const [
                ['1', '2', '3'],
                ['4', '5', '6'],
                ['7', '8', '9'],
              ])
                Row(mainAxisAlignment: MainAxisAlignment.center, children: row.map(_key).toList()),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _action(Icons.backspace_outlined, 'Delete',
                      () => setState(() => _entered = _entered.isEmpty ? '' : _entered.substring(0, _entered.length - 1))),
                  _key('0'),
                  _action(Icons.check, 'Unlock', _submit),
                ],
              ),
              const Spacer(),
              if (!_confirmForgot)
                TextButton(onPressed: () => setState(() => _confirmForgot = true), child: const Text('Forgot PIN?'))
              else
                Column(
                  children: [
                    Text('You will need to sign in again with your phone number. Your PIN will be removed.',
                        textAlign: TextAlign.center, style: t.bodySmall),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        TextButton(onPressed: () => setState(() => _confirmForgot = false), child: const Text('Cancel')),
                        TextButton(onPressed: _forgot, child: const Text('Sign in again')),
                      ],
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _key(String d) => Padding(
        padding: const EdgeInsets.all(8),
        child: SizedBox(
          width: 72,
          height: 72,
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(shape: const CircleBorder(), padding: EdgeInsets.zero),
            onPressed: _waiting ? null : () => _press(d),
            child: Text(d, style: const TextStyle(fontSize: 26)),
          ),
        ),
      );

  Widget _action(IconData icon, String label, VoidCallback onTap) => Padding(
        padding: const EdgeInsets.all(8),
        child: SizedBox(
          width: 72,
          height: 72,
          // No tooltip: the lock sits outside the Navigator, where there is no Overlay.
          child: Semantics(
            button: true,
            label: label,
            child: IconButton(onPressed: _waiting ? null : onTap, icon: Icon(icon)),
          ),
        ),
      );
}
