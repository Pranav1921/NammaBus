import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:logging/logging.dart';
import 'package:flutter/material.dart'; // Import for ValueNotifier

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final _logger = Logger('AuthService');

  // Notifier to announce login/logout events
  final ValueNotifier<bool> userLoggedInNotifier = ValueNotifier(false);

  // Stream to listen to authentication state changes (logged in or out)
  Stream<User?> get user => _auth.authStateChanges();

  // Synchronous getter for the currently signed-in user (may be null)
  User? get currentUser => _auth.currentUser;

  // Sign in with Google (for Passengers)
  Future<User?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        _logger.info('Google sign-in aborted by user.');
        return null; // User cancelled
      }
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      final UserCredential userCredential = await _auth.signInWithCredential(credential);
      _logger.info('Passenger signed in: ${userCredential.user?.displayName}');
      userLoggedInNotifier.value = true; // Announce that a user has logged in
      return userCredential.user;
    } catch (e) {
      _logger.severe('Error during Google sign-in: $e');
      return null;
    }
  }

  // Sign in with Email & Password (for Conductors)
  Future<User?> signInWithEmail(String email, String password) async {
    try {
      final UserCredential result = await _auth.signInWithEmailAndPassword(email: email, password: password);
      _logger.info('Conductor signed in: ${result.user?.email}');
      userLoggedInNotifier.value = true; // Announce that a user has logged in
      return result.user;
    } on FirebaseAuthException catch (e) {
      _logger.warning('Failed to sign in: ${e.message}');
      return null;
    }
  }

  // Sign out
  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
    userLoggedInNotifier.value = false; // Announce that the user has logged out
    _logger.info('User signed out.');
  }
}
