import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../services/link_service.dart';
import '../services/member_profile.dart';
import 'widgets/common.dart';

class LinkPage extends StatefulWidget {
  const LinkPage({super.key});

  @override
  State<LinkPage> createState() => _LinkPageState();
}

class _LinkPageState extends State<LinkPage> {
  final _code = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _redeem(String code) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final name = await LinkService.redeem(code);
      if (!mounted) return;
      showQuietSnack(context, 'You are now connected with $name.');
      Navigator.of(context).pop();
    } on LinkException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _scan() async {
    final code = await Navigator.of(context).push<String>(MaterialPageRoute(builder: (_) => const _ScanPage()));
    if (code != null) {
      _code.text = code;
      await _redeem(code);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Connect with your counsellor')),
      body: ListenableBuilder(
        listenable: MemberProfile.instance,
        builder: (context, _) {
          final p = MemberProfile.instance;
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
              if (p.linked) ...[
                SectionCard(
                  child: Row(children: [
                    Icon(Icons.check_circle, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text('Connected with ${p.counsellorName ?? 'your counsellor'}.', style: t.titleMedium),
                    ),
                  ]),
                ),
                const SizedBox(height: 16),
                Text('If you have been given a new code, you can enter it below.', style: t.bodySmall),
                const SizedBox(height: 16),
              ] else ...[
                Text('Your counsellor can give you a code, or show you a QR code to scan.', style: t.bodyLarge),
                const SizedBox(height: 20),
              ],
              FilledButton.icon(
                icon: const Icon(Icons.qr_code_scanner),
                label: const Text('Scan a QR code'),
                onPressed: _busy ? null : _scan,
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _code,
                textCapitalization: TextCapitalization.characters,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9-]')),
                  LengthLimitingTextInputFormatter(9),
                ],
                decoration: const InputDecoration(labelText: 'Or type the code', hintText: 'ABCD-1234'),
                onSubmitted: (v) => _redeem(v),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: _busy ? null : () => _redeem(_code.text),
                child: Text(_busy ? 'Checking…' : 'Connect'),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _ScanPage extends StatefulWidget {
  const _ScanPage();

  @override
  State<_ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<_ScanPage> {
  final _controller = MobileScannerController();
  bool _done = false;
  DateTime? _lastWarning;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_done) return;
    for (final b in capture.barcodes) {
      final raw = b.rawValue;
      if (raw == null) continue;
      final code = LinkService.codeFromQr(raw);
      if (code != null) {
        _done = true;
        Navigator.of(context).pop(code);
        return;
      }
    }
    final now = DateTime.now();
    if (_lastWarning == null || now.difference(_lastWarning!) > const Duration(seconds: 4)) {
      _lastWarning = now;
      showQuietSnack(context, "That QR code isn't a Mool code.");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan the QR code')),
      body: Stack(
        children: [
          MobileScanner(controller: _controller, onDetect: _onDetect),
          Center(
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 3),
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
          Positioned(
            left: 24,
            right: 24,
            bottom: 40,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(12)),
              child: const Text(
                'Point the camera at the code on your counsellor\'s screen.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
