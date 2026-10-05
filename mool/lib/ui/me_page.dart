import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

import '../app/theme.dart';
import '../core/permissions.dart';
import '../core/settings.dart';
import '../services/auth_service.dart';
import '../services/member_profile.dart';
import '../services/repository.dart';
import '../services/safety/trusted_contacts.dart';
import '../services/sensing/sensing_coordinator.dart';
import 'contacts_page.dart';
import 'guardian_onboarding_page.dart';
import 'permission_settings_page.dart';
import 'privacy_page.dart';
import 'widgets/common.dart';

class MePage extends StatelessWidget {
  const MePage({super.key});

  /// Turns a feature on only if its permissions are granted.
  Future<void> _toggle(BuildContext context, String key, bool value, List<Permission> perms) async {
    if (value && !await Perms.requestAll(perms)) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Mool needs permission for this. You can allow it in phone settings.'),
        action: SnackBarAction(label: 'Settings', onPressed: openAppSettings),
      ));
      return;
    }
    await Settings.instance.setBool(key, value);
    await Repo.instance.upsertProfile();
  }

  Future<void> _editName(BuildContext context) async {
    final controller = TextEditingController(text: Settings.instance.displayName);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Your name'),
        content: TextField(controller: controller, autofocus: true, textCapitalization: TextCapitalization.words),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, controller.text.trim()), child: const Text('Save')),
        ],
      ),
    );
    if (name == null) return;
    await Settings.instance.setString(SettingKeys.name, name);
    await Repo.instance.upsertProfile();
  }

  Future<void> _pickReminder(BuildContext context) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: Settings.instance.reminderHour, minute: 0),
      helpText: 'Remind me around',
    );
    if (picked != null) await Settings.instance.setInt(SettingKeys.reminderHour, picked.hour);
  }

  Future<void> _setPin(BuildContext context) async {
    final pin = await showDialog<String>(context: context, builder: (_) => const _PinDialog());
    if (pin == null) return;
    await Settings.instance.setPin(pin);
    if (context.mounted) showQuietSnack(context, 'PIN set. Mool will ask for it when you come back to the app.');
  }

  Future<void> _signOut(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text(
          'Your check-ins stay in your account. Your safety plan, trusted people and settings are removed '
          'from this phone, so someone else using it cannot see them.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: MoolPalette.ember),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    SensingCoordinator.instance.stopAll();
    MemberProfile.instance.stop();
    await Settings.instance.reset();
    try {
      await AuthService.instance.signOut();
    } catch (_) {}
    if (!context.mounted) return;
    Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const GuardianOnboardingPage()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Me'), actions: const [GetHelpButton()]),
      body: ListenableBuilder(
        listenable: Listenable.merge([Settings.instance, MemberProfile.instance, TrustedContacts.instance]),
        builder: (context, _) {
          final s = Settings.instance;
          final contacts = TrustedContacts.instance.all.length;
          final hour = s.reminderHour;
          final hourLabel = '${hour % 12 == 0 ? 12 : hour % 12} ${hour < 12 ? 'am' : 'pm'}';

          Widget header(String text) => Padding(
                padding: const EdgeInsets.fromLTRB(4, 24, 4, 8),
                child: Text(text, style: t.titleMedium),
              );

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
            children: [
              Card(
                child: Column(children: [
                  ListTile(
                    leading: const Icon(Icons.person_outline),
                    title: Text(s.displayName.isEmpty ? 'Add your name' : s.displayName),
                    trailing: const Icon(Icons.edit_outlined),
                    onTap: () => _editName(context),
                  ),
                  ListTile(
                    leading: const Icon(Icons.shield_outlined, color: MoolPalette.moss),
                    title: Text(s.hasGuardian ? 'Guardian: ${s.guardianName}' : 'Connect with your Guardian'),
                    subtitle: Text(s.hasGuardian ? 'Tap to change or re-scan QR' : 'Scan QR code from web portal'),
                    trailing: const Icon(Icons.qr_code_scanner),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const GuardianOnboardingPage(initialStep: 1)),
                    ),
                  ),
                  ListTile(
                    leading: const Icon(Icons.cloud_sync_outlined, color: MoolPalette.moss),
                    title: Text(AuthService.instance.isGoogleUser ? 'Google Cloud Backup' : 'Back up with Google'),
                    subtitle: Text(AuthService.instance.isGoogleUser
                        ? 'Active (${AuthService.instance.userEmail ?? "Connected"})'
                        : 'Sign in with Google to protect your data across resets'),
                    trailing: AuthService.instance.isGoogleUser
                        ? const Icon(Icons.check_circle, color: MoolPalette.moss, size: 18)
                        : const Icon(Icons.chevron_right),
                    onTap: AuthService.instance.isGoogleUser
                        ? null
                        : () async {
                            try {
                              final cred = await AuthService.instance.signInWithGoogle();
                              if (cred != null && context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    backgroundColor: MoolPalette.moss,
                                    content: Text('Account backed up with Google successfully!'),
                                  ),
                                );
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    backgroundColor: MoolPalette.ember,
                                    content: Text('Google Sign-In failed: $e'),
                                  ),
                                );
                              }
                            }
                          },
                  ),
                  ListTile(
                    leading: const Icon(Icons.lock_outline),
                    title: const Text('Privacy and sharing'),
                    subtitle: const Text('What your counsellor can and cannot see'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PrivacyPage())),
                  ),
                  ListTile(
                    leading: const Icon(Icons.security_outlined, color: MoolPalette.moss),
                    title: const Text('Permissions & Transparency'),
                    subtitle: const Text('Why & how sensors are used, and manage access'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PermissionSettingsPage())),
                  ),
                ]),
              ),
              header('In an emergency'),
              Card(
                child: Column(children: [
                  ListTile(
                    leading: const Icon(Icons.people_outline),
                    title: const Text('People I trust'),
                    subtitle: Text(contacts == 0 ? 'No one added yet' : '$contacts added'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () async {
                      await Perms.requestAll(Perms.emergency);
                      if (!context.mounted) return;
                      await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ContactsPage()));
                    },
                  ),
                  SwitchListTile(
                    title: const Text('Call 112'),
                    subtitle: const Text('After messaging your trusted people'),
                    value: s.call112OnSos,
                    onChanged: (v) => _toggle(context, SettingKeys.call112OnSos, v, const [Permission.phone]),
                  ),
                  SwitchListTile(
                    title: const Text('Send my location'),
                    subtitle: const Text('To trusted people and your support team, only in an emergency'),
                    value: s.shareLocationOnSos,
                    onChanged: (v) =>
                        _toggle(context, SettingKeys.shareLocationOnSos, v, const [Permission.locationWhenInUse]),
                  ),
                  SwitchListTile(
                    title: const Text('Record audio'),
                    subtitle: const Text('Sealed as evidence'),
                    value: s.recordAudioOnSos,
                    onChanged: (v) => _toggle(context, SettingKeys.recordAudioOnSos, v, Perms.audio),
                  ),
                ]),
              ),
              header('What Mool notices'),
              Card(
                child: Column(children: [
                  SwitchListTile(
                    title: const Text('My daily activity'),
                    subtitle: const Text('Steps and time outside, as daily totals. Never where you went.'),
                    value: s.passiveSensing,
                    onChanged: (v) => _toggle(context, SettingKeys.passiveSensing, v, Perms.passiveSensing),
                  ),
                  SwitchListTile(
                    title: const Text('Devices following me'),
                    subtitle: const Text(
                        'Best at finding tracker tags. Phones change their Bluetooth name often, so it may miss them.'),
                    value: s.followWatch,
                    onChanged: (v) => _toggle(context, SettingKeys.followWatch, v, Perms.followWatch),
                  ),
                ]),
              ),
              header('Reminders'),
              Card(
                child: Column(children: [
                  SwitchListTile(
                    title: const Text('Remind me to check in'),
                    subtitle: const Text('Only if you haven\'t checked in that day'),
                    value: s.remindersOn,
                    onChanged: (v) => _toggle(context, SettingKeys.remindersOn, v, const [Permission.notification]),
                  ),
                  if (s.remindersOn)
                    ListTile(
                      title: const Text('Time'),
                      subtitle: Text('Around $hourLabel'),
                      trailing: const Icon(Icons.schedule),
                      onTap: () => _pickReminder(context),
                    ),
                ]),
              ),
              header('This phone'),
              Card(
                child: Column(children: [
                  ListTile(
                    leading: const Icon(Icons.pin_outlined),
                    title: Text(s.hasPin ? 'Change PIN' : 'Lock Mool with a PIN'),
                    subtitle: const Text('For phones shared with others'),
                    onTap: () => _setPin(context),
                  ),
                  if (s.hasPin)
                    ListTile(
                      leading: const Icon(Icons.no_encryption_outlined),
                      title: const Text('Remove PIN'),
                      onTap: () => s.removePin(),
                    ),
                  ListTile(
                    leading: const Icon(Icons.exit_to_app),
                    title: const Text('Close Mool quickly'),
                    onTap: () => SystemNavigator.pop(),
                  ),
                  ListTile(
                    leading: const Icon(Icons.logout),
                    title: const Text('Sign out'),
                    onTap: () => _signOut(context),
                  ),
                ]),
              ),
              const SizedBox(height: 16),
              Center(child: Text('Mool 0.1.0', style: t.bodySmall)),
            ],
          );
        },
      ),
    );
  }
}

class _PinDialog extends StatefulWidget {
  const _PinDialog();

  @override
  State<_PinDialog> createState() => _PinDialogState();
}

class _PinDialogState extends State<_PinDialog> {
  final _a = TextEditingController();
  final _b = TextEditingController();
  String? _error;

  void _save() {
    final a = _a.text;
    if (!RegExp(r'^\d{4,6}$').hasMatch(a)) {
      setState(() => _error = 'Use 4 to 6 digits.');
      return;
    }
    if (a != _b.text) {
      setState(() => _error = "The two PINs don't match.");
      return;
    }
    Navigator.pop(context, a);
  }

  @override
  Widget build(BuildContext context) {
    InputDecoration deco(String label) => InputDecoration(labelText: label, counterText: '');
    return AlertDialog(
      title: const Text('Choose a PIN'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _a,
            obscureText: true,
            keyboardType: TextInputType.number,
            maxLength: 6,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: deco('New PIN'),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _b,
            obscureText: true,
            keyboardType: TextInputType.number,
            maxLength: 6,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: deco('Type it again'),
            onSubmitted: (_) => _save(),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}
