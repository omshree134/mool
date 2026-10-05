import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../app/theme.dart';

class PermissionSettingsPage extends StatefulWidget {
  const PermissionSettingsPage({super.key});

  @override
  State<PermissionSettingsPage> createState() => _PermissionSettingsPageState();
}

class _PermissionSettingsPageState extends State<PermissionSettingsPage> with WidgetsBindingObserver {
  final Map<String, bool> _statusMap = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkAllPermissions();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkAllPermissions();
    }
  }

  Future<void> _checkAllPermissions() async {
    final activity = await Permission.activityRecognition.isGranted;
    final location = await Permission.locationWhenInUse.isGranted;
    final microphone = await Permission.microphone.isGranted;
    final bluetooth = await Permission.bluetoothScan.isGranted;
    final notification = await Permission.notification.isGranted;
    final camera = await Permission.camera.isGranted;
    final contacts = await Permission.contacts.isGranted;

    if (mounted) {
      setState(() {
        _statusMap['activity'] = activity;
        _statusMap['location'] = location;
        _statusMap['microphone'] = microphone;
        _statusMap['bluetooth'] = bluetooth;
        _statusMap['notification'] = notification;
        _statusMap['camera'] = camera;
        _statusMap['contacts'] = contacts;
        _loading = false;
      });
    }
  }

  Future<void> _togglePermission(String key, List<Permission> perms) async {
    final isGranted = _statusMap[key] ?? false;

    if (isGranted) {
      // Permission already granted. Direct user to OS settings to revoke if desired.
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Manage in Settings'),
          content: const Text(
            'On Android, granted permissions can be turned off anytime in your phone’s App Settings.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(ctx);
                openAppSettings();
              },
              child: const Text('Open Settings'),
            ),
          ],
        ),
      );
      return;
    }

    // Request permissions
    bool allGranted = true;
    for (final p in perms) {
      final status = await p.request();
      if (!status.isGranted && !status.isLimited) {
        allGranted = false;
        if (status.isPermanentlyDenied && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Permission was previously denied. Please enable in Settings.'),
              action: SnackBarAction(
                label: 'Settings',
                onPressed: openAppSettings,
              ),
            ),
          );
          return;
        }
      }
    }

    await _checkAllPermissions();

    if (allGranted && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: MoolPalette.moss,
          content: Text('Permission enabled safely.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final t = theme.textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Permission Transparency'),
        actions: const [
          IconButton(
            tooltip: 'System App Settings',
            icon: Icon(Icons.settings_suggest_outlined),
            onPressed: openAppSettings,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
              children: [
                // Header Banner explaining the philosophy
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? MoolPalette.nightSurface : MoolPalette.moss.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark ? const Color(0xFF333832) : MoolPalette.moss.withValues(alpha: 0.25),
                      width: 1.2,
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.shield_outlined,
                        color: isDark ? MoolPalette.mossLight : MoolPalette.moss,
                        size: 28,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Data Minimization & Trust',
                              style: t.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: isDark ? MoolPalette.mossLight : MoolPalette.mossDark,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Mool only activates sensors to protect your physical safety or detect distress patterns. '
                              'Sensors are computed locally on your device with on-device ML — your intimate life is never monetized or exposed.',
                              style: t.bodySmall?.copyWith(
                                height: 1.45,
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Section title
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 8),
                  child: Text(
                    'Device Permissions',
                    style: t.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: scheme.onSurface,
                    ),
                  ),
                ),

                // 1. Physical Activity
                _PermissionCard(
                  title: 'Physical Activity & Steps',
                  icon: Icons.directions_walk,
                  isGranted: _statusMap['activity'] ?? false,
                  why: 'Detects prolonged confinement or severe mobility drop-offs that often indicate worsening depression or acute post-trauma freeze response.',
                  how: 'Monitored as an anonymous step count total aggregated locally on your phone. Exact routes and places are never tracked.',
                  onToggle: () => _togglePermission('activity', [Permission.activityRecognition]),
                ),

                // 2. Emergency SOS Location
                _PermissionCard(
                  title: 'Emergency SOS Location',
                  icon: Icons.location_on_outlined,
                  isGranted: _statusMap['location'] ?? false,
                  why: 'Provides your live GPS coordinates to your verified guardian and emergency responders when you trigger an SOS.',
                  how: 'DORMANT during normal use. Your location is transmitted strictly when you trigger an active SOS alert.',
                  onToggle: () => _togglePermission('location', [Permission.locationWhenInUse]),
                ),

                // 3. Microphone & Voice Evidence
                _PermissionCard(
                  title: 'Microphone & Audio Evidence',
                  icon: Icons.mic_outlined,
                  isGranted: _statusMap['microphone'] ?? false,
                  why: 'Captures ambient emergency audio during active SOS to secure tamper-evident safety records, or records voice reflections for your diary.',
                  how: 'Sealed with client-side encryption. The microphone is never monitored in the background without active prompt.',
                  onToggle: () => _togglePermission('microphone', [Permission.microphone]),
                ),

                // 4. Bluetooth & Intimidation Watch
                _PermissionCard(
                  title: 'Bluetooth (Intimidation Watch)',
                  icon: Icons.bluetooth_searching,
                  isGranted: _statusMap['bluetooth'] ?? false,
                  why: 'Identifies unauthorized Bluetooth trackers (like AirTags or BLE beacons) that may be tracking your physical movement without your consent.',
                  how: 'Scans for nearby Bluetooth beacons locally. Device IDs are hashed on your phone; no location or telemetry is broadcast.',
                  onToggle: () => _togglePermission('bluetooth', [Permission.bluetoothScan, Permission.bluetoothConnect]),
                ),

                // 5. Notifications
                _PermissionCard(
                  title: 'Quiet Notifications',
                  icon: Icons.notifications_none_outlined,
                  isGranted: _statusMap['notification'] ?? false,
                  why: 'Delivers gentle daily check-in prompts at your preferred hour and silent alerts if a suspicious tracking beacon is detected.',
                  how: 'Generated entirely on-device by your local scheduler. They do not depend on external advertising push networks.',
                  onToggle: () => _togglePermission('notification', [Permission.notification]),
                ),

                // 6. Camera & QR Pairing
                _PermissionCard(
                  title: 'Camera & QR Scanner',
                  icon: Icons.qr_code_scanner,
                  isGranted: _statusMap['camera'] ?? false,
                  why: 'Allows you to scan the Guardian QR code from your support counsellor’s portal for pairing, or take secure photos of physical evidence.',
                  how: 'Active only while the camera viewfinder is visible. No continuous background video processing is ever run.',
                  onToggle: () => _togglePermission('camera', [Permission.camera]),
                ),

                // 7. Contacts & Emergency Dispatch
                _PermissionCard(
                  title: 'Contacts & Emergency Dispatch',
                  icon: Icons.contact_phone_outlined,
                  isGranted: _statusMap['contacts'] ?? false,
                  why: 'Enables quick selection of your trusted circle so Mool can alert them via SMS or call during an emergency.',
                  how: 'Reads only the specific contact records you select. Your contact list is never uploaded or scraped.',
                  onToggle: () => _togglePermission('contacts', [Permission.contacts]),
                ),

                const SizedBox(height: 20),
                Center(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      side: BorderSide(
                        color: isDark ? const Color(0xFF454B42) : MoolPalette.mistDark,
                        width: 1.2,
                      ),
                      foregroundColor: scheme.onSurface,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    icon: Icon(Icons.settings_suggest_outlined, color: scheme.onSurfaceVariant),
                    label: Text(
                      'Open Phone App Settings',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurface,
                      ),
                    ),
                    onPressed: openAppSettings,
                  ),
                ),
              ],
            ),
    );
  }
}

class _PermissionCard extends StatefulWidget {
  final String title;
  final IconData icon;
  final bool isGranted;
  final String why;
  final String how;
  final VoidCallback onToggle;

  const _PermissionCard({
    required this.title,
    required this.icon,
    required this.isGranted,
    required this.why,
    required this.how,
    required this.onToggle,
  });

  @override
  State<_PermissionCard> createState() => _PermissionCardState();
}

class _PermissionCardState extends State<_PermissionCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final t = theme.textTheme;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      color: isDark ? MoolPalette.nightSurface : Colors.white,
      elevation: isDark ? 0 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: widget.isGranted
              ? (isDark ? MoolPalette.mossLight.withValues(alpha: 0.4) : MoolPalette.moss.withValues(alpha: 0.35))
              : (isDark ? const Color(0xFF333832) : MoolPalette.mist),
          width: 1.2,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => setState(() => _expanded = !_expanded),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: widget.isGranted
                          ? (isDark ? MoolPalette.moss.withValues(alpha: 0.25) : MoolPalette.mossSoft)
                          : (isDark ? MoolPalette.nightRaised : MoolPalette.mistLight),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      widget.icon,
                      size: 20,
                      color: widget.isGranted
                          ? (isDark ? MoolPalette.mossLight : MoolPalette.mossDark)
                          : (isDark ? scheme.onSurfaceVariant : MoolPalette.slate),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.title,
                      style: t.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurface,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
                    decoration: BoxDecoration(
                      color: widget.isGranted
                          ? (isDark ? MoolPalette.moss.withValues(alpha: 0.25) : MoolPalette.mossSoft)
                          : (isDark ? MoolPalette.sandrose.withValues(alpha: 0.2) : MoolPalette.sandroseSoft),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          widget.isGranted ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
                          size: 13,
                          color: widget.isGranted
                              ? (isDark ? MoolPalette.mossLight : MoolPalette.mossDark)
                              : (isDark ? MoolPalette.sandroseLight : MoolPalette.ember),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          widget.isGranted ? 'Allowed' : 'Off',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: widget.isGranted
                            ? (isDark ? MoolPalette.mossLight : MoolPalette.mossDark)
                            : (isDark ? MoolPalette.sandroseLight : MoolPalette.ember),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    _expanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                    size: 22,
                    color: scheme.onSurfaceVariant,
                  ),
                ],
              ),

              // Expanded transparency details
              if (_expanded) ...[
                const SizedBox(height: 14),
                Divider(height: 1, color: isDark ? const Color(0xFF333832) : MoolPalette.mist),
                const SizedBox(height: 14),

                // Why it is used
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.help_outline_rounded, size: 17, color: isDark ? MoolPalette.mossLight : MoolPalette.moss),
                    const SizedBox(width: 10),
                    Expanded(
                      child: RichText(
                        text: TextSpan(
                          style: t.bodySmall?.copyWith(
                            height: 1.45,
                            fontSize: 12.5,
                            color: scheme.onSurfaceVariant,
                          ),
                          children: [
                            TextSpan(
                              text: 'Why it is used: ',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: scheme.onSurface,
                              ),
                            ),
                            TextSpan(text: widget.why),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // How it is used
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.lock_outline_rounded, size: 17, color: isDark ? MoolPalette.mossLight : MoolPalette.moss),
                    const SizedBox(width: 10),
                    Expanded(
                      child: RichText(
                        text: TextSpan(
                          style: t.bodySmall?.copyWith(
                            height: 1.45,
                            fontSize: 12.5,
                            color: scheme.onSurfaceVariant,
                          ),
                          children: [
                            TextSpan(
                              text: 'How it is used: ',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: scheme.onSurface,
                              ),
                            ),
                            TextSpan(text: widget.how),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Action button
                Align(
                  alignment: Alignment.centerRight,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                      side: BorderSide(
                        color: widget.isGranted
                            ? (isDark ? const Color(0xFF454B42) : MoolPalette.mistDark)
                            : (isDark ? MoolPalette.mossLight : MoolPalette.moss),
                        width: 1.2,
                      ),
                      foregroundColor: widget.isGranted
                          ? scheme.onSurface
                          : (isDark ? MoolPalette.mossLight : MoolPalette.mossDark),
                      backgroundColor: widget.isGranted
                          ? (isDark ? MoolPalette.nightRaised : Colors.transparent)
                          : (isDark ? MoolPalette.moss.withValues(alpha: 0.15) : MoolPalette.mossSoft),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: Icon(
                      widget.isGranted ? Icons.settings_outlined : Icons.lock_open_rounded,
                      size: 16,
                      color: widget.isGranted
                          ? scheme.onSurfaceVariant
                          : (isDark ? MoolPalette.mossLight : MoolPalette.mossDark),
                    ),
                    label: Text(
                      widget.isGranted ? 'Manage Permission' : 'Turn On Permission',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: widget.isGranted
                            ? scheme.onSurface
                            : (isDark ? MoolPalette.mossLight : MoolPalette.mossDark),
                      ),
                    ),
                    onPressed: widget.onToggle,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
