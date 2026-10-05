import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart' hide Settings;
import 'package:flutter/widgets.dart';
import 'package:geolocator/geolocator.dart';

import '../core/local_store.dart';
import '../core/settings.dart';
import 'repository.dart';
import 'safety/sos_service.dart';
import 'sensing/feature_store.dart';

/// Lightweight 10-second telemetry heartbeat service.
///
/// Designed specifically for Firebase Cloud Free Tier:
/// - Sends a minimal merged document write every 10 seconds while the app is
///   active (foreground) or during an emergency SOS.
/// - Automatically pauses when the app is backgrounded/idle to guarantee 0 bill
///   from Google Cloud (<20,000 writes/day free tier quota).
/// - Transmits live emergency coordinates and status to the Guardian Web Portal.
class TelemetryService with WidgetsBindingObserver {
  TelemetryService._();
  static final TelemetryService instance = TelemetryService._();

  Timer? _timer;
  bool _isForeground = true;
  bool _started = false;

  void start() {
    if (_started) return;
    _started = true;
    WidgetsBinding.instance.addObserver(this);
    SosService.instance.addListener(_onSosChanged);
    _startTimer();
    // Send immediate initial ping
    _sendHeartbeat();
  }

  void stop() {
    if (!_started) return;
    _started = false;
    WidgetsBinding.instance.removeObserver(this);
    SosService.instance.removeListener(_onSosChanged);
    _timer?.cancel();
    _timer = null;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _isForeground = true;
      _startTimer();
      _sendHeartbeat();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      _isForeground = false;
      // Only keep pinging in the background if an active emergency SOS is underway
      if (!SosService.instance.active) {
        _timer?.cancel();
        _timer = null;
        _sendOfflineStatus();
      }
    }
  }

  void _onSosChanged() {
    if (SosService.instance.active) {
      // Ensure timer is actively running during SOS even in background
      _startTimer();
      _sendHeartbeat();
    } else if (!_isForeground) {
      // SOS resolved while in background: pause timer to conserve free tier
      _timer?.cancel();
      _timer = null;
      _sendOfflineStatus();
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 10), (_) => _sendHeartbeat());
  }

  Future<void> _sendHeartbeat() async {
    try {
      final now = DateTime.now();
      final isSos = SosService.instance.active;

      // Extract current GPS position if SOS is active and location sharing is allowed
      Map<String, dynamic>? liveLocation;
      if (isSos && Settings.instance.shareLocationOnSos) {
        try {
          final pos = await Geolocator.getLastKnownPosition();
          if (pos != null) {
            liveLocation = {
              'lat': pos.latitude,
              'lng': pos.longitude,
              'accuracyM': pos.accuracy,
              'timestamp': pos.timestamp.toIso8601String(),
            };
          }
        } catch (_) {}
      }

      // Sensed Gait & Mobility telemetry
      final todaySteps = LocalStore.instance.getInt('steps.today') ?? 0;
      final todayFeatures = FeatureStore.instance.today();
      final gaitData = <String, dynamic>{
        'steps': todaySteps,
        'activeMinutes': todayFeatures.activeMinutes,
        'activeBlocks': todayFeatures.activeBlocks,
        'inactiveBlocks': todayFeatures.inactiveBlocks,
        'notCarriedBlocks': todayFeatures.notCarriedBlocks,
        'hoursAway': double.parse((todayFeatures.awayMinutes / 60).toStringAsFixed(1)),
        'maxDistanceKm': double.parse(todayFeatures.maxDistanceKm.toStringAsFixed(1)),
        'cadenceEstimate': todaySteps > 0 ? (todaySteps / 30).clamp(40, 120).round() : 0,
        'updatedAt': now.toIso8601String(),
      };

      final s = Settings.instance;
      final payload = <String, dynamic>{
        'isOnline': true,
        'lastHeartbeatAt': now.toIso8601String(),
        'lastSeenAt': FieldValue.serverTimestamp(),
        'activeSos': isSos,
        'appVersion': '0.1.0',
        'gait': gaitData,
        'telemetry': {
          'passiveSensing': s.passiveSensing,
          'followWatch': s.followWatch,
          'batterySaver': false,
          'gait': gaitData,
        },
      };

      if (s.hasGuardian) {
        payload['guardianId'] = s.guardianId;
        payload['guardianName'] = s.guardianName;
      }
      if (s.displayName.isNotEmpty) {
        payload['displayName'] = s.displayName;
      }
      final emergency = LocalStore.instance.getString('emergency.contact') ?? '';
      if (emergency.isNotEmpty) {
        payload['emergencyContact'] = emergency;
      }

      if (liveLocation != null) {
        payload['lastSosLocation'] = liveLocation;
      }

      // Merge write to memberDoc. Extremely lightweight and fast.
      Repo.instance.memberDoc.set(payload, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Telemetry heartbeat error: $e');
    }
  }

  Future<void> _sendOfflineStatus() async {
    try {
      Repo.instance.memberDoc.set({
        'isOnline': false,
        'lastHeartbeatAt': DateTime.now().toIso8601String(),
        'lastSeenAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {}
  }
}
