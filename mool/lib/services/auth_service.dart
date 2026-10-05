import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'repository.dart';

class AuthService {
  static final AuthService instance = AuthService._();
  AuthService._();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    serverClientId: '732080045766-3hmm78b3h96crihlnvnnmn6afid8ngcc.apps.googleusercontent.com',
  );

  User? get currentUser => _auth.currentUser;

  bool get isGoogleUser =>
      currentUser != null &&
      currentUser!.providerData.any((p) => p.providerId == 'google.com');

  String? get userEmail => currentUser?.email;
  String? get userPhotoUrl => currentUser?.photoURL;

  /// Signs in the user with Google, links their Firebase credential,
  /// and automatically restores their cloud profile and history from Firestore.
  Future<UserCredential?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        // User cancelled the interactive dialog
        return null;
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await _auth.signInWithCredential(credential);
      final user = userCredential.user;

      if (user != null) {
        // Restore all user data from Firestore
        await Repo.instance.restoreFromCloud(user);
      }

      return userCredential;
    } catch (e) {
      debugPrint('Google Sign-In failed: $e');
      rethrow;
    }
  }

  /// Signs out of Google and Firebase Auth.
  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
    } catch (_) {}
    try {
      await _auth.signOut();
    } catch (_) {}
  }
}
