import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import 'app/app.dart';
import 'core/local_store.dart';
import 'core/settings.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Fast local storage initialization (<15ms)
  try {
    await LocalStore.instance.init();

    // Ensure local user ID exists
    if (LocalStore.instance.getString('local_uid') == null) {
      await LocalStore.instance.setString('local_uid', const Uuid().v4());
    }
    // Initialize memberSince if not set
    if (LocalStore.instance.getString(SettingKeys.memberSince) == null) {
      await LocalStore.instance.setString(SettingKeys.memberSince, DateTime.now().toIso8601String());
    }
  } catch (e) {
    debugPrint('LocalStore init error: $e');
  }

  // Initialize Firebase with timeout protection so slow networks NEVER block app launch
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    ).timeout(const Duration(seconds: 3));
  } catch (e) {
    debugPrint('Firebase init timeout or skipped: $e');
  }

  // Render UI IMMEDIATELY (under 100ms startup)
  runApp(const MoolApp());

  // Cloud auth runs asynchronously in background without blocking UI
  _initCloudServices();
}

void _initCloudServices() {
  unawaited(() async {
    try {
      if (FirebaseAuth.instance.currentUser == null) {
        await FirebaseAuth.instance.signInAnonymously().timeout(const Duration(seconds: 5));
      }
    } catch (e) {
      debugPrint('Background anonymous auth: $e');
    }
  }());
}
