import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../../core/dates.dart';
import '../../core/local_store.dart';
import 'feature_store.dart';

/// Estimates time spent away from home each day. Everything stays on the
/// phone: the learned home and all positions are never uploaded. Only the
/// daily totals ("5.5 hours away, furthest 3.2 km") are synced.
///
/// Fixes compared with Abhaya's LocationService:
///  * Abhaya polled a high-accuracy GPS fix every 4 seconds (heavy battery
///    drain) and asked for permission inside that timer, which could pop the
///    permission dialog again and again. Here a single low-power stream is
///    used, and permission is only asked when the person turns the feature on.
///  * The stream runs with a foreground notification. This keeps Mool alive in
///    the background so daily totals are real, not just "while the app was open".
class MobilityService {
  MobilityService._();
  static final MobilityService instance = MobilityService._();

  static const tickMinutes = 10;
  static const awayMeters = 250.0;

  StreamSubscription<Position>? _sub;
  Timer? _tick;
  Position? lastPosition;

  bool get running => _sub != null;

  Future<bool> start() async {
    if (_sub != null) return true;
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) return false;
      if (!await Geolocator.isLocationServiceEnabled()) return false;

      final settings = AndroidSettings(
        accuracy: LocationAccuracy.medium,
        distanceFilter: 100,
        intervalDuration: const Duration(minutes: 5),
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationTitle: 'Mool',
          notificationText: 'Running quietly',
          enableWakeLock: false,
          setOngoing: true,
        ),
      );
      _sub = Geolocator.getPositionStream(locationSettings: settings).listen(
        (p) => lastPosition = p,
        onError: (Object e) => debugPrint('Location stream: $e'),
      );
      lastPosition ??= await Geolocator.getLastKnownPosition();
      _tick = Timer.periodic(const Duration(minutes: tickMinutes), (_) => _onTick());
      return true;
    } catch (e) {
      debugPrint('Mobility unavailable: $e');
      return false;
    }
  }

  void stop() {
    _sub?.cancel();
    _sub = null;
    _tick?.cancel();
    _tick = null;
  }

  void _onTick() {
    // With a distance filter the stream is silent while the person stays in
    // one place, so the last position is still where they are.
    final p = lastPosition;
    if (p == null) return;
    final now = DateTime.now();
    _learnHome(p, now);
    final home = homeCentre();
    FeatureStore.instance.update(dateKey(now), (f) {
      f.locationCoverageMinutes += tickMinutes;
      f.homeKnown = home != null;
      if (home != null) {
        final meters = Geolocator.distanceBetween(p.latitude, p.longitude, home.$1, home.$2);
        if (meters > awayMeters) f.awayMinutes += tickMinutes;
        final km = meters / 1000;
        if (km > f.maxDistanceKm) f.maxDistanceKm = km;
      }
    });
  }

  // ── Home learning ──────────────────────────────────────────
  // Home = the ~110 m grid cell where the phone sits between 1 and 5 am on
  // the most nights (at least 3 of the last 14).

  static const _nightsKey = 'mobility.nightCells';

  static String _cell(double lat, double lng) => '${(lat * 1000).round()}:${(lng * 1000).round()}';

  void _learnHome(Position p, DateTime now) {
    if (now.hour < 1 || now.hour >= 5) return;
    final data = LocalStore.instance.getJson(_nightsKey);
    final cell = _cell(p.latitude, p.longitude);
    final nights = List<String>.from((data[cell] as List?) ?? const []);
    final key = dateKey(now);
    if (nights.contains(key)) return;
    nights.add(key);
    final cutoff = dateKey(now.subtract(const Duration(days: 14)));
    data[cell] = nights.where((k) => k.compareTo(cutoff) >= 0).toList();
    data.removeWhere((_, v) => (v as List).isEmpty);
    LocalStore.instance.setJson(_nightsKey, data);
  }

  (double, double)? homeCentre() {
    final data = LocalStore.instance.getJson(_nightsKey);
    String? best;
    var bestCount = 0;
    data.forEach((cell, nights) {
      final n = (nights as List).length;
      if (n > bestCount) {
        best = cell;
        bestCount = n;
      }
    });
    if (best == null || bestCount < 3) return null;
    final parts = best!.split(':');
    return (int.parse(parts[0]) / 1000, int.parse(parts[1]) / 1000);
  }

  bool isNearHome(double lat, double lng, {double meters = awayMeters}) {
    final home = homeCentre();
    if (home == null) return false;
    return Geolocator.distanceBetween(lat, lng, home.$1, home.$2) <= meters;
  }
}
