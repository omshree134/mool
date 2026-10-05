import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart' hide Settings;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../app/app.dart';
import '../app/theme.dart';
import '../core/local_store.dart';
import '../core/settings.dart';
import '../services/auth_service.dart';
import '../services/repository.dart';

class GuardianOnboardingPage extends StatefulWidget {
  final int initialStep;
  const GuardianOnboardingPage({super.key, this.initialStep = 0});

  @override
  State<GuardianOnboardingPage> createState() => _GuardianOnboardingPageState();
}

class _GuardianOnboardingPageState extends State<GuardianOnboardingPage> {
  late final PageController _pageController;
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _manualCodeController = TextEditingController();

  final MobileScannerController _scannerController = MobileScannerController();
  bool _scanning = true;
  bool _busy = false;
  String? _busyMessage;
  String? _error;
  late int _currentStep;

  @override
  void initState() {
    super.initState();
    _currentStep = widget.initialStep;
    _pageController = PageController(initialPage: widget.initialStep);
    final currentName = Settings.instance.displayName;
    if (currentName.isNotEmpty) {
      _nameController.text = currentName;
    }
    final currentPhone = LocalStore.instance.getString('emergency.contact');
    if (currentPhone != null && currentPhone.isNotEmpty) {
      _phoneController.text = currentPhone;
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _manualCodeController.dispose();
    _scannerController.dispose();
    super.dispose();
  }

  void _goToScanStep() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Please enter a name or pseudonym to continue.');
      return;
    }
    setState(() {
      _error = null;
      _currentStep = 1;
    });
    _pageController.animateToPage(
      1,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeInOut,
    );
  }

  /// Google Sign-In with automatic cloud data restore across app resets
  Future<void> _signInWithGoogle() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _busyMessage = 'Signing in with Google...';
      _error = null;
    });

    try {
      final credential = await AuthService.instance.signInWithGoogle();
      if (credential == null) {
        // User cancelled interactive sign-in
        if (mounted) {
          setState(() {
            _busy = false;
            _busyMessage = null;
          });
        }
        return;
      }

      if (!mounted) return;

      final s = Settings.instance;
      final name = s.displayName.isNotEmpty ? s.displayName : (credential.user?.displayName ?? 'Friend');

      // Check if this account already has a linked guardian or history
      if (s.hasGuardian || s.onboarded) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: MoolPalette.moss,
            content: Row(
              children: [
                const Icon(Icons.cloud_done_rounded, color: Colors.white),
                const SizedBox(width: 10),
                Expanded(child: Text('Welcome back, $name! Your data has been restored.')),
              ],
            ),
            duration: const Duration(seconds: 3),
          ),
        );
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const HomeShell()),
        );
      } else {
        // New Google account - prefill name and proceed to Guardian connect step
        _nameController.text = name;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: MoolPalette.moss,
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white),
                const SizedBox(width: 10),
                Expanded(child: Text('Signed in as $name. Connect with your Guardian to finish setup.')),
              ],
            ),
            duration: const Duration(seconds: 2),
          ),
        );
        setState(() {
          _busy = false;
          _busyMessage = null;
          _currentStep = 1;
        });
        _pageController.animateToPage(
          1,
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeInOut,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Google Sign-In failed: $e';
          _busy = false;
          _busyMessage = null;
        });
      }
    }
  }

  Future<void> _skipToHome() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _busyMessage = 'Entering Mool...';
      _scanning = false;
      _error = null;
    });

    try {
      final name = _nameController.text.trim().isEmpty ? 'Friend' : _nameController.text.trim();
      await LocalStore.instance.setString(SettingKeys.name, name);
      if (_phoneController.text.trim().isNotEmpty) {
        await LocalStore.instance.setString('emergency.contact', _phoneController.text.trim());
      }
      await LocalStore.instance.setBool(SettingKeys.onboarded, true);
      await Repo.instance.upsertProfile();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: MoolPalette.dusk,
          content: Row(
            children: [
              Icon(Icons.info_outline, color: Colors.white, size: 20),
              SizedBox(width: 10),
              Expanded(
                child: Text('Welcome! You can connect with your Guardian anytime in Me > Connect.'),
              ),
            ],
          ),
          duration: Duration(seconds: 3),
        ),
      );

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeShell()),
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Error skipping setup: $e';
          _busy = false;
          _busyMessage = null;
          _scanning = true;
        });
      }
    }
  }

  Future<void> _handleScannedData(String rawData) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _busyMessage = 'Connecting to Guardian...';
      _scanning = false;
      _error = null;
    });

    try {
      String guardianId = 'guardian_singh';
      String guardianName = 'Officer Rajesh Singh (Guardian)';

      // 1. Try parsing JSON format: {"guardianId": "...", "guardianName": "..."}
      final trimmed = rawData.trim();
      if (trimmed.startsWith('{') && trimmed.endsWith('}')) {
        try {
          final decoded = jsonDecode(trimmed);
          if (decoded is Map) {
            guardianId = decoded['guardianId']?.toString() ?? guardianId;
            guardianName = decoded['guardianName']?.toString() ?? guardianName;
          }
        } catch (_) {}
      } else {
        // 2. Try parsing URI format: mool://link?guardianId=...&guardianName=...
        final uri = Uri.tryParse(trimmed);
        if (uri != null && uri.queryParameters.containsKey('guardianId')) {
          guardianId = uri.queryParameters['guardianId'] ?? guardianId;
          guardianName = uri.queryParameters['guardianName'] ?? guardianName;
        } else if (trimmed.isNotEmpty) {
          // 3. Simple code like GRD-8821
          final cleanCode = trimmed.toUpperCase();
          guardianId = cleanCode;
          guardianName = 'Guardian ($cleanCode)';
          try {
            final snap = await FirebaseFirestore.instance
                .collection('pairingCodes')
                .doc(cleanCode)
                .get()
                .timeout(const Duration(seconds: 4));
            if (snap.exists && snap.data() != null) {
              final d = snap.data()!;
              guardianId = d['guardianId']?.toString() ?? guardianId;
              guardianName = d['guardianName']?.toString() ?? guardianName;
            }
          } catch (_) {}
        }
      }

      // Save user details
      final currentName = Settings.instance.displayName;
      final name = _nameController.text.trim().isNotEmpty
          ? _nameController.text.trim()
          : (currentName.isNotEmpty ? currentName : 'Friend');
      await LocalStore.instance.setString(SettingKeys.name, name);
      if (_phoneController.text.trim().isNotEmpty) {
        await LocalStore.instance.setString('emergency.contact', _phoneController.text.trim());
      }
      await LocalStore.instance.setBool(SettingKeys.onboarded, true);

      // Link guardian in repository & Firestore
      await Repo.instance.linkGuardian(guardianId: guardianId, guardianName: guardianName);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: MoolPalette.moss,
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white),
              const SizedBox(width: 10),
              Expanded(child: Text('Connected with $guardianName!')),
            ],
          ),
          duration: const Duration(seconds: 2),
        ),
      );

      if (widget.initialStep == 1 && Navigator.canPop(context)) {
        Navigator.of(context).pop(true);
      } else {
        // Navigate straight into HomeShell
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const HomeShell()),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to connect: $e';
          _busy = false;
          _busyMessage = null;
          _scanning = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // Top App Bar / Progress Indicator (clean header, no duplicate skip button)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  if (_currentStep == 1 || widget.initialStep == 1 || Navigator.canPop(context))
                    IconButton(
                      icon: Icon(Icons.arrow_back_rounded, color: scheme.onSurface),
                      onPressed: () {
                        if (widget.initialStep == 1) {
                          Navigator.of(context).maybePop();
                        } else if (_currentStep == 1) {
                          setState(() => _currentStep = 0);
                          _pageController.animateToPage(
                            0,
                            duration: const Duration(milliseconds: 250),
                            curve: Curves.easeInOut,
                          );
                        } else if (Navigator.canPop(context)) {
                          Navigator.of(context).pop();
                        }
                      },
                    ),
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: MoolPalette.moss,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: MoolPalette.moss.withValues(alpha: 0.25),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'म',
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.initialStep == 1 ? 'Connect Guardian' : 'Mool Setup',
                        style: GoogleFonts.inter(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.2,
                          color: scheme.onSurface,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: isDark ? MoolPalette.nightRaised : MoolPalette.mossSoft,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          widget.initialStep == 1
                              ? 'Scan QR Code'
                              : (_currentStep == 0 ? 'Step 1: Your Details' : 'Step 2: Connect Guardian'),
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isDark ? MoolPalette.mossLight : MoolPalette.mossDark,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: isDark ? const Color(0xFF333832) : MoolPalette.mist),

            // Main Step Views
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildDetailsStep(theme, scheme, isDark),
                  _buildScanStep(theme, scheme, isDark),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailsStep(ThemeData theme, ColorScheme scheme, bool isDark) {
    final cardBg = isDark ? MoolPalette.nightSurface : const Color(0xFFF9F7F1);
    final borderColor = isDark ? const Color(0xFF333832) : MoolPalette.mist;
    final inputBg = isDark ? MoolPalette.nightRaised : Colors.white;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          Text(
            'Welcome to Mool',
            style: GoogleFonts.inter(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'A quiet, grounded space to check in with yourself and stay safely connected with your support guardian.',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: scheme.onSurfaceVariant,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 24),

          // Google Login Card - Backup & Restore
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: borderColor, width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: isDark ? Colors.black26 : const Color(0xFF2B2B28).withValues(alpha: 0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isDark ? MoolPalette.nightRaised : Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.cloud_sync_rounded, color: MoolPalette.moss, size: 20),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Save & Restore Your Account',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: scheme.onSurface,
                            ),
                          ),
                          Text(
                            'Keep your check-ins and guardian link safe if you reset or change phones.',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: scheme.onSurfaceVariant,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      backgroundColor: inputBg,
                      side: BorderSide(color: isDark ? const Color(0xFF40463E) : const Color(0xFFD5CFBF), width: 1.2),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    onPressed: _busy ? null : _signInWithGoogle,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 22,
                          height: 22,
                          alignment: Alignment.center,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: const Text(
                            'G',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF4285F4),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Continue with Google',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: scheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Divider: Or setup manually
          Row(
            children: [
              Expanded(child: Divider(color: borderColor)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  'OR SET UP MANUALLY',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
              Expanded(child: Divider(color: borderColor)),
            ],
          ),

          const SizedBox(height: 20),

          // Name & Details Card - GroundedCard styling
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: borderColor, width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: isDark ? Colors.black26 : const Color(0xFF2B2B28).withValues(alpha: 0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.person_outline_rounded, size: 16, color: MoolPalette.moss),
                    const SizedBox(width: 6),
                    Text(
                      'Preferred Name / Pseudonym',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurface,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    hintText: 'e.g. Aarav, Hope, or chosen name',
                    hintStyle: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
                    filled: true,
                    fillColor: inputBg,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: borderColor),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: borderColor),
                    ),
                    focusedBorder: const OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(14)),
                      borderSide: BorderSide(color: MoolPalette.moss, width: 2),
                    ),
                  ),
                ),
                const SizedBox(height: 18),

                // Optional Emergency Contact Phone
                Row(
                  children: [
                    const Icon(Icons.phone_outlined, size: 16, color: MoolPalette.sandrose),
                    const SizedBox(width: 6),
                    Text(
                      'Emergency Contact Phone (Optional)',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurface,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    hintText: 'e.g. 9876543210 (trusted friend or family)',
                    hintStyle: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
                    filled: true,
                    fillColor: inputBg,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: borderColor),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: borderColor),
                    ),
                    focusedBorder: const OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(14)),
                      borderSide: BorderSide(color: MoolPalette.moss, width: 2),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Privacy explanation card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? MoolPalette.moss.withValues(alpha: 0.15) : MoolPalette.mossSoft,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isDark ? MoolPalette.moss.withValues(alpha: 0.3) : MoolPalette.mossLight.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.shield_outlined, color: MoolPalette.moss, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Your daily check-ins and reflection notes remain private and encrypted. Your guardian will only see your overall wellbeing tier and emergency signals.',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: scheme.onSurface,
                      height: 1.45,
                    ),
                  ),
                ),
              ],
            ),
          ),

          if (_error != null) ...[
            const SizedBox(height: 16),
            Text(
              _error!,
              style: const TextStyle(color: MoolPalette.signal, fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ],

          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: MoolPalette.moss,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              onPressed: _busy ? null : _goToScanStep,
              icon: const Icon(Icons.arrow_forward_rounded, size: 20),
              label: const Text(
                'Next: Connect to Guardian',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // ONLY ONE skip button on Step 0:
          Center(
            child: TextButton(
              onPressed: _busy ? null : _skipToHome,
              child: Text(
                'Skip setup and explore Mool first',
                style: GoogleFonts.inter(
                  color: scheme.onSurfaceVariant,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScanStep(ThemeData theme, ColorScheme scheme, bool isDark) {
    final cardBg = isDark ? MoolPalette.nightSurface : const Color(0xFFF9F7F1);
    final borderColor = isDark ? const Color(0xFF333832) : MoolPalette.mist;
    final inputBg = isDark ? MoolPalette.nightRaised : Colors.white;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            'Scan Guardian QR Code',
            style: GoogleFonts.inter(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.4,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Point your camera at the QR code shown on the Guardian Web Portal (https://moolorg.web.app).',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: scheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),

          // Camera Viewfinder Box
          Container(
            width: 250,
            height: 250,
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: MoolPalette.moss, width: 3),
              boxShadow: [
                BoxShadow(
                  color: MoolPalette.moss.withValues(alpha: 0.25),
                  blurRadius: 20,
                  spreadRadius: 4,
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (_scanning)
                  MobileScanner(
                    controller: _scannerController,
                    onDetect: (capture) {
                      for (final barcode in capture.barcodes) {
                        final val = barcode.rawValue;
                        if (val != null && val.isNotEmpty) {
                          _handleScannedData(val);
                          break;
                        }
                      }
                    },
                  ),
                if (_busy)
                  Container(
                    color: Colors.black87,
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
                          const SizedBox(height: 14),
                          Text(
                            _busyMessage ?? 'Connecting to Guardian...',
                            style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Manual Code Entry alternative - GroundedCard styling
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: borderColor, width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: isDark ? Colors.black26 : const Color(0xFF2B2B28).withValues(alpha: 0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Or enter Guardian code manually:',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _manualCodeController,
                        textCapitalization: TextCapitalization.characters,
                        decoration: InputDecoration(
                          hintText: 'e.g. GRD-8821',
                          hintStyle: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          filled: true,
                          fillColor: inputBg,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: borderColor),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: borderColor),
                          ),
                          focusedBorder: const OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(12)),
                            borderSide: BorderSide(color: MoolPalette.moss, width: 2),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: MoolPalette.moss,
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _busy
                          ? null
                          : () {
                              final code = _manualCodeController.text.trim();
                              if (code.isNotEmpty) {
                                _handleScannedData(code);
                              }
                            },
                      child: const Text(
                        'Connect',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          if (_error != null) ...[
            const SizedBox(height: 14),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: MoolPalette.signal, fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ],

          const SizedBox(height: 24),

          // Cancel or Skip button:
          SizedBox(
            width: double.infinity,
            height: 50,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: scheme.onSurface,
                side: BorderSide(color: isDark ? const Color(0xFF40463E) : MoolPalette.mistDark, width: 1.2),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                backgroundColor: inputBg,
              ),
              onPressed: _busy
                  ? null
                  : (widget.initialStep == 1
                      ? () => Navigator.of(context).maybePop()
                      : _skipToHome),
              icon: Icon(
                widget.initialStep == 1 ? Icons.close_rounded : Icons.arrow_forward_rounded,
                size: 18,
                color: widget.initialStep == 1 ? scheme.onSurfaceVariant : MoolPalette.moss,
              ),
              label: Text(
                widget.initialStep == 1 ? 'Cancel — Return to Me tab' : 'Skip for now — Connect later',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurface,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            widget.initialStep == 1
                ? 'Point camera at the QR code on your guardian web portal.'
                : 'You can always connect to your Guardian in the Me tab.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
