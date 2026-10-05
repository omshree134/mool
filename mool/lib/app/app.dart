import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/notifier.dart';
import '../core/settings.dart';
import '../services/daily_pipeline.dart';
import '../services/member_profile.dart';
import '../services/safety/evidence_service.dart';
import '../services/sensing/sensing_coordinator.dart';
import '../services/telemetry_service.dart';
import '../ui/ai_chat_page.dart';
import '../ui/guardian_onboarding_page.dart';
import '../ui/help_page.dart';
import '../ui/lock_page.dart';
import '../ui/me_page.dart';
import '../ui/today_page.dart';
import '../ui/tools_page.dart';
import 'theme.dart';

final appNavigatorKey = GlobalKey<NavigatorState>();

class MoolApp extends StatefulWidget {
  const MoolApp({super.key});

  @override
  State<MoolApp> createState() => _MoolAppState();
}

class _MoolAppState extends State<MoolApp> with WidgetsBindingObserver {
  late bool _locked = Settings.instance.hasPin;
  DateTime? _backgroundedAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Start continuous telemetry and cloud sync across all screens
    TelemetryService.instance.start();
    MemberProfile.instance.listen();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      _backgroundedAt ??= DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      TelemetryService.instance.start();
      EvidenceService.instance.uploadPending();
      final away = _backgroundedAt == null ? Duration.zero : DateTime.now().difference(_backgroundedAt!);
      _backgroundedAt = null;
      if (Settings.instance.hasPin && away > const Duration(seconds: 30)) {
        setState(() => _locked = true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mool',
      navigatorKey: appNavigatorKey,
      debugShowCheckedModeBanner: false,
      theme: MoolTheme.light(),
      darkTheme: MoolTheme.dark(),
      themeMode: ThemeMode.system,
      // The lock sits above every route, so a screen left open underneath
      // (a check-in, the safety plan) can't be seen by someone else.
      builder: (context, child) => Stack(
        children: [
          child ?? const SizedBox.shrink(),
          if (_locked && Settings.instance.hasPin)
            Positioned.fill(child: LockPage(onUnlocked: () => setState(() => _locked = false))),
        ],
      ),
      home: ListenableBuilder(
        listenable: Settings.instance,
        builder: (context, _) =>
            Settings.instance.onboarded ? const HomeShell() : const GuardianOnboardingPage(),
      ),
    );
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  static const _nativeChannel = MethodChannel('app.mool/native');
  int _tab = 0;
  Timer? _settingsDebounce;

  @override
  void initState() {
    super.initState();
    MemberProfile.instance.listen();
    Notifier.init();
    Settings.instance.addListener(_onSettingsChanged);
    TelemetryService.instance.start();
    _checkWidgetLaunch();
    // Let the first frame render before starting sensors, so opening the
    // app feels instant.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      SensingCoordinator.instance.apply();
      DailyPipeline.instance.run();
      EvidenceService.instance.uploadPending();
    });
  }

  void _checkWidgetLaunch() {
    _nativeChannel.setMethodCallHandler((call) async {
      if (call.method == 'onNavigateRoute' && call.arguments == 'get_help') {
        _navigateToHelpPage();
      }
    });

    _nativeChannel.invokeMethod<String>('getInitialRoute').then((route) {
      if (route == 'get_help') {
        WidgetsBinding.instance.addPostFrameCallback((_) => _navigateToHelpPage());
      }
    }).catchError((_) {});
  }

  void _navigateToHelpPage() {
    appNavigatorKey.currentState?.push(MaterialPageRoute(
      builder: (_) => const HelpPage(),
    ));
  }

  @override
  void dispose() {
    Settings.instance.removeListener(_onSettingsChanged);
    TelemetryService.instance.stop();
    _settingsDebounce?.cancel();
    super.dispose();
  }

  void _onSettingsChanged() {
    _settingsDebounce?.cancel();
    _settingsDebounce = Timer(const Duration(milliseconds: 400), SensingCoordinator.instance.apply);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _tab,
        children: const [TodayPage(), AiChatPage(), ToolsPage(), MePage()],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.wb_twilight_outlined), selectedIcon: Icon(Icons.wb_twilight), label: 'Today'),
          NavigationDestination(icon: Icon(Icons.chat_bubble_outline), selectedIcon: Icon(Icons.chat_bubble), label: 'Talk'),
          NavigationDestination(icon: Icon(Icons.spa_outlined), selectedIcon: Icon(Icons.spa), label: 'Tools'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Me'),
        ],
      ),
    );
  }
}
