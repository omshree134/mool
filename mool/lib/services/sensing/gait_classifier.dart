import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

enum ActivityState { active, inactive, notCarried, uncertain }

class ActivitySample {
  const ActivitySample(this.state, {this.label, this.confidence = 0});
  final ActivityState state;
  final String? label;
  final double confidence;
}

class _Reading {
  _Reading(this.tUs, this.userAcc, this.gyro, this.acc);
  final int tUs;
  final List<double> userAcc;
  final List<double> gyro;
  final List<double> acc;
}

/// Runs Abhaya's gait model in short bursts to estimate daily active time.
///
/// Fixes compared with Abhaya's _GaitMotionEngine:
///  1. Units. The model has the UCI-HAR shape (128 × 9 → 6 classes). UCI-HAR
///     stores acceleration in g; Android reports m/s². Abhaya fed m/s²
///     straight in, inflating acceleration ~9.8× and skewing predictions.
///  2. Sample rate. Abhaya read sensors at the plugin default (~5 Hz) but
///     sampled them on a 20 ms timer, so each window held the same value
///     repeated about ten times. Here sensors run at 50 Hz and are resampled
///     onto an exact 50 Hz grid by timestamp.
///  3. Inference rate. Abhaya ran the model on every sample (50×/s) on the UI
///     thread. Here it runs 4 times per burst, off the UI thread, with 50%
///     window overlap like UCI-HAR.
///  4. Still phone. A phone lying on a table classifies as LAYING. Abhaya
///     treated STANDING → LAYING as a fall and opened the SOS countdown.
///     Here a motionless phone is "not carried" and excluded, and there is no
///     automatic fall-to-SOS at all.
///  5. Low confidence is "uncertain" and ignored instead of guessed.
class GaitClassifier {
  static const labels = ['WALKING', 'WALKING_UPSTAIRS', 'WALKING_DOWNSTAIRS', 'SITTING', 'STANDING', 'LAYING'];
  static const _walking = {0, 1, 2};

  /// Set to false only if your model was trained on m/s² instead of g.
  static const bool modelExpectsG = true;
  static const double _g = 9.80665;

  static const int _window = 128;
  static const int _hop = 64;
  static const int _rateHz = 50;
  static const double minConfidence = 0.6;

  /// Std-dev of acceleration magnitude (m/s²) below which the phone is lying
  /// still rather than being carried. Tune on real devices if needed.
  static const double stillnessStd = 0.04;

  Interpreter? _interpreter;
  IsolateInterpreter? _isolate;
  bool get available => _isolate != null;
  String? lastError;

  Future<bool> load() async {
    if (_isolate != null) return true;
    try {
      final interpreter = await Interpreter.fromAsset(
        'assets/models/gait_model.tflite',
        options: InterpreterOptions()..threads = 2,
      );
      final inShape = interpreter.getInputTensor(0).shape;
      final outShape = interpreter.getOutputTensor(0).shape;
      if (inShape.length != 3 || inShape[1] != _window || inShape[2] != 9 || outShape.last != labels.length) {
        lastError = 'Unexpected model shape in=$inShape out=$outShape';
        interpreter.close();
        return false;
      }
      _interpreter = interpreter;
      _isolate = await IsolateInterpreter.create(address: interpreter.address);
      return true;
    } catch (e) {
      // No heuristic fallback: Abhaya invented labels when the model failed to
      // load. Steps still cover activity if the model is unavailable.
      lastError = '$e';
      debugPrint('Gait model unavailable: $e');
      return false;
    }
  }

  Future<ActivitySample> sample({Duration length = const Duration(milliseconds: 6600)}) async {
    final readings = <_Reading>[];
    var userAcc = <double>[0, 0, 0];
    var gyro = <double>[0, 0, 0];
    final clock = Stopwatch()..start();

    final subs = <StreamSubscription<Object?>>[
      userAccelerometerEventStream(samplingPeriod: SensorInterval.gameInterval)
          .listen((e) => userAcc = [e.x, e.y, e.z], onError: (Object _) {}),
      gyroscopeEventStream(samplingPeriod: SensorInterval.gameInterval)
          .listen((e) => gyro = [e.x, e.y, e.z], onError: (Object _) {}),
      accelerometerEventStream(samplingPeriod: SensorInterval.gameInterval).listen(
        (e) => readings.add(_Reading(clock.elapsedMicroseconds, userAcc, gyro, [e.x, e.y, e.z])),
        onError: (Object _) {},
      ),
    ];
    await Future<void>.delayed(length);
    for (final s in subs) {
      await s.cancel();
    }

    if (readings.length < 30) return const ActivitySample(ActivityState.uncertain);

    // Is the phone lying still?
    final mags = readings.map((r) => sqrt(r.acc[0] * r.acc[0] + r.acc[1] * r.acc[1] + r.acc[2] * r.acc[2])).toList();
    final mean = mags.reduce((a, b) => a + b) / mags.length;
    final std = sqrt(mags.map((m) => (m - mean) * (m - mean)).reduce((a, b) => a + b) / mags.length);
    if (std < stillnessStd) return const ActivitySample(ActivityState.notCarried);

    if (_isolate == null) return const ActivitySample(ActivityState.uncertain);

    // Resample onto an exact 50 Hz grid.
    final scale = modelExpectsG ? _g : 1.0;
    final series = <List<double>>[];
    const stepUs = 1000000 ~/ _rateHz;
    var j = 0;
    for (var t = readings.first.tUs; t <= readings.last.tUs; t += stepUs) {
      while (j + 1 < readings.length && readings[j + 1].tUs <= t) {
        j++;
      }
      final r = readings[j];
      // Channel order must match training: body acc, gyro, total acc.
      series.add([
        r.userAcc[0] / scale, r.userAcc[1] / scale, r.userAcc[2] / scale,
        r.gyro[0], r.gyro[1], r.gyro[2],
        r.acc[0] / scale, r.acc[1] / scale, r.acc[2] / scale,
      ]);
    }
    if (series.length < _window) return const ActivitySample(ActivityState.uncertain);

    final probs = List<double>.filled(labels.length, 0);
    var runs = 0;
    try {
      for (var start = 0; start + _window <= series.length; start += _hop) {
        final input = [series.sublist(start, start + _window)];
        final output = [List<double>.filled(labels.length, 0)];
        await _isolate!.run(input, output);
        for (var i = 0; i < labels.length; i++) {
          probs[i] += output[0][i];
        }
        runs++;
      }
    } catch (e) {
      lastError = '$e';
      return const ActivitySample(ActivityState.uncertain);
    }
    if (runs == 0) return const ActivitySample(ActivityState.uncertain);

    var best = 0;
    for (var i = 1; i < probs.length; i++) {
      if (probs[i] > probs[best]) best = i;
    }
    final confidence = probs[best] / runs;
    if (confidence < minConfidence) return ActivitySample(ActivityState.uncertain, confidence: confidence);
    return ActivitySample(
      _walking.contains(best) ? ActivityState.active : ActivityState.inactive,
      label: labels[best],
      confidence: confidence,
    );
  }

  void dispose() {
    _isolate?.close();
    _interpreter?.close();
    _isolate = null;
    _interpreter = null;
  }
}
