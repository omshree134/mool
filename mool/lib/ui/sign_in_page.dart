import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/theme.dart';
import 'guardian_onboarding_page.dart';

class SignInPage extends StatefulWidget {
  const SignInPage({super.key});

  @override
  State<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends State<SignInPage> {
  final _phone = TextEditingController();
  final _code = TextEditingController();
  String? _verificationId;
  int? _resendToken;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _phone.dispose();
    _code.dispose();
    super.dispose();
  }

  String get _e164 => '+91${_phone.text.replaceAll(RegExp(r'\D'), '')}';

  Future<void> _sendCode() async {
    final digits = _phone.text.replaceAll(RegExp(r'\D'), '');
    if (digits.length != 10) {
      setState(() => _error = 'Enter your 10-digit mobile number.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    await FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: _e164,
      forceResendingToken: _resendToken,
      timeout: const Duration(seconds: 60),
      verificationCompleted: (credential) async {
        await FirebaseAuth.instance.signInWithCredential(credential);
      },
      verificationFailed: (e) {
        if (!mounted) return;
        setState(() {
          _busy = false;
          _error = switch (e.code) {
            'invalid-phone-number' => 'That number doesn\'t look right. Check it and try again.',
            'too-many-requests' => 'Too many tries. Wait a while, then try again.',
            'network-request-failed' => 'No internet connection. Try again when you\'re online.',
            _ => 'The code could not be sent. Try again in a moment.',
          };
        });
      },
      codeSent: (verificationId, resendToken) {
        if (!mounted) return;
        setState(() {
          _busy = false;
          _verificationId = verificationId;
          _resendToken = resendToken;
        });
      },
      codeAutoRetrievalTimeout: (verificationId) => _verificationId = verificationId,
    );
  }

  Future<void> _verify() async {
    final code = _code.text.trim();
    if (_verificationId == null || code.length != 6) {
      setState(() => _error = 'Enter the 6-digit code from the SMS.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await FirebaseAuth.instance.signInWithCredential(
        PhoneAuthProvider.credential(verificationId: _verificationId!, smsCode: code),
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.code == 'invalid-verification-code'
            ? 'That code isn\'t right. Check the SMS and try again.'
            : 'Could not sign in. Try again in a moment.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final codeStep = _verificationId != null;

    return Scaffold(
      backgroundColor: MoolPalette.mist,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Serene Brand Mark
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: MoolPalette.moss,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: MoolPalette.moss.withValues(alpha: 0.25),
                        blurRadius: 14,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: const Text('म', style: TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 16),
                Text('Mool (मूल)', style: t.headlineMedium?.copyWith(fontWeight: FontWeight.bold, color: MoolPalette.ink)),
                const SizedBox(height: 6),
                Text(
                  'A quiet place to check in with yourself, and stay grounded with your guardian.',
                  textAlign: TextAlign.center,
                  style: t.bodyMedium?.copyWith(color: MoolPalette.slate, height: 1.4),
                ),
                const SizedBox(height: 28),

                // Card Container
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFD5E0DA)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (!codeStep) ...[
                        Text('Sign in with Mobile Number', style: t.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text("We'll send a 6-digit verification code by SMS.", style: t.bodySmall?.copyWith(color: MoolPalette.slate)),
                        const SizedBox(height: 20),
                        TextField(
                          controller: _phone,
                          keyboardType: TextInputType.phone,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)],
                          decoration: InputDecoration(
                            prefixText: '+91  ',
                            labelText: 'Mobile number',
                            filled: true,
                            fillColor: MoolPalette.mist.withValues(alpha: 0.5),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFD5E0DA))),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: MoolPalette.moss, width: 2)),
                          ),
                          onSubmitted: (_) => _sendCode(),
                        ),
                        const SizedBox(height: 18),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: MoolPalette.moss,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: _busy ? null : _sendCode,
                          child: Text(_busy ? 'Sending code…' : 'Send verification code', style: const TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ] else ...[
                        Text('Enter verification code', style: t.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text('Sent via SMS to $_e164', style: t.bodySmall?.copyWith(color: MoolPalette.slate)),
                        const SizedBox(height: 20),
                        TextField(
                          controller: _code,
                          keyboardType: TextInputType.number,
                          autofillHints: const [AutofillHints.oneTimeCode],
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
                          textAlign: TextAlign.center,
                          style: const TextStyle(letterSpacing: 8, fontSize: 18, fontWeight: FontWeight.bold),
                          decoration: InputDecoration(
                            hintText: '••••••',
                            filled: true,
                            fillColor: MoolPalette.mist.withValues(alpha: 0.5),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFD5E0DA))),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: MoolPalette.moss, width: 2)),
                          ),
                          onSubmitted: (_) => _verify(),
                        ),
                        const SizedBox(height: 18),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: MoolPalette.moss,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: _busy ? null : _verify,
                          child: Text(_busy ? 'Checking…' : 'Sign in & continue', style: const TextStyle(fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: _busy ? null : () => setState(() => _verificationId = null),
                          child: const Text('Use a different number', style: TextStyle(color: MoolPalette.moss)),
                        ),
                        TextButton(
                          onPressed: _busy ? null : _sendCode,
                          child: const Text('Resend code', style: TextStyle(color: MoolPalette.slate)),
                        ),
                      ],
                      if (_error != null) ...[
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.red.shade200),
                          ),
                          child: Text(_error!, style: TextStyle(color: Colors.red.shade800, fontSize: 13)),
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 24),
                // Or connect to Guardian
                TextButton.icon(
                  onPressed: () => Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (_) => const GuardianOnboardingPage()),
                  ),
                  icon: const Icon(Icons.qr_code_scanner, color: MoolPalette.moss, size: 18),
                  label: const Text('Direct Guardian Setup & QR Scan →', style: TextStyle(color: MoolPalette.moss, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
